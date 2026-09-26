import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:royal_clean/presentation_royal_clean/home/bling_data_page_royal_clean.dart';

void main() {
  testWidgets('Contacts paginate, search and refresh without date filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final queries = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: BlingDataPageRoyalClean(
          load: (input) async {
            queries.add(input);
            return {
              'items': input['kind'] == 'contacts'
                  ? [
                      {
                        'name': 'Loja ${input['page']}',
                        'code': 'C1',
                        'status': 'A',
                        'document': '00000000000100',
                      },
                    ]
                  : [],
              'hasMore': true,
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clientes e fornecedores'));
    await tester.pumpAndSettle();
    expect(queries.last, {'kind': 'contacts', 'page': 1});
    expect(find.text('Loja 1'), findsOneWidget);
    await tester.ensureVisible(find.text('Próxima'));
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    expect(queries.last['page'], 2);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Loja');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(queries.last, {'kind': 'contacts', 'page': 1, 'search': 'Loja'});
    await tester.tap(find.byTooltip('Limpar pesquisa de contatos'));
    await tester.pumpAndSettle();
    expect(queries.last, {'kind': 'contacts', 'page': 1});
    await tester.tap(find.text('Atualizar do Bling'));
    await tester.pumpAndSettle();
    expect(queries.last, {'kind': 'contacts', 'page': 1});
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Long press opens Products for the selected invoice and returns to list',
    (tester) async {
      final queries = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: BlingDataPageRoyalClean(
            load: (input) async {
              queries.add(input);
              if (input['kind'] == 'invoiceItems') {
                return {
                  'invoice': {'statusLabel': 'Autorizada'},
                  'total': 22,
                  'freight': 2,
                  'items': [
                    {
                      'description': 'Produto da nota',
                      'code': 'SKU',
                      'quantity': 2,
                      'unit': 'UN',
                      'unitPrice': 10,
                      'total': 20,
                    },
                  ],
                };
              }
              return {
                'items': input['kind'] == 'invoices'
                    ? [
                        {
                          'id': '123',
                          'code': '10',
                          'date': '2026-09-25',
                          'operationDate': '2026-09-25',
                          'statusLabel': 'Autorizada',
                          'accessKey': '',
                        },
                      ]
                    : [],
                'hasMore': false,
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notas de saída'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('NF-e 10'));
      await tester.longPress(find.text('NF-e 10'));
      await tester.pumpAndSettle();
      final card = find.ancestor(
        of: find.text('NF-e 10'),
        matching: find.byType(Card),
      );
      final action = find.byType(PopupMenuItem<bool>);
      expect(action, findsOneWidget);
      expect(tester.getRect(card).overlaps(tester.getRect(action)), isTrue);
      expect(find.byType(BottomSheet), findsNothing);
      // Dismiss without fetching details, then reopen using the accessible menu.
      await tester.tapAt(const Offset(8, 100));
      await tester.pumpAndSettle();
      expect(action, findsNothing);
      expect(queries.where((q) => q['kind'] == 'invoiceItems'), isEmpty);
      await tester.tap(find.byTooltip('Opções da NF-e 10'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Produtos').last);
      await tester.pumpAndSettle();
      expect(queries.last, {'kind': 'invoiceItems', 'invoiceId': '123'});
      expect(find.text('Produto da nota'), findsOneWidget);
      expect(find.text('Total do item: R\$ 20,00'), findsOneWidget);
      await tester.tap(find.text('Voltar às notas'));
      await tester.pumpAndSettle();
      expect(find.text('NF-e 10'), findsOneWidget);
      expect(find.text('Produto da nota'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Invoice filter queries outgoing notes with dates and cancellation status',
    (tester) async {
      final queries = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: BlingDataPageRoyalClean(
            load: (input) async {
              queries.add(input);
              return {
                'items': input['kind'] == 'invoices'
                    ? [
                        {
                          'code': '10',
                          'date': '2026-09-25',
                          'operationDate': '2026-09-25',
                          'statusLabel': input['invoiceStatus'] == 2
                              ? 'Cancelada'
                              : 'Autorizada',
                          'accessKey': '',
                        },
                      ]
                    : [],
                'hasMore': false,
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notas de saída'));
      await tester.pumpAndSettle();
      expect(queries.last['kind'], 'invoices');
      expect(queries.last['start'], isNotNull);
      expect(find.text('NF-e 10'), findsOneWidget);
      await tester.ensureVisible(find.text('Não canceladas'));
      await tester.tap(find.text('Não canceladas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelada').last);
      await tester.pumpAndSettle();
      expect(queries.last['invoiceStatus'], 2);
      expect(queries.last['page'], 1);
      expect(find.text('Situação: Cancelada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
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
