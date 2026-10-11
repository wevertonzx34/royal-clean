import 'package:flutter/material.dart';
import 'package:royal_clean/presentation_royal_clean/home/office_shortcut_royal_clean.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/stock_data_shortcut_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/image_action_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/stock_lighting_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/stock_functions_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/production_drawer_royal_clean.dart';

void main() {
  testWidgets('Open drawer keeps production toggle and office accessible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var officeOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
          child: StockFunctionsPageRoyalClean(
            onOpenOffice: () async => officeOpens++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final production = find.byKey(const ValueKey('royal-producao-shortcut'));
    final office = find.byKey(const ValueKey('royal-office-shortcut'));
    final productionRect = tester.getRect(production);
    final officeRect = tester.getRect(office);
    await tester.tap(production);
    await tester.pumpAndSettle();
    expect(find.byType(ProductionDrawerRoyalClean), findsOneWidget);
    expect(production.hitTestable(), findsOneWidget);
    expect(office.hitTestable(), findsOneWidget);
    expect(tester.getRect(production), productionRect);
    expect(tester.getRect(office), officeRect);
    await tester.tap(production);
    await tester.pumpAndSettle();
    expect(find.byType(ProductionDrawerRoyalClean), findsNothing);
    await tester.tap(production);
    await tester.pumpAndSettle();
    expect(find.byType(ProductionDrawerRoyalClean), findsOneWidget);
    await tester.tap(office);
    await tester.pumpAndSettle();
    expect(officeOpens, 1);
    expect(find.byType(ProductionDrawerRoyalClean), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Production can close its drawer during the tap animation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: StockFunctionsPageRoyalClean()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final production = find.byKey(const ValueKey('royal-producao-shortcut'));
    await tester.tap(production);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ProductionDrawerRoyalClean), findsOneWidget);
    await tester.tap(production);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ProductionDrawerRoyalClean), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Rapid 3D taps each trigger lighting during the active animation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StockBackgroundRoyalClean(showOffice: true)),
        ),
      );
      await tester.pump();
      final target = find.byKey(const ValueKey('royal-3d-shortcut'));
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(target);
      final lighting = tester.widget<StockLightingRoyalClean>(
        find.byType(StockLightingRoyalClean),
      );
      expect(lighting.trigger.value, 3);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Production opens while stock retains its three shortcuts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(390, 844), disableAnimations: true),
          child: StockFunctionsPageRoyalClean(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final notifications = find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == 'Notifica\u00e7\u00f5es',
    );
    final myData = find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == 'Meus dados',
    );
    final overview = find.byKey(const ValueKey('stock-data-shortcut'));
    final positions = [
      tester.getRect(notifications),
      tester.getRect(myData),
      tester.getRect(overview),
    ];
    await tester.tap(find.byKey(const ValueKey('royal-producao-shortcut')));
    await tester.pumpAndSettle();
    expect(tester.getRect(notifications), positions[0]);
    expect(tester.getRect(myData), positions[1]);
    expect(tester.getRect(overview), positions[2]);
    expect(notifications.hitTestable(), findsOneWidget);
    expect(myData.hitTestable(), findsOneWidget);
    expect(overview.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Production opens on tap without waiting for its animation', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 200,
            height: 160,
            child: OfficeShortcutRoyalClean.production(
              onOpen: () async => opens++,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('royal-producao-shortcut')));
    expect(opens, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Stock data shortcut preserves home dimensions and opens overview',
    (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: StockDataShortcutRoyalClean(
                  onOpen: () async {
                    opens++;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final target = find.byKey(const ValueKey('stock-data-shortcut'));
      expect(tester.getSize(target), const Size(100, 100));
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Immediate feedback runs once before the 120 ms animation ends', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ImageActionRoyalClean(
            activateBeforeAnimation: true,
            duration: const Duration(milliseconds: 120),
            onActivate: () {
              calls++;
            },
            builder: (_, flash) => const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ImageActionRoyalClean));
    expect(calls, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
  testWidgets('Royal 3D tap flashes windows; hold only opens property', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(432, 912));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var visits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StockBackgroundRoyalClean(
            showOffice: true,
            onOpenProperty: () async {
              visits++;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final target = find.byKey(const ValueKey('royal-3d-shortcut'));
    final trigger = tester
        .widget<StockLightingRoyalClean>(find.byType(StockLightingRoyalClean))
        .trigger;
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(trigger.value, 1);
    expect(visits, 0);
    await tester.longPress(target);
    await tester.pumpAndSettle();
    expect(visits, 1);
    expect(trigger.value, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Stock background covers mobile viewport with accessible standard header',
    (tester) async {
      for (final size in [const Size(320, 640), const Size(800, 400)]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: StockFunctionsPageRoyalClean(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Funções de estoque'), findsOneWidget);
        final background = find.byType(Image).first;
        final rendered = tester.getRect(background);
        expect(rendered.left, lessThanOrEqualTo(0));
        expect(rendered.top, lessThanOrEqualTo(0));
        expect(rendered.right, greaterThanOrEqualTo(size.width));
        expect(rendered.bottom, greaterThanOrEqualTo(size.height));
        expect(
          tester.widget<FittedBox>(find.byType(FittedBox).first).fit,
          BoxFit.cover,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}
