import 'package:royal_clean/presentation_royal_clean/shared/layout_button_royal_clean.dart';
import 'shortcut_vapor_royal_clean.dart';
import 'package:flutter/material.dart';
import 'image_action_royal_clean.dart';
import 'neon_image_royal_clean.dart';
import '../../core_royal_clean/services/touch_feedback_royal_clean.dart';

/// Decorative placeholder: touch feedback only, until its destination is defined.
class OfficeShortcutRoyalClean extends StatelessWidget {
  final bool isProduction;
  final VoidCallback? onTouch;
  final Future<void> Function()? onOpen;
  const OfficeShortcutRoyalClean({super.key, this.onTouch, this.onOpen})
    : isProduction = false;
  const OfficeShortcutRoyalClean.production({
    super.key,
    this.onTouch,
    this.onOpen,
  }) : isProduction = true;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: isProduction ? 'Royal Produção' : 'Royal Office',
    hint: onOpen == null
        ? 'Atalho em preparação'
        : isProduction
        ? 'Conferir produtos da OS / NF-e'
        : 'Abrir NF-e',
    child: LayoutButtonRoyalClean(
      id: isProduction ? 'stock.production' : 'stock.office',
      child: ImageActionRoyalClean(
        key: ValueKey(
          isProduction ? 'royal-producao-shortcut' : 'royal-office-shortcut',
        ),
        pulses: 2,
        duration: const Duration(milliseconds: 600),
        scaleDepth: .018,
        feedback: () {
          TouchFeedbackRoyalClean.pulse();
          onTouch?.call();
        },
        onActivate: () async {
          await onOpen?.call();
        },
        builder: (_, flash) => Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: ShortcutVaporRoyalClean(
                    activation: flash,
                    isProduction: isProduction,
                  ),
                ),
              ),
            ),
            NeonImageRoyalClean(
              asset:
                  'assets/preview/royal-store/${isProduction ? 'royal-producao' : 'royal-office'}.webp',
              aspectRatio: isProduction ? 650 / 496 : 191 / 415,
              cacheWidth: 600,
              glow: const Color(0xFF69DCFF),
              activationGlow: const Color(0xFF008CFF),
              activation: flash,
            ),
          ],
        ),
      ),
    ),
  );
}
