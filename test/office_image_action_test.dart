import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/office_image_action_royal_clean.dart';

void main() {
  for (final name in ['royal-papper', 'royal-pedidos', 'royal-receita']) {
    testWidgets('$name reveals three times, then opens once and hides', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 250,
                height: 120,
                child: OfficeImageActionRoyalClean(
                  asset: 'assets/preview/royal-store/$name.webp',
                  onActivate: () async => opened++,
                ),
              ),
            ),
          ),
        ),
      );
      final action = find.byType(OfficeImageActionRoyalClean);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      final image = find.descendant(of: action, matching: find.byType(Image));
      expect(
        tester.getRect(image),
        tester.getRect(action),
        reason: 'Image and contour must share the same centered fitting box',
      );
      final imageVisibility = find.descendant(
        of: action,
        matching: find.byType(Opacity),
      );
      double opacity() => tester.widget<Opacity>(imageVisibility).opacity;
      expect(opacity(), 0);
      await tester.tap(action);
      await tester.pump();
      for (var pulse = 0; pulse < 3; pulse++) {
        await tester.pump(const Duration(microseconds: 166667));
        expect(opacity(), 1, reason: 'Full image in pulse ${pulse + 1}');
        expect(opened, 0);
        await tester.tap(
          action,
        ); // Ignore duplicate taps while the sequence runs.
        await tester.pump(const Duration(microseconds: 166667));
        expect(
          opacity(),
          0,
          reason: 'Only the contour after pulse ${pulse + 1}',
        );
      }
      expect(opened, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(opacity(), 0);
      expect(opened, 1);
      // Leaving during another flash must not navigate after disposal.
      await tester.tap(action);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
