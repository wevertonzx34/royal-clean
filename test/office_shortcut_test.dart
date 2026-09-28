import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/office_shortcut_royal_clean.dart';

void main() {
  for (final reducedMotion in [false, true]) {
    testWidgets('Office touch stays on page; reduced motion=$reducedMotion', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 191,
                  height: 415,
                  child: OfficeShortcutRoyalClean(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final button = find.byKey(const ValueKey('royal-office-shortcut'));
      expect(tester.getSize(button), const Size(191, 415));
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(button, findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
