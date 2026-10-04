import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/cached_glow_royal_clean.dart';

void main() {
  testWidgets(
    'Cached halo keeps transparent corners and reuses the same texture',
    (tester) async {
      await tester.runAsync(() async {
        const asset = 'assets/preview/royal-store/royal-avatar.webp';
        final glow = await CachedGlowRoyalClean.load(asset, Colors.purple);
        expect(glow, isNotNull);
        expect(
          identical(
            glow,
            await CachedGlowRoyalClean.load(asset, Colors.purple),
          ),
          isTrue,
        );
        final bytes = (await glow!.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (final offset in [
          0,
          (glow.image.width - 1) * 4,
          (glow.image.width * (glow.image.height - 1)) * 4,
          (glow.image.width * glow.image.height - 1) * 4,
        ]) {
          expect(bytes.getUint8(offset + 3), 0);
        }
      });
    },
  );
}
