import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/core_royal_clean/theme/app_theme_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/dashboard_chart_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/dashboard_data_royal_clean.dart';

void main() {
  test('Periods preserve movement totals and use closing status counts', () {
    for (final metrics in dashboardMetricsRoyalClean.values) {
      for (final metric in metrics) {
        for (final period in [
          DashboardPeriodRoyalClean.monthly,
          DashboardPeriodRoyalClean.quarterly,
          DashboardPeriodRoyalClean.halfYear,
          DashboardPeriodRoyalClean.yearly,
        ]) {
          final series = dashboardSeriesRoyalClean(metric, period);
          expect(
            series.summary(metric.cumulative),
            closeTo(metric.summary, .001),
          );
          expect(series.labels.length, series.values.length);
          expect(series.details.length, series.values.length);
        }
        final weeks = dashboardSeriesRoyalClean(
          metric,
          DashboardPeriodRoyalClean.weekly,
        );
        expect(
          weeks.summary(metric.cumulative),
          closeTo(metric.values.last, .001),
        );
      }
    }
    final products = dashboardMetricsRoyalClean['Produtos']!;
    for (final period in DashboardPeriodRoyalClean.values) {
      final incoming = dashboardSeriesRoyalClean(products[0], period).values;
      final outgoing = dashboardSeriesRoyalClean(products[1], period).values;
      final flow = dashboardSeriesRoyalClean(products[3], period).values;
      for (var i = 0; i < flow.length; i++) {
        expect(flow[i], incoming[i] - outgoing[i]);
      }
    }
  });

  testWidgets(
    'All six periods work in bars, line and area and persist across groups',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemeRoyalClean.theme,
          home: const Scaffold(
            body: SingleChildScrollView(child: DashboardChartRoyalClean()),
          ),
        ),
      );
      for (final style in ['Barras', 'Linha', 'Área']) {
        await tester.ensureVisible(find.byTooltip(style));
        await tester.tap(find.byTooltip(style));
        await tester.pumpAndSettle();
        for (final period in DashboardPeriodRoyalClean.values) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('dashboard-period')),
          );
          await tester.tap(find.byKey(const ValueKey('dashboard-period')));
          await tester.pumpAndSettle();
          await tester.tap(find.text(period.label).last);
          await tester.pumpAndSettle();
          final series = dashboardSeriesRoyalClean(
            dashboardMetricsRoyalClean['Produtos']!.first,
            period,
          );
          expect(
            find.text('Dados simulados • ${series.range}'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('dashboard-month-value')),
                )
                .data,
            dashboardMetricsRoyalClean['Produtos']!.first.format(
              series.values.last,
            ),
          );
          expect(tester.takeException(), isNull);
        }
      }
      await tester.ensureVisible(find.text('Tokens'));
      await tester.tap(find.text('Tokens'));
      await tester.pumpAndSettle();
      expect(find.text('2026: Abr–Set (parcial)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Demo uses totals for movements and latest position for status counts',
    () {
      final products = dashboardMetricsRoyalClean['Produtos']!;
      expect(products[0].summary, 2690);
      expect(products[2].format(products[2].summary), 'R\$ 86.200,00');
      expect(dashboardMetricsRoyalClean['Usuários']!.first.summary, 246);
      for (var month = 0; month < 6; month++) {
        expect(
          products[3].values[month],
          products[0].values[month] - products[1].values[month],
        );
      }
    },
  );

  testWidgets('All categories and metrics update a single chart', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeRoyalClean.theme,
        home: const Scaffold(
          body: SingleChildScrollView(child: DashboardChartRoyalClean()),
        ),
      ),
    );
    for (final group in dashboardMetricsRoyalClean.entries) {
      await tester.ensureVisible(find.text(group.key));
      await tester.tap(find.text(group.key));
      await tester.pumpAndSettle();
      for (final metric in group.value) {
        await tester.ensureVisible(find.text(metric.label));
        await tester.tap(find.text(metric.label));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('admin-dashboard-chart')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('dashboard-total')))
              .data,
          metric.format(metric.summary),
        );
      }
    }
    for (final type in ['Barras', 'Linha', 'Área']) {
      await tester.ensureVisible(find.byTooltip(type));
      await tester.tap(find.byTooltip(type));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.ensureVisible(find.byTooltip('Mês anterior'));
    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Ago/2026'), findsOneWidget);
    expect(
      find.text('Dados simulados • Abril a setembro de 2026'),
      findsOneWidget,
    );
  });

  testWidgets('Chart fits narrow and wide screens, including large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [320.0, 720.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemeRoyalClean.theme,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: const TextScaler.linear(1.6),
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: DashboardChartRoyalClean(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
