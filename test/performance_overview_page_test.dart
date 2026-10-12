import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/core_royal_clean/services/admin_access_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/dashboard_chart_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/preview/contacts_performance_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/preview/contacts_market_chart_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/preview/performance_overview_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/preview/preview_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/preview/public_activity_index_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/preview/activity_market_viewport_royal_clean.dart';

Map<String, dynamic> fixture() => {
  'source': 'royal-clean',
  'generatedAt': 1791748800000,
  'bins': [
    {
      'start': 1791694800000,
      'end': 1791781200000,
      'registered': 8,
      'deleted': 2,
      'pending': 3,
      'online': 4,
      'absent': 6,
      'closed': false,
      'deletionComplete': true,
      'playersOpen': 100,
      'playersPositiveClose': 108,
      'playersClose': 103,
      'activityOpen': 5,
      'activityHigh': 7,
      'activityLow': 2,
      'activityClose': 4,
    },
  ],
  'records': 3,
  'partial': true,
  'labels': ['A', 'B'],
  'details': ['Período A', 'Período B'],
  'metrics': [
    {
      'label': 'Quantidade',
      'unit': 'registros',
      'values': [1, 2],
      'money': false,
    },
  ],
};

void main() {
  test(
    'Presence volume paints a pink zero tick without inventing a negative volume',
    () async {
      final recorder = ui.PictureRecorder();
      final bins = [
        {
          'start': 0,
          'end': 60000,
          'indexPoints': true,
          'activityOpen': 100,
          'activityClose': 101,
          'volume': 1,
        },
        {
          'start': 60000,
          'end': 120000,
          'indexPoints': true,
          'activityOpen': 101,
          'activityClose': 100,
          'volume': 0,
        },
      ];
      ContactsMarketPainterRoyalClean(
        bins: bins,
        category: 'Atividade',
        minimumRange: 1,
      ).paint(Canvas(recorder), const Size(390, 320));
      final picture = recorder.endRecording();
      final rendered = await picture.toImage(390, 320);
      final pixels = (await rendered.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var pinkTick = false;
      for (var y = 272; y <= 274; y++) {
        for (var x = 237; x <= 246; x++) {
          final offset = (y * 390 + x) * 4;
          final alpha = pixels.getUint8(offset + 3);
          if (alpha > 0 &&
              pixels.getUint8(offset) * 255 / alpha > 200 &&
              pixels.getUint8(offset + 2) * 255 / alpha > 150 &&
              (pixels.getUint8(offset) - pixels.getUint8(offset + 1)) *
                      255 /
                      alpha >
                  20) {
            pinkTick = true;
          }
        }
      }
      expect(pinkTick, isTrue);
      expect(activityVolumeHeightRoyalClean(0, 1), 0);
      expect(
        activityVolumeHeightRoyalClean(.000001, 1),
        greaterThanOrEqualTo(2),
      );
      expect(bins.last['volume'], 0);
      rendered.dispose();
      picture.dispose();
    },
  );
  test(
    'Countdown uses the candle end, handles long periods and never goes negative',
    () {
      final now = DateTime.utc(2026, 10, 12, 15);
      expect(
        candleCountdownRoyalClean(
          now.add(const Duration(seconds: 59)).millisecondsSinceEpoch,
          now,
        ),
        '00:00:59',
      );
      expect(
        candleCountdownRoyalClean(
          now.add(const Duration(days: 3, hours: 2)).millisecondsSinceEpoch,
          now,
        ),
        '3d\n02:00:00',
      );
      expect(
        candleCountdownRoyalClean(
          now.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch,
          now,
        ),
        'Encerrado',
      );
    },
  );
  testWidgets(
    'Chart leaves future space, pans both axes and preserves camera on live updates',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bins = List.generate(
        80,
        (i) => <String, dynamic>{
          'start': i * 60000,
          'end': (i + 1) * 60000,
          'indexPoints': true,
          'activityOpen': 100 + i / 1440,
          'activityClose': 100 + (i + 1) / 1440,
          'activityHigh': 100 + (i + 1) / 1440,
          'activityLow': 100 + i / 1440,
        },
      );
      num? selected;
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      Future<void> mount() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  ActivityMarketViewportRoyalClean(
                    bins: List.of(bins),
                    minimumRange: 1 / 1440,
                    latestClose: 100 + bins.length / 1440,
                    onSelect: (value) => selected = value,
                    candleEnd: DateTime.now()
                        .add(const Duration(hours: 1))
                        .millisecondsSinceEpoch,
                  ),
                  const SizedBox(height: 1000),
                ],
              ),
            ),
          ),
        ),
      );
      await mount();
      final chart = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ContactsMarketPainterRoyalClean,
      );
      ContactsMarketPainterRoyalClean painter() =>
          tester.widget<CustomPaint>(chart).painter!
              as ContactsMarketPainterRoyalClean;
      final initialOffset = painter().endOffset;
      expect(initialOffset, greaterThan(5));
      final origin = tester.getTopLeft(chart);
      await tester.tapAt(origin + const Offset(305, 100));
      expect(
        selected,
        isNull,
        reason: 'Empty future space must not select or invent a candle',
      );
      final gesture = await tester.startGesture(
        origin + const Offset(170, 130),
      );
      await gesture.moveBy(const Offset(-20, 10));
      await tester.pump();
      await gesture.moveBy(const Offset(-55, 35));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(painter().endOffset, greaterThan(initialOffset));
      expect(painter().cameraRange, isNotNull);
      final offset = painter().endOffset, range = painter().cameraRange;
      bins.last = {...bins.last, 'activityClose': 100.08};
      await mount();
      expect(painter().endOffset, offset);
      expect(painter().cameraRange, range);
      await tester.tap(find.byTooltip('Últimos candles e zoom padrão'));
      await tester.pump();
      expect(painter().endOffset, initialOffset);
      expect(painter().cameraRange, isNull);
      final vertical = await tester.startGesture(
        origin + const Offset(150, 100),
      );
      await vertical.moveBy(const Offset(0, 22));
      await tester.pump();
      await vertical.moveBy(const Offset(0, 60));
      await tester.pump();
      await vertical.up();
      await tester.pump();
      expect(painter().cameraRange, isNotNull);
      final downRange = painter().cameraRange!;
      final upward = await tester.startGesture(origin + const Offset(150, 180));
      await upward.moveBy(const Offset(0, -22));
      await tester.pump();
      await upward.moveBy(const Offset(0, -60));
      await tester.pump();
      await upward.up();
      await tester.pump();
      expect(painter().cameraRange!.$1, lessThan(downRange.$1));
      expect(
        scroll.offset,
        0,
        reason: 'Vertical drag inside the chart must not scroll the page',
      );
      expect(find.text('FECHA EM'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 400));
    },
  );
  testWidgets(
    'Two-finger pinch zooms, compresses candles into a line and requests earlier pages',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var earlier = 0;
      final bins = List.generate(
        200,
        (i) => <String, dynamic>{
          'start': 1791774000000 + i * 60000,
          'end': 1791774000000 + (i + 1) * 60000,
          'indexPoints': true,
          'activityOpen': 100 + i / 1440,
          'activityClose': 100 + (i + 1) / 1440,
          'activityHigh': 100 + (i + 1) / 1440,
          'activityLow': 100 + i / 1440,
          'volume': 1 / 1440,
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityMarketViewportRoyalClean(
              bins: bins,
              minimumRange: 1 / 1440,
              latestClose: 100 + 200 / 1440,
              onSelect: (_) {},
              onNeedOlder: () => earlier++,
            ),
          ),
        ),
      );
      final chart = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ContactsMarketPainterRoyalClean,
      );
      final center = tester.getCenter(chart);
      final one = await tester.createGesture(pointer: 1),
          two = await tester.createGesture(pointer: 2);
      await one.down(center - const Offset(60, 0));
      await two.down(center + const Offset(60, 0));
      await tester.pump();
      await one.moveTo(center - const Offset(110, 0));
      await two.moveTo(center + const Offset(110, 0));
      await tester.pump();
      ContactsMarketPainterRoyalClean painter() =>
          tester.widget<CustomPaint>(chart).painter!
              as ContactsMarketPainterRoyalClean;
      expect(painter().capacity!, lessThan(40));
      await one.up();
      await two.up();
      await tester.pump();
      final three = await tester.createGesture(pointer: 3),
          four = await tester.createGesture(pointer: 4);
      await three.down(center - const Offset(120, 0));
      await four.down(center + const Offset(120, 0));
      await tester.pump();
      for (final distance in [90.0, 60.0, 30.0, 10.0, 2.0]) {
        await three.moveTo(center - Offset(distance, 0));
        await four.moveTo(center + Offset(distance, 0));
        await tester.pump();
      }
      expect(painter().minimumRange, 1 / 1440);
      await three.up();
      await four.up();
      await tester.pump();
      for (var pass = 0; pass < 2; pass++) {
        final left = await tester.createGesture(pointer: 20 + pass * 2),
            right = await tester.createGesture(pointer: 21 + pass * 2);
        await left.down(center - const Offset(120, 0));
        await right.down(center + const Offset(120, 0));
        await tester.pump();
        for (final distance in [90.0, 60.0, 30.0, 10.0, 2.0]) {
          await left.moveTo(center - Offset(distance, 0));
          await right.moveTo(center + Offset(distance, 0));
          await tester.pump();
        }
        await left.up();
        await right.up();
        await tester.pump();
      }
      expect(painter().capacity!, greaterThan(100));
      expect(earlier, greaterThan(0));
      await tester.tap(find.byTooltip('Últimos candles e zoom padrão'));
      await tester.pump();
      final initialRange = contactMarketRangeRoyalClean(
        painter().bins,
        'Atividade',
        1 / 1440,
      );
      final topFinger = await tester.createGesture(pointer: 5),
          bottomFinger = await tester.createGesture(pointer: 6);
      await topFinger.down(center - const Offset(0, 50));
      await bottomFinger.down(center + const Offset(0, 50));
      await tester.pump();
      await topFinger.moveTo(center - const Offset(0, 85));
      await bottomFinger.moveTo(center + const Offset(0, 85));
      await tester.pump();
      expect(
        painter().capacity!,
        closeTo(40, .001),
        reason:
            'Two fingers placed together activate vertical zoom without a preceding one-finger drag',
      );
      final expandedCapacity = painter().capacity!;
      final expandedRange = painter().cameraRange!;
      expect(
        expandedRange.$2 - expandedRange.$1,
        lessThan(initialRange.$2 - initialRange.$1),
      );
      await topFinger.moveTo(center - const Offset(0, 25));
      await bottomFinger.moveTo(center + const Offset(0, 25));
      await tester.pump();
      expect(
        painter().cameraRange!.$2 - painter().cameraRange!.$1,
        greaterThan(expandedRange.$2 - expandedRange.$1),
      );
      expect(painter().capacity!, closeTo(expandedCapacity, .001));
      await topFinger.up();
      await bottomFinger.up();
      await tester.pump();
      final tapPosition = tester.getTopLeft(chart) + const Offset(200, 100);
      await tester.tapAt(tapPosition);
      await tester.pump(const Duration(milliseconds: 70));
      await tester.tapAt(tapPosition);
      await tester.pump();
      expect(painter().capacity, 40);
      expect(painter().cameraRange, isNull);
      final dragOne = await tester.createGesture(pointer: 7),
          dragTwo = await tester.createGesture(pointer: 8);
      await dragOne.down(center - const Offset(50, 30));
      await dragTwo.down(center + const Offset(50, 30));
      await tester.pump();
      for (final distance in [10.0, 20.0, 30.0]) {
        await dragOne.moveTo(
          center - const Offset(50, 30) + Offset(-distance, distance),
        );
        await dragTwo.moveTo(
          center + const Offset(50, 30) + Offset(-distance, distance),
        );
        await tester.pump();
      }
      expect(
        painter().capacity!,
        closeTo(40, .001),
        reason:
            'Moving two fingers together must pan without changing their zoom',
      );
      expect(painter().endOffset, greaterThan(7.2));
      final pannedRange = painter().cameraRange!;
      await dragOne.moveTo(center + const Offset(-30, -30));
      await dragTwo.moveTo(center + const Offset(-30, 90));
      await tester.pump();
      expect(painter().capacity!.isFinite, isTrue);
      expect(
        painter().cameraRange!.$2 - painter().cameraRange!.$1,
        lessThan((pannedRange.$2 - pannedRange.$1) * 2),
        reason: 'Changing pinch orientation must not explode an axis scale',
      );
      await dragOne.up();
      await tester.pump();
      final beforeLiftMove = painter().cameraRange!;
      await dragTwo.moveBy(const Offset(0, -10));
      await tester.pump();
      expect(
        (painter().cameraRange!.$2 - painter().cameraRange!.$1),
        closeTo(beforeLiftMove.$2 - beforeLiftMove.$1, .000001),
        reason: 'Lifting one finger must retain zoom and continue panning',
      );
      await dragTwo.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 400));
    },
  );
  test(
    'Market geometry anchors Players at prior totals and uses observed activity ranges',
    () {
      final b = Map<String, dynamic>.from(
        (fixture()['bins'] as List).first as Map,
      );
      final players = contactMarketCandleRoyalClean(b, 'Players')!;
      expect(players.open, 100);
      expect(players.high, 108);
      expect(players.close, 103);
      expect(players.paired, true);
      final activity = contactMarketCandleRoyalClean(b, 'Atividade')!;
      expect(activity.open, 5);
      expect(activity.high, 7);
      expect(activity.low, 2);
      expect(activity.close, 4);
      expect(activity.paired, false);
    },
  );
  testWidgets(
    'Preview Desempenho opens dedicated overview instead of scrolling to partners',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PreviewPageRoyalClean()));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Desempenho'));
      await tester.pumpAndSettle();
      expect(find.byType(PerformanceOverviewPageRoyalClean), findsOneWidget);
      expect(find.byType(PublicActivityIndexRoyalClean), findsOneWidget);
      expect(find.byType(ContactsPerformanceRoyalClean), findsNothing);
      expect(find.byType(DashboardChartRoyalClean), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Public index renders real fractional OHLC and updates closing value without private queries',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = StreamController<Map<String, dynamic>?>();
      final periods = <String>[];
      Map<String, dynamic> publicData(double close) => {
        'source': 'royal-clean',
        'method': 'royal-activity-v1',
        'unit': 'points',
        'period': 'daily',
        'generatedAt': DateTime.now().millisecondsSinceEpoch,
        'bins': [
          {
            'start': 1791774000000,
            'end': 1791860400000,
            'indexPoints': true,
            'activityOpen': 100.0,
            'activityClose': close,
            'activityHigh': 100.0005,
            'activityLow': 99.999,
            'closed': false,
            'volume': .012,
            'coverage': .1,
            'activityPartial': true,
            'referenceOrigin': 'initial',
          },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PublicActivityIndexRoyalClean(
                watch: (period) {
                  periods.add(period);
                  return period == 'daily'
                      ? controller.stream
                      : Stream.value(null);
                },
              ),
            ),
          ),
        ),
      );
      controller.add(publicData(100.0005));
      await tester.pumpAndSettle();
      expect(find.text('100.000500 pts'), findsOneWidget);
      expect(find.byType(ContactsPerformanceRoyalClean), findsNothing);
      final candle = contactMarketCandleRoyalClean(
        (publicData(100.0005)['bins'] as List).first,
        'Atividade',
      )!;
      expect(candle.open, 100);
      expect(candle.movement, .012);
      controller.add(publicData(99.999));
      await tester.pumpAndSettle();
      expect(find.text('99.999000 pts'), findsOneWidget);
      expect(find.text('-0.001000 pts no período atual'), findsOneWidget);
      await tester.tap(find.byTooltip('Período do índice'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'Semanal'),
      );
      await tester.pumpAndSettle();
      expect(periods, ['daily', 'weekly']);
      expect(
        find.text('99.999000 pts'),
        findsNothing,
      ); // Do not show the old daily value under a weekly label.
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      unawaited(controller.close());
    },
  );

  testWidgets(
    'Dedicated app contacts queries only after authorization and never loads Bling',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final access = StreamController<AdminAccessRoyalClean>();
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: PerformanceOverviewPageRoyalClean(
            accessStream: () => access.stream,
            load: (query) async {
              calls.add(query);
              return fixture();
            },
          ),
        ),
      );
      await tester.pump();
      expect(calls, isEmpty);
      access.add(AdminAccessRoyalClean.allowed);
      await tester.pumpAndSettle();
      expect(find.text('Visão geral'), findsOneWidget);
      expect(find.text('Desempenho'), findsOneWidget);
      expect(calls.first, {'period': 'daily'});
      expect(find.byType(DashboardChartRoyalClean), findsNothing);
      expect(find.byType(ContactsPerformanceRoyalClean), findsOneWidget);
      expect(find.text('Positiva: 8'), findsOneWidget);
      expect(find.text('Negativa: 5'), findsOneWidget);
      expect(
        Theme.of(
          tester.element(find.byType(ContactsPerformanceRoyalClean)),
        ).brightness,
        Brightness.dark,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Registrados'));
      await tester.pumpAndSettle();
      expect(find.text('Registrados: 8'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Atividade'));
      await tester.pumpAndSettle();
      expect(find.text('Online: 4'), findsOneWidget);
      expect(find.text('Ausentes: 6'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Processando'));
      await tester.pumpAndSettle();
      expect(find.text('Processando: 3'), findsOneWidget);
      expect(find.textContaining('Negativa:'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Deletados'));
      await tester.pumpAndSettle();
      expect(find.text('Deletados: 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Estilo do gráfico'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'Linha'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('As regras de Linha e Área'), findsOneWidget);
      access.add(AdminAccessRoyalClean.denied);
      await tester.pumpAndSettle();
      expect(find.byType(DashboardChartRoyalClean), findsNothing);
      expect(find.byType(ContactsPerformanceRoyalClean), findsNothing);
      expect(
        find.text('Acesso restrito a administradores ativos.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      unawaited(access.close());
    },
  );
}
