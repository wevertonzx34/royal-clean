import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/preview/preview_page_royal_clean.dart';

Map<String, dynamic> product(String id, String title) => {
  'id': id,
  'title': title,
  'description': 'Limpeza de superfícies',
  'code': id,
  'royalCatalog': true,
  'published': true,
  'imageUrl': 'https://example.test/$id.jpg',
  'presentation': 'unit',
  'pfCents': 2500,
  'pjCents': 2000,
  'categories': ['limpeza-profissional'],
  'niches': ['Dia a dia'],
  'updatedAt': '2026-10-11T12:00:00Z',
};

void main() {
  void phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'Products menu opens dedicated empty catalogue and preserves complete header',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(const MaterialApp(home: PreviewPageRoyalClean()));
      await tester.pumpAndSettle();
      final menu = find.widgetWithText(TextButton, 'Produtos');
      final position = tester.getRect(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('preview-products-page')),
        findsOneWidget,
      );
      expect(find.text('Nenhum produto publicado no momento.'), findsOneWidget);
      expect(find.text('Multiuso essencial'), findsNothing);
      expect(
        tester.getRect(find.widgetWithText(TextButton, 'Produtos')),
        position,
      );
      for (final title in [
        'Produtos',
        'Novidades',
        'Desempenho',
        'Sobre nós',
      ]) {
        expect(
          find.widgetWithText(TextButton, title).hitTestable(),
          findsOneWidget,
        );
      }
      expect(find.text('ROYAL CLEAN'), findsOneWidget);
      expect(find.byTooltip('Notificações').hitTestable(), findsOneWidget);
      expect(find.text('Login').hitTestable(), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Produtos'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('preview-products-page')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Voltar ao Preview'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preview-products-page')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Real publications form two columns and update, filter and disappear live',
    (tester) async {
      phone(tester);
      final feed = StreamController<List<Map<String, dynamic>>>();
      await tester.pumpWidget(
        MaterialApp(home: PreviewPageRoyalClean(products: feed.stream)),
      );
      feed.add([
        product('p1', 'Detergente'),
        product('p2', 'Bobina'),
        {...product('hidden', 'Rascunho'), 'published': false},
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Produtos'));
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('public-product-p1'));
      final second = find.byKey(const ValueKey('public-product-p2'));
      expect(first, findsOneWidget);
      expect(second, findsOneWidget);
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
      expect(
        tester.getTopLeft(second).dx,
        greaterThan(tester.getTopRight(first).dx),
      );
      expect(find.text('Rascunho · Unidade'), findsNothing);
      expect(find.text('R\$ 20,00'), findsNWidgets(2));
      expect(find.text('PF: R\$ 25,00'), findsNWidgets(2));
      expect(find.text('Limpeza de superfícies'), findsNWidgets(2));
      await tester.tap(find.byTooltip('Pesquisar produtos'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'superficies');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(first, findsOneWidget);
      feed.add([
        {
          ...product('p1', 'Produto atualizado'),
          'pjCents': 2200,
          'description': 'Novas superfícies',
        },
        {...product('p2', 'Bobina'), 'published': false},
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Produto atualizado · Unidade'), findsOneWidget);
      expect(find.text('R\$ 22,00'), findsOneWidget);
      expect(second, findsNothing);
      await tester.tap(find.byTooltip('Fechar pesquisa'));
      await tester.pumpAndSettle();
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(find.text('PRODUTO ROYAL CLEAN'), findsOneWidget);
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
      feed.add([]);
      await tester.pumpAndSettle();
      expect(find.text('Nenhum produto publicado no momento.'), findsOneWidget);
      expect(first, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => feed.close());
    },
  );

  testWidgets(
    'Dedicated header keeps session state and returns to preview sections',
    (tester) async {
      phone(tester);
      final session = StreamController<bool>();
      await tester.pumpWidget(
        MaterialApp(home: PreviewPageRoyalClean(authenticated: session.stream)),
      );
      session.add(true);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Produtos'));
      await tester.pumpAndSettle();
      expect(find.text('Perfil'), findsOneWidget);
      session.add(false);
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Novidades'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preview-products-page')), findsNothing);
      expect(find.text('NOSSA PARCERIA').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => session.close());
    },
  );

  testWidgets(
    'Compact accessible grid respects quote-only and excludes archived records',
    (tester) async {
      phone(tester, size: const Size(320, 720));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 720),
              textScaler: TextScaler.linear(2),
            ),
            child: PreviewPageRoyalClean(
              productsOnly: true,
              products: Stream.value([
                {
                  ...product('quote', 'Produto disponível para orçamento'),
                  'quoteOnly': true,
                },
                {...product('archived', 'Arquivado'), 'archived': true},
                {
                  ...product('unrelated', 'Outro cadastro'),
                  'royalCatalog': false,
                },
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('public-product-quote')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Solicitar orçamento'), findsOneWidget);
      expect(find.text('R\$ 20,00'), findsNothing);
      expect(
        find.byKey(const ValueKey('public-product-archived')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('public-product-unrelated')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
