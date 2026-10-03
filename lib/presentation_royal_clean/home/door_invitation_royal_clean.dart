import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../shared/layout_button_royal_clean.dart';
import 'image_action_royal_clean.dart';

/// Independently adjustable overlay; a normal tap keeps the door action.
class DoorInvitationRoyalClean extends StatefulWidget {
  final Future<void> Function()? onActivate;
  const DoorInvitationRoyalClean({super.key, this.onActivate});

  @override
  State<DoorInvitationRoyalClean> createState() => _DoorInvitationState();
}

class _DoorInvitationState extends State<DoorInvitationRoyalClean>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _animation.stop();
      _animation.value = 0;
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: LayoutBuilder(
      builder: (context, constraints) => Center(
        child: Transform.translate(
          offset: Offset(
            constraints.maxWidth * .005,
            -constraints.maxHeight * .18,
          ),
          child: Transform.scale(
            scale: .466875,
            child: SizedBox(
              width: constraints.maxWidth * .8,
              child: LayoutButtonRoyalClean(
                id: 'home.door-logo',
                freeMovement: true,
                child: Semantics(
                  button: true,
                  label: 'Logo da porta: abrir funções de estoque',
                  child: ImageActionRoyalClean(
                    onActivate: widget.onActivate ?? () async {},
                    pulses: 3,
                    replayAfterActivation: true,
                    duration: const Duration(milliseconds: 900),
                    scaleDepth: .018,
                    builder: (_, flash) => AnimatedBuilder(
                      animation: _animation,
                      builder: (context, _) {
                        final phase = (_animation.value * 2) % 1;
                        final beat = phase < .18
                            ? math.sin(phase / .18 * math.pi)
                            : phase >= .24 && phase < .42
                            ? .7 * math.sin((phase - .24) / .18 * math.pi)
                            : 0.0;
                        return Transform.scale(
                          scale: 1 + .035 * beat,
                          child: Image.asset(
                            'assets/preview/royal-store/logo-porta.webp',
                            key: const ValueKey('door-logo-image'),
                            fit: BoxFit.contain,
                            cacheWidth: 300,
                            filterQuality: FilterQuality.medium,
                            gaplessPlayback: true,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
