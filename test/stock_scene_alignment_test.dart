import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/stock_functions_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/stock_lighting_royal_clean.dart';

void main() {
  testWidgets('Office follows backdrop scaling and cropping across screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final viewport in [
      const Size(432, 912),
      const Size(360, 800),
      const Size(800, 600),
    ]) {
      tester.view.physicalSize = viewport;
      await tester.pumpWidget(
        const MaterialApp(home: StockBackgroundRoyalClean(showOffice: true)),
      );
      await tester.pump(const Duration(seconds: 1));
      final scale = math.max(viewport.width / 2250, viewport.height / 4000);
      final offset = Offset(
        (viewport.width - 2250 * scale) / 2,
        (viewport.height - 4000 * scale) / 2,
      );
      for (final entry in const {
        'royal-office-shortcut': StockBackgroundRoyalClean.officeRect,
        'royal-producao-shortcut': StockBackgroundRoyalClean.productionRect,
      }.entries) {
        final button = find.byKey(ValueKey(entry.key));
        final anchor = entry.value;
        final expected = Rect.fromLTWH(
          offset.dx + anchor.left * scale,
          offset.dy + anchor.top * scale,
          anchor.width * scale,
          anchor.height * scale,
        );
        final actual = tester.getRect(button);
        expect(actual.left, closeTo(expected.left, .01));
        expect(actual.top, closeTo(expected.top, .01));
        expect(actual.width, closeTo(expected.width, .01));
        expect(actual.height, closeTo(expected.height, .01));
        // A cropped shortcut must still respond inside its visible portion.
        final visible = expected.intersect(Offset.zero & viewport);
        expect(visible.isEmpty, isFalse);
        final lighting = tester.widget<StockLightingRoyalClean>(
          find.byType(StockLightingRoyalClean),
        );
        final previousFlash = lighting.trigger.value;
        await tester.tapAt(visible.center);
        expect(lighting.trigger.value, previousFlash + 1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        expect(button, findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
