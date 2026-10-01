import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Decorative invitation: the door remains the single accessible touch target.
class DoorInvitationRoyalClean extends StatefulWidget {
  const DoorInvitationRoyalClean({super.key});

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
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final phase = (_animation.value * 2) % 1;
                // Two short beats followed by a resting interval.
                final beat = phase < .18
                    ? math.sin(phase / .18 * math.pi)
                    : phase >= .24 && phase < .42
                    ? .7 * math.sin((phase - .24) / .18 * math.pi)
                    : 0.0;
                return Transform.translate(
                  offset: Offset(
                    constraints.maxWidth * .005,
                    -constraints.maxHeight * .18,
                  ),
                  child: Transform.scale(
                    scale: .466875 * (1 + .035 * beat),
                    child: SizedBox(
                      width: constraints.maxWidth * .8,
                      child: Image.asset(
                        'assets/preview/royal-store/logo-porta.webp',
                        fit: BoxFit.contain,
                        cacheWidth: 300,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
