import 'package:flutter/material.dart';
import 'avatar_aura_royal_clean.dart';
import 'image_action_royal_clean.dart';

/// Keep the alpha-derived contour visible while revealing the original image
/// three times before opening its existing destination.
class OfficeImageActionRoyalClean extends StatelessWidget {
  final String asset;
  final int cacheWidth;
  final Future<void> Function() onActivate;
  final VoidCallback? onAdminEdit;
  const OfficeImageActionRoyalClean({
    super.key,
    required this.asset,
    required this.onActivate,
    this.cacheWidth = 900,
    this.onAdminEdit,
  });

  @override
  Widget build(BuildContext context) => ImageActionRoyalClean(
    pulses: 3,
    duration: const Duration(seconds: 1),
    scaleDepth: 0,
    onActivate: onActivate,
    onAdminEdit: onAdminEdit,
    builder: (_, flash) => AvatarAuraRoyalClean(
      asset: asset,
      contourColor: const Color(0xFFB875FF),
      particles: false,
      activation: flash,
      // The contour fits the full button bounds. Give the original image the
      // same bounds; a loose Stack child otherwise fits at the upper-left.
      child: SizedBox.expand(
        child: Opacity(
          opacity: flash >= .5 ? 1 : 0,
          child: RepaintBoundary(
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              cacheWidth: cacheWidth,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    ),
  );
}
