import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/avatar_aura_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/neon_image_royal_clean.dart';

void main() {
  testWidgets(
    'Aura follows asset, preserves touch bounds and pauses for reduced motion',
    (tester) async {
      await tester.runAsync(AvatarAuraRoyalClean.prepare);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(500, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var taps = 0;
      final capture = GlobalKey(), target = GlobalKey();
      Widget scene(bool reduced) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(500, 900),
            disableAnimations: reduced,
          ),
          child: RepaintBoundary(
            key: capture,
            child: Scaffold(
              backgroundColor: const Color(0xFF05132A),
              body: Center(
                child: SizedBox(
                  width: 282,
                  child: GestureDetector(
                    key: target,
                    onTap: () => taps++,
                    child: const AvatarAuraRoyalClean(
                      child: NeonImageRoyalClean(
                        asset: 'assets/preview/royal-store/royal-avatar.webp',
                        aspectRatio: 282 / 603,
                        glow: Color(0xFF9955FF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(scene(false));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1700));
      final bounds = tester.getRect(find.byKey(target));
      expect(bounds.width, 282);
      expect(bounds.height, closeTo(603, .01));
      await tester.tapAt(bounds.center);
      expect(taps, 1);
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'build/avatar-aura-preview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(scene(true));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.getRect(find.byKey(target)), bounds);
      expect(tester.takeException(), isNull);
    },
  );
}
