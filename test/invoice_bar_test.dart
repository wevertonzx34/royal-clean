import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/core_royal_clean/services/active_contacts_cache_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/services/invoice_list_cache_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/invoice_bar_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/dashboard_chart_royal_clean.dart';

final rows = <Map<String, dynamic>>[
  {
    'id': '1',
    'code': '101',
    'recipientName': 'Empresa primeira',
    'recipientDocument': '12345678000190',
    'date': '2026-09-01 00:00:00',
    'metricKeys': ['Faturamento', 'Quantidade', 'Autorizadas'],
  },
  {
    'id': '2',
    'code': '102',
    'recipientName': 'Empresa última',
    'recipientDocument': '98765432000190',
    'date': '2026-09-30 23:59:59',
    'metricKeys': ['Faturamento', 'Quantidade', 'Autorizadas'],
  },
  {
    'id': '3',
    'code': '103',
    'recipientName': 'Cancelada',
    'date': '2026-09-20 12:00:00',
    'metricKeys': ['Quantidade', 'Canceladas'],
  },
  {
    'id': '4',
    'code': '104',
    'date': '2026-10-01 00:00:00',
    'metricKeys': ['Faturamento', 'Quantidade'],
  },
  {
    'id': '5',
    'code': '105',
    'date': '2026-02-30 12:00:00',
    'metricKeys': ['Quantidade'],
  },
];
void main() {
  testWidgets(
    'Long press loads only selected invoice products and returns to warm list',
    (tester) async {
      final queries = <Map<String, dynamic>>[];
      final cache = ActiveContactsCacheRoyalClean(
        kind: 'invoiceCatalog',
        load: (_) async => {
          'items': [rows.first],
          'total': 1,
          'hasMore': false,
          'catalogRun': 'r1',
        },
      );
      cache.setOwner('admin');
      await cache.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: InvoiceBarPageRoyalClean(
            start: '2026-09-01',
            endExclusive: '2026-10-01',
            metric: 'Quantidade',
            periodLabel: 'Setembro',
            cache: cache,
            loadItems: (query) async {
              queries.add(query);
              return {
                'items': [
                  {
                    'description': 'Produto da nota selecionada',
                    'code': 'SKU1',
                    'quantity': 2,
                    'unit': 'UN',
                    'unitPrice': 5,
                    'total': 10,
                  },
                ],
                'total': 10,
                'freight': 0,
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Empresa primeira'));
      await tester.pumpAndSettle();
      expect(queries, [
        {'kind': 'invoiceItems', 'invoiceId': '1'},
      ]);
      expect(find.text('Produto da nota selecionada'), findsOneWidget);
      await tester.tap(find.text('Voltar às notas'));
      await tester.pumpAndSettle();
      expect(find.text('Notas do período'), findsOneWidget);
      expect(find.text('Empresa primeira'), findsOneWidget);
      expect(queries.length, 1);
    },
  );
  test(
    'Date boundaries include last second, exclude next day, and retain fiscal filter',
    () {
      expect(
        invoicesInBarRoyalClean(
          rows,
          start: '2026-09-01',
          endExclusive: '2026-10-01',
          metric: 'Faturamento',
        ).map((r) => r['id']),
        ['1', '2'],
      );
      expect(
        invoicesInBarRoyalClean(
          rows,
          start: '2026-09-01',
          endExclusive: '2026-10-01',
          metric: 'Canceladas',
        ).map((r) => r['id']),
        ['3'],
      );
      expect(
        invoicesInBarRoyalClean(
          rows,
          start: '2026-10-01',
          metric: 'Quantidade',
        ).map((r) => r['id']),
        ['4'],
      );
      expect(
        invoicesInBarRoyalClean(
          rows,
          start: '2026-01-01',
          endExclusive: '2026-03-01',
          metric: 'Quantidade',
        ),
        isEmpty,
      );
      expect(
        invoiceDateTimeRoyalClean('2026-09-30 23:59:59'),
        '30/09/2026 • 23:59:59',
      );
      expect(
        invoiceDateTimeRoyalClean('2026-09-30'),
        contains('horário não informado'),
      );
    },
  );
  testWidgets(
    'Warm invoice bar shows recipient fields immediately; return and reopening need no fetch',
    (tester) async {
      var calls = 0;
      final cache = ActiveContactsCacheRoyalClean(
        kind: 'invoiceCatalog',
        load: (q) async {
          calls++;
          expect(q['kind'], 'invoiceCatalog');
          return {
            'items': rows,
            'total': rows.length,
            'hasMore': false,
            'catalogRun': 'r1',
            'checkedAt': '2026-09-26T20:00:00Z',
          };
        },
      );
      cache.setOwner('admin');
      await cache.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openInvoiceBarRoyalClean(
                  context,
                  start: '2026-09-01',
                  endExclusive: '2026-10-01',
                  metric: 'Faturamento',
                  periodLabel: 'Setembro',
                  cache: cache,
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        expect(find.text('NF-e 101'), findsOneWidget);
        expect(find.text('Empresa primeira'), findsOneWidget);
        expect(find.text('12345678000190'), findsOneWidget);
        expect(find.text('01/09/2026 • 00:00:00'), findsOneWidget);
        expect(find.text('NF-e 103'), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      cache.dispose();
    },
  );
  testWidgets(
    'Graph forwards exact selected server range and preserves category after return',
    (tester) async {
      final cache = ActiveContactsCacheRoyalClean(
        kind: 'invoiceCatalog',
        load: (q) async => {
          'items': rows,
          'total': rows.length,
          'hasMore': false,
          'catalogRun': 'r1',
        },
      );
      cache.setOwner('admin');
      await cache.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardChartRoyalClean(
                invoiceCache: cache,
                load: (q) async => {
                  'records': 5,
                  'labels': ['Set/26'],
                  'details': ['2026-09-01 a 2026-09-30'],
                  'ranges': [
                    {'start': '2026-09-01', 'endExclusive': '2026-10-01'},
                  ],
                  'metrics': [
                    {
                      'label': 'Faturamento',
                      'money': true,
                      'unit': '',
                      'values': [100],
                    },
                  ],
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notas'));
      await tester.pumpAndSettle();
      final plot = find.byKey(const ValueKey('dashboard-plot'));
      await tester.ensureVisible(plot);
      await tester.tap(plot);
      await tester.pumpAndSettle();
      expect(find.text('Notas do período'), findsOneWidget);
      expect(find.text('2 notas neste intervalo'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Notas do período'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      cache.dispose();
    },
  );
}
