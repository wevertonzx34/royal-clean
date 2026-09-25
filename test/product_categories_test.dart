import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/preview/preview_content_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/preview/preview_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/preview/product_categories_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/preview/product_filters_royal_clean.dart';

void main() {
  test('Seven categories cover samples and waste bags belong to cleaning', () {
    expect(productCategoriesRoyalClean.length, 7);
    expect(
      productCategoriesRoyalClean.any((c) => c.title == 'Sacos de lixo'),
      false,
    );
    for (final category in productCategoriesRoyalClean) {
      expect(
        previewProductsRoyalClean.any((p) => p.generalCategory == category.id),
        true,
      );
    }
    final bags = previewProductsRoyalClean.singleWhere(
      (p) => p.code == 'DEMO-SAC-100',
    );
    expect(bags.generalCategory, 'limpeza-profissional');
    expect(bags.tags, contains('sacos de lixo'));
  });

  testWidgets(
    'Categories stay pinned, combine with code search and toggle off',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: PreviewPageRoyalClean()));
      await tester.pumpAndSettle();
      final cleaning = find.widgetWithText(ChoiceChip, 'Limpeza profissional');
      await tester.tap(find.text('Produtos'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(ProductCategoriesRoyalClean)).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byType(ProductFiltersRoyalClean)).dy,
        ),
      );
      await tester.ensureVisible(cleaning);
      await tester.pumpAndSettle();
      await tester.tap(cleaning);
      await tester.pumpAndSettle();
      expect(find.text('Papel toalha interfolhado'), findsNothing);
      final y = tester.getTopLeft(cleaning).dy;
      await tester.tap(find.text('Novidades'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(cleaning).dy, lessThan(y));
      expect(cleaning.hitTestable(), findsOneWidget);
      await tester.tap(find.text('Produtos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pesquisar produtos'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DEMO-SAC-100');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Saco de lixo preto 100 L'), findsOneWidget);
      expect(find.text('Multiuso essencial'), findsNothing);
      await tester.tap(find.byTooltip('Fechar pesquisa'));
      await tester.pumpAndSettle();
      await tester.tap(cleaning);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(cleaning).selected, false);
      expect(tester.takeException(), isNull);
    },
  );
}
