import 'package:flutter/material.dart';

/// Decode at the same sizes used by the widgets, before navigation.
Future<void> precacheProfileImagesRoyalClean(BuildContext context) async {
  for (final asset in const [
    'royal-home',
    'royal-porta',
    'royal-avatar',
    'royal-dados',
    'royal-stoque',
    'royal-pixels',
  ]) {
    if (!context.mounted) return;
    await precacheImage(
      ResizeImage(
        AssetImage('assets/preview/royal-store/$asset.webp'),
        width: asset == 'royal-stoque' || asset == 'royal-pixels'
            ? 1080
            : asset == 'royal-dados'
            ? 300
            : 900,
      ),
      context,
    );
  }
}
