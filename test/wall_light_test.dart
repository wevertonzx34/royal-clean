import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/wall_light_royal_clean.dart';

void main() {
  testWidgets(
    'Opening flashes four times; closing twice; input passes through',
    (tester) async {
      final open = ValueNotifier(false);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox.expand(),
                ),
                WallLightRoyalClean(openState: open),
              ],
            ),
          ),
        ),
      );
      final paint = find.descendant(
        of: find.byType(WallLightRoyalClean),
        matching: find.byType(CustomPaint),
      );
      double flash() =>
          (tester.widget<CustomPaint>(paint).painter as dynamic).flash
              as double;
      await tester.tapAt(const Offset(200, 200));
      expect(taps, 1);
      for (final value in [true, false]) {
        open.value = value;
        await tester.pump();
        final halfPeriod = Duration(milliseconds: value ? 180 : 325);
        for (var i = 0; i < (value ? 4 : 2); i++) {
          await tester.pump(halfPeriod);
          expect(flash(), closeTo(1, .001));
          await tester.pump(halfPeriod);
          expect(flash(), closeTo(0, .001));
        }
        await tester.pump(const Duration(milliseconds: 1));
      }
      await tester.pumpWidget(const SizedBox.shrink());
      open.dispose();
      await tester.pump(const Duration(seconds: 30));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Faults have long pauses and reduced motion stops flickering', (
    tester,
  ) async {
    final open = ValueNotifier(false);
    Widget host(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(body: WallLightRoyalClean(openState: open)),
      ),
    );
    await tester.pumpWidget(host(false));
    final opacity = find.descendant(
      of: find.byType(WallLightRoyalClean),
      matching: find.byType(Opacity),
    );
    await tester.pump(const Duration(seconds: 15));
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<Opacity>(opacity).opacity, lessThan(1));
    await tester.pumpWidget(host(true));
    open.value = true;
    await tester.pump(const Duration(seconds: 30));
    expect(tester.widget<Opacity>(opacity).opacity, 1);
    final paint = find.descendant(
      of: find.byType(WallLightRoyalClean),
      matching: find.byType(CustomPaint),
    );
    expect((tester.widget<CustomPaint>(paint).painter as dynamic).flash, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    open.dispose();
    expect(tester.takeException(), isNull);
  });
}
