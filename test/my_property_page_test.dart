import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/my_property_page_royal_clean.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(432, 912),
    const Size(800, 400),
  ]) {
    testWidgets('Property artwork and controls adapt to $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MyPropertyPageRoyalClean(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final profile = find.byKey(const ValueKey('royal-perfil-shortcut'));
      final cover = tester.widget<FittedBox>(
        find.byKey(const ValueKey('property-cover')),
      );
      expect(cover.fit, BoxFit.cover);
      final scale = math.max(size.width / 432, size.height / 768);
      final origin = Offset(
        (size.width - 432 * scale) / 2,
        (size.height - 768 * scale) / 2,
      );
      final profileBounds = tester.getRect(profile);
      expect(profileBounds.left, greaterThanOrEqualTo(-.01));
      expect(profileBounds.right, lessThanOrEqualTo(size.width + .01));
      expect(profileBounds.center.dx, closeTo(size.width / 2, .01));
      expect(
        profileBounds.width,
        closeTo(math.min(432 * .615 * 1.4 * scale, size.width), .01),
      );
      expect(
        tester.getTopLeft(profile).dy,
        closeTo(origin.dy + 768 * .07 * scale, .01),
      );
      final background = find.byType(Image).first;
      final bounds = tester.getRect(background);
      expect(bounds.left, lessThanOrEqualTo(.01));
      expect(bounds.top, lessThanOrEqualTo(.01));
      expect(bounds.right, greaterThanOrEqualTo(size.width - .01));
      expect(bounds.bottom, greaterThanOrEqualTo(size.height - .01));
      expect(find.byTooltip('Notificações'), findsOneWidget);
      expect(find.byTooltip('Meus dados'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('property-back'))),
        const Size(48, 48),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('Property back returns to its originating route', (tester) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MediaQuery(
                  data: MediaQueryData(disableAnimations: true),
                  child: MyPropertyPageRoyalClean(),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(MyPropertyPageRoyalClean), findsNothing);
  });
}
