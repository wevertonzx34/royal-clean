import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/stock_functions_page_royal_clean.dart';

void main() {
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
