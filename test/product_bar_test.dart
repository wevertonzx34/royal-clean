import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/core_royal_clean/services/active_contacts_cache_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/product_bar_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/dashboard_chart_royal_clean.dart';

void main() {
  final rows = <Map<String, dynamic>>[
    {
      'id': '1',
      'name': 'Produto ativo',
      'code': 'SKU1',
      'status': 'A',
      'price': 12.5,
      'stock': 3,
      'unit': 'UN',
    },
    {'id': '2', 'name': 'Produto inativo', 'code': 'SKU2', 'status': 'I'},
    {'id': '3', 'name': 'Produto outro', 'status': ''},
    {'id': '4', 'name': 'Produto excluído', 'status': 'E'},
  ];
  test(
    'Each product bar matches its status, with no excluded product in Others',
    () {
      expect(productsInBarRoyalClean(rows, 'Ativos').map((r) => r['id']), [
        '1',
      ]);
      expect(productsInBarRoyalClean(rows, 'Inativos').map((r) => r['id']), [
        '2',
      ]);
      expect(productsInBarRoyalClean(rows, 'Outros').map((r) => r['id']), [
        '3',
      ]);
    },
  );
  testWidgets(
    'Bar opens matching products and warm reopening does not fetch again',
    (tester) async {
      var calls = 0;
      final cache = ActiveContactsCacheRoyalClean(
        kind: 'productCatalog',
        load: (q) async {
          calls++;
          expect(q['kind'], 'productCatalog');
          return {
            'items': rows,
            'total': 4,
            'hasMore': false,
            'catalogRun': 'r1',
            'checkedAt': '2026-09-27T03:00:00Z',
          };
        },
      );
      cache.setOwner('admin');
      await cache.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardChartRoyalClean(
                productCache: cache,
                load: (q) async => {
                  'catalogRun': 'r1',
                  'records': 3,
                  'labels': ['Ativos', 'Inativos', 'Outros'],
                  'details': ['Ativos', 'Inativos', 'Outros'],
                  'metrics': [
                    {
                      'label': 'Cadastros',
                      'money': false,
                      'unit': 'registros',
                      'values': [1, 1, 1],
                    },
                  ],
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Produtos').first);
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        final plot = find.byKey(const ValueKey('dashboard-plot'));
        await tester.ensureVisible(plot);
        final rect = tester.getRect(plot);
        await tester.tapAt(Offset(rect.left + 60, rect.center.dy));
        await tester.pumpAndSettle();
        expect(find.text('Produtos da barra'), findsOneWidget);
        expect(find.text('Produto ativo'), findsOneWidget);
        expect(find.text('Código: SKU1'), findsOneWidget);
        expect(find.text('Produto inativo'), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      cache.dispose();
    },
  );
}
