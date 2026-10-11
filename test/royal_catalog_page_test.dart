import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:royal_clean/presentation_royal_clean/home/royal_catalog_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/catalog_audit_card_royal_clean.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Mobile audit uses two columns, description search and audited photos',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: RoyalCatalogPageRoyalClean(
            production: true,
            load: (input) async => {
              'items': [
                {
                  'id': 'b_1',
                  'title': 'Bobina',
                  'code': 'B1',
                  'description': 'Embalagem resistente',
                  'audited': input['filter'] == 'integrated',
                  'presentations': [
                    {'imageUrl': 'https://example.test/bobina.jpg'},
                  ],
                },
                {
                  'id': 'b_2',
                  'title': 'Detergente',
                  'code': 'D1',
                  'audited': false,
                },
              ],
              'cursor': null,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('audit-product-b_1'));
      final second = find.byKey(const ValueKey('audit-product-b_2'));
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
      expect(
        tester.getTopLeft(second).dx,
        greaterThan(tester.getTopRight(first).dx),
      );
      expect(find.byType(CatalogAuditPlaceholderRoyalClean), findsNWidgets(2));
      await tester.enterText(find.byType(TextField), 'resistente');
      await tester.pumpAndSettle();
      expect(find.text('Bobina'), findsOneWidget);
      expect(find.text('Detergente'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Integrados'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: first,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is ResizeImage &&
                (widget.image as ResizeImage).imageProvider is NetworkImage,
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Production keeps audit filters separate and requests the selected source page',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: RoyalCatalogPageRoyalClean(
            production: true,
            load: (input) async {
              calls.add(input);
              return {
                'items': [
                  {
                    'id': 'b_1',
                    'title': 'Bobina 20 x 30',
                    'code': 'BOB20',
                    'sourceId': '1',
                    'audited': input['filter'] == 'integrated',
                  },
                ],
                'cursor': null,
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Disponíveis'), findsOneWidget);
      expect(find.text('Integrados'), findsOneWidget);
      expect(find.text('Excluídos'), findsOneWidget);
      expect(find.text('Criar produto'), findsOneWidget);
      expect(calls.last['filter'], 'available');
      await tester.tap(find.text('Integrados'));
      await tester.pumpAndSettle();
      expect(calls.last['filter'], 'integrated');
      expect(find.textContaining('Auditoria concluída'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'inexistente');
      await tester.pumpAndSettle();
      expect(find.text('Bobina 20 x 30'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Products lists publication states and allows paging even when a filtered source page is empty',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: RoyalCatalogPageRoyalClean(
            load: (input) async {
              calls.add(input);
              return {
                'items': input['cursor'] == null
                    ? []
                    : [
                        {
                          'id': 'n_2',
                          'title': 'Produto auditado',
                          'code': 'RC2',
                          'audited': true,
                          'stock': {'boxes': 2, 'loose': 1},
                        },
                      ],
                'cursor': input['cursor'] == null ? 'cursor_1' : null,
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Receitas',
        'Publicado',
        'Observação',
        'Suspensos',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Criar produto'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Carregar próxima página'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Carregar próxima página'));
      await tester.pumpAndSettle();
      expect(calls.last['cursor'], 'cursor_1');
      expect(find.text('Produto auditado'), findsOneWidget);
      expect(find.textContaining('2 caixas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
