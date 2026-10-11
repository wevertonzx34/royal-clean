import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/royal_tag_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/avatar_aura_royal_clean.dart';

void main() {
  testWidgets(
    'Tag hops once a second, boosts on avatar signal and respects reduced motion',
    (tester) async {
      final taps = ValueNotifier<int>(0);
      addTearDown(taps.dispose);
      Widget scene(bool reduced) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 60,
                child: RoyalTagRoyalClean(avatarTap: taps),
              ),
            ),
          ),
        ),
      );
      double offset() => tester
          .widget<Transform>(find.byKey(const ValueKey('royal-tag-jump')))
          .transform
          .storage[13];
      await tester.pumpWidget(scene(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(offset(), closeTo(-4, .01));
      await tester.pump(const Duration(milliseconds: 500));
      expect(offset(), closeTo(0, .01));
      taps.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 225));
      expect(offset(), closeTo(-12, .01));
      final aura = tester.widget<AvatarAuraRoyalClean>(
        find.byType(AvatarAuraRoyalClean),
      );
      expect(aura.particles, isTrue);
      expect(aura.particleColor, const Color(0xFFC08AFF));
      await tester.pumpWidget(scene(true));
      taps.value++;
      await tester.pump(const Duration(seconds: 2));
      expect(offset(), 0);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
