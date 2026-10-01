import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/core_royal_clean/theme/app_theme_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/services/bling_sync_events_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/dashboard_chart_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/dashboard_data_royal_clean.dart';

Map<String, dynamic> sample(Map<String, dynamic> query) => {
  'records': 3,
  'partial': true,
  'checkedAt': '2026-09-26T12:00:00Z',
  'labels': ['A', 'B'],
  'details': ['Intervalo A', 'Intervalo B'],
  'metrics': [
    {
      'label': 'Quantidade',
      'unit': 'registros',
      'money': false,
      'values': [1, 2],
    },
  ],
};
Widget host(
  Future<Map<String, dynamic>> Function(Map<String, dynamic>) load, {
  double scale = 1,
}) => MaterialApp(
  theme: AppThemeRoyalClean.theme,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DashboardChartRoyalClean(load: load),
        ),
      ),
    ),
  ),
);
void main() {
  testWidgets(
    'Sync keeps the previous chart visible while the new snapshot loads',
    (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      final pending = Completer<Map<String, dynamic>>();
      var calls = 0;
      await tester.pumpWidget(
        host((q) {
          calls++;
          if (calls == 1) expect(q['group'], 'invoices');
          return calls == 1 ? Future.value(sample(q)) : pending.future;
        }),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('Notas')).dx,
        lessThan(tester.getCenter(find.text('Produtos')).dx),
      );
      expect(find.text('3 registros'), findsOneWidget);
      blingSyncRevisionRoyalClean.value++;
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(calls, 2);
      expect(find.text('3 registros'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      pending.complete({
        ...sample({}),
        'records': 4,
        'metrics': [
          {
            'label': 'Quantidade',
            'unit': 'registros',
            'money': false,
            'values': [2, 2],
          },
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('4 registros'), findsOneWidget);
    },
  );

  testWidgets(
    'Pending imports refresh the visible snapshot without starting Bling reads or hiding the chart',
    (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        host((q) async {
          calls.add(q);
          return {
            ...sample(q),
            'catalogPending': calls.length == 1,
            'records': calls.length == 1 ? 3 : 4,
            'metrics': [
              {
                'label': 'Quantidade',
                'unit': 'registros',
                'money': false,
                'values': [calls.length == 1 ? 1 : 2, 2],
              },
            ],
          };
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 registros'), findsOneWidget);
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('4 registros'), findsOneWidget);
      expect(calls.every((q) => q['refreshDetails'] != true), true);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(calls.length, 2);
    },
  );

  testWidgets(
    'Complete catalog labels active and inactive total separately from excluded',
    (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(
        host(
          (q) async => {
            ...sample(q),
            'records': 427,
            'partial': false,
            'excluded': 112,
            'metrics': [
              {
                'label': 'Cadastros',
                'unit': 'registros',
                'money': false,
                'values': [426, 1],
              },
            ],
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Produtos'));
      await tester.pumpAndSettle();
      expect(find.text('427 registros'), findsOneWidget);
      expect(find.textContaining('catálogo completo'), findsOneWidget);
      expect(find.textContaining('112 excluídos'), findsOneWidget);
      expect(find.textContaining('base parcial'), findsNothing);
    },
  );
  testWidgets(
    'Manual failure keeps the visible snapshot and late requests cannot replace it',
    (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      var fail = false;
      await tester.pumpWidget(
        host((q) async {
          if (fail && q['refreshSince'] != null) throw Exception('offline');
          return sample(q);
        }),
      );
      await tester.pumpAndSettle();
      fail = true;
      await tester.tap(find.byTooltip('Atualizar resumo'));
      await tester.pumpAndSettle();
      expect(find.text('3 registros'), findsOneWidget);
      expect(
        find.textContaining('Os dados anteriores foram mantidos'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Background fallback refresh updates all groups, reuses cache and manual refresh bypasses freshness',
    (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        host((q) async {
          calls.add(q);
          return sample(q);
        }),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Produtos'));
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(calls.length, 5);
      expect(calls.skip(2).map((q) => q['group']).toSet(), {
        'products',

        'invoices',
        'contacts',
      });
      expect(
        calls
            .skip(2)
            .every(
              (q) => q['refreshDetails'] != true && q['refreshSince'] == null,
            ),
        true,
      );
      await tester.tap(find.byTooltip('Atualizar resumo'));
      await tester.pumpAndSettle();
      expect(calls.length, 8);
      expect(
        calls
            .skip(5)
            .every(
              (q) => q['refreshDetails'] == true && q['refreshSince'] != null,
            ),
        true,
      );
      await tester.tap(find.text('Contatos'));
      await tester.pumpAndSettle();
      expect(calls.length, 8);
    },
  );
  testWidgets(
    'Invoice options keep fiscal totals below consultation and unknown payment is not zero',
    (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(
        host(
          (q) async => {
            ...sample(q),
            'summary': {
              'label': 'Valor trimestral',
              'value': 100,
              'count': 2,
              'financialCount': 1,
              'missingAmounts': 0,
              'start': '2026-07-01',
              'end': '2026-09-26',
            },
            'metrics': [
              for (final name in [
                'Faturamento',
                'Quantidade',
                'Autorizadas',
                'Canceladas',
                'Entregues',
                'Pagas',
                'Pendentes',
              ])
                {
                  'label': name,
                  'unit': 'notas',
                  'money': name == 'Faturamento',
                  'values': [0, name == 'Faturamento' ? 100 : 1],
                  if (name == 'Pagas')
                    'unavailable': 'Pagamento ainda não conciliado.',
                },
            ],
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notas'));
      await tester.pumpAndSettle();
      final chips = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .map((c) => (c.label as Text).data)
          .toList();
      expect(chips, [
        'Faturamento',
        'Quantidade',
        'Autorizadas',
        'Canceladas',
        'Entregues',
        'Pagas',
        'Pendentes',
      ]);
      expect(
        tester.getTopLeft(find.textContaining('Valor trimestral')).dy,
        greaterThan(
          tester.getBottomLeft(find.textContaining('Última consulta:')).dy,
        ),
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Pagas'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Pagas'));
      await tester.pumpAndSettle();
      expect(find.text('Pagamento ainda não conciliado.'), findsOneWidget);
      expect(find.byKey(const ValueKey('dashboard-month-value')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Financial summaries retain quantity and value while horizontal filters query the server',
    (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final queries = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        host((input) async {
          queries.add(input);
          return {
            ...sample(input),
            'baseRecords': 3,
            'summary': {
              'label': 'Valor trimestral',
              'value': 123.45,
              'count': 3,
              'missingAmounts': 0,
              'start': '2026-07-01',
              'end': '2026-09-26',
              'futureValue': 50,
              'futureCount': 1,
              'futureMissing': 0,
            },
            'metrics': [
              {
                'label': 'Quantidade',
                'unit': 'notas',
                'money': false,
                'values': [1, 2],
              },
              {
                'label': 'Valor',
                'unit': '',
                'money': true,
                'values': [23.45, 100],
              },
            ],
          };
        }),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notas'));
      await tester.pumpAndSettle();
      expect(find.text('R\$ 123,45'), findsOneWidget);
      expect(find.text('3 notas no período'), findsOneWidget);
      expect(find.text('Pedidos'), findsNothing);
      await tester.ensureVisible(find.text('Contatos'));
      await tester.tap(find.text('Contatos'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Clientes'));
      await tester.pumpAndSettle();
      expect(queries.last['contactRole'], 'customer');
      await tester.drag(
        find.byKey(const ValueKey('filters-Contatos')),
        const Offset(-100, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Fornecedores'));
      await tester.pumpAndSettle();
      expect(queries.last['contactRole'], 'supplier');
      await tester.drag(
        find.byKey(const ValueKey('filters-Contatos')),
        const Offset(700, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
      await tester.pumpAndSettle();
      expect(
        queries.any(
          (q) => q['group'] == 'contacts' && q['contactRole'] == 'all',
        ),
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Todos'))
            .selected,
        isTrue,
      );
      final beforeReselect = queries.length;
      await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
      await tester.pumpAndSettle();
      expect(queries.length, beforeReselect);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Todos'))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Real summaries switch all groups and periods; synced data invalidates dashboard',
    (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        host((input) async {
          calls.add(input);
          return sample(input);
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 registros'), findsOneWidget);
      expect(find.textContaining('base parcial'), findsOneWidget);
      expect(find.text('Usuários'), findsNothing);
      expect(find.text('Tokens'), findsNothing);
      expect(find.byTooltip('Período do gráfico'), findsOneWidget);
      expect(
        find.byType(DropdownButtonFormField<DashboardPeriodRoyalClean>),
        findsNothing,
      );
      for (final group in {
        'Produtos': 'products',

        'Notas': 'invoices',
        'Contatos': 'contacts',
      }.entries) {
        await tester.ensureVisible(find.text(group.key));
        await tester.tap(find.text(group.key));
        await tester.pumpAndSettle();
        expect(calls.last['group'], group.value);
        final clock = tester.getRect(find.byTooltip('Período do gráfico'));
        final style = tester.getRect(find.byTooltip('Estilo do gráfico'));
        expect(clock.right, lessThanOrEqualTo(style.left));
        expect(clock.center.dy, style.center.dy);
        expect(
          style.right,
          lessThanOrEqualTo(
            tester.getRect(find.byTooltip('Atualizar resumo')).left,
          ),
        );
        for (final period in DashboardPeriodRoyalClean.values) {
          await tester.tap(find.byKey(const ValueKey('dashboard-period')));
          await tester.pumpAndSettle();
          if (group.value == 'products' || group.value == 'contacts') {
            expect(
              find.textContaining('Sem histórico por data'),
              findsOneWidget,
            );
          }
          final option = find.widgetWithText(
            CheckedPopupMenuItem<DashboardPeriodRoyalClean>,
            period.label,
          );
          await tester.ensureVisible(option);
          await tester.tap(option);
          await tester.pumpAndSettle();
          expect(
            calls.any(
              (q) => q['group'] == group.value && q['period'] == period.name,
            ),
            true,
          );
        }
      }
      final count = calls.length;
      blingSyncRevisionRoyalClean.value++;
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(calls.length, count + 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Failure never becomes zero and late responses cannot replace current category',
    (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      final pending = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        host((input) async {
          if (input['group'] == 'products') return pending.future;
          if (input['group'] == 'invoices') throw Exception('offline');
          return {...sample(input), 'records': 0};
        }),
      );
      await tester.tap(find.text('Notas'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Não foi possível'), findsOneWidget);
      expect(find.byKey(const ValueKey('dashboard-total')), findsNothing);
      pending.complete(sample({}));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('dashboard-total')), findsNothing);
      await tester.tap(find.text('Contatos'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ainda não há registros'), findsOneWidget);
    },
  );
  testWidgets(
    'Compact chart fits narrow screens and large text in every style',
    (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [320.0, 390.0, 720.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(host((input) async => sample(input)));
        await tester.pumpAndSettle();
        expect(
          tester
              .getSize(find.byKey(const ValueKey('admin-dashboard-chart')))
              .height,
          lessThan(600),
        );
        for (final style in ['Barras', 'Linha', 'Área']) {
          await tester.ensureVisible(find.byTooltip('Estilo do gráfico'));
          await tester.tap(find.byTooltip('Estilo do gráfico'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(style).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(
          host((input) async => sample(input), scale: 1.6),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
