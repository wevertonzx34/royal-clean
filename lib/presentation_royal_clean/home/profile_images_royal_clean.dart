import 'package:flutter/material.dart';
import 'avatar_aura_royal_clean.dart';
import 'royal_blu_page.dart';

/// Decode at the same sizes used by the widgets, before navigation.
Future<void> precacheProfileImagesRoyalClean(BuildContext context) async {
  await AvatarAuraRoyalClean.prepare();
  if (!context.mounted) return;
  await prepareRoyalBlu(context);
  for (final asset in const [
    'royal-home',
    'royal-porta',
    'logo-porta',
    'royal-avatar',
    'royal-dados',
    'royal-blu',
    'royal-stoque',
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
