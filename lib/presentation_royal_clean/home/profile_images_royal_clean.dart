import 'package:flutter/material.dart';

/// Decode at the same sizes used by the widgets, before navigation.
Future<void> precacheProfileImagesRoyalClean(BuildContext context) async {
  for (final asset in const [
    'royal-home',
    'royal-porta',
    'logo-porta',
    'royal-avatar',
    'royal-dados',
    'royal-blu',
  ]) {
    if (!context.mounted) return;
    await precacheImage(
      ResizeImage(
        AssetImage('assets/preview/royal-store/$asset.webp'),
        width: ['royal-dados', 'royal-blu', 'logo-porta'].contains(asset)
            ? 300
            : 900,
      ),
      context,
    );
  }
}

/// Decode destination artwork only when it is actually requested.
Future<void> precacheStockImagesRoyalClean(BuildContext context) async {
  for (final asset in const [
    'royal-stoque',
    'royal-3d',
    'royal-pixels',
    'royal-perfil',
    'royal-office',
    'royal-producao',
  ]) {
    if (!context.mounted) return;
    await precacheImage(
      ResizeImage(
        AssetImage('assets/preview/royal-store/$asset.webp'),
        width:
            asset == 'royal-stoque' ||
                asset == 'royal-pixels' ||
                asset == 'royal-perfil'
            ? 1080
            : asset == 'royal-dados' ||
                  asset == 'royal-blu' ||
                  asset == 'logo-porta'
            ? 300
            : asset == 'royal-office' || asset == 'royal-producao'
            ? 600
            : 900,
      ),
      context,
    );
  }
}
