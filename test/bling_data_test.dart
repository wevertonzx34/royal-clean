import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:royal_clean/presentation_royal_clean/home/bling_data_page_royal_clean.dart';

void main() {
  testWidgets(
    'Real products paginate and sales scope failures never display false zero totals',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final queries = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: BlingDataPageRoyalClean(
            load: (input) async {
              queries.add(input);
              if (input['kind'] == 'sales') {
                throw FirebaseFunctionsException(
                  code: 'permission-denied',
                  message: 'Habilite Pedidos de Venda no Bling.',
                );
              }
              return {
                'items': [
                  {
                    'name': 'Produto real ${input['page']}',
                    'code': 'ABC',
                    'unit': 'UN',
                    'price': 10.9,
                    'status': 'A',
                  },
                ],
                'hasMore': input['page'] == 1,
                'checkedAt': '2026-09-25T22:00:00Z',
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Produto real 1'), findsOneWidget);
      await tester.ensureVisible(find.text('Próxima'));
      await tester.tap(find.text('Próxima'));
      await tester.pumpAndSettle();
      expect(queries.last['page'], 2);
      expect(find.text('Produto real 2'), findsOneWidget);
      await tester.ensureVisible(find.text('Pedidos de venda'));
      await tester.tap(find.text('Pedidos de venda'));
      await tester.pumpAndSettle();
      expect(find.text('Habilite Pedidos de Venda no Bling.'), findsOneWidget);
      expect(find.textContaining('Soma dos'), findsNothing);
      expect(find.text('Produto real 2'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
