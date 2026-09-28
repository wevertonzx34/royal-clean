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
                final color = Color.lerp(
                  const Color(0xFFA8E5FF),
                  const Color(0xFFFFBDD9),
                  (1 - math.cos(_animation.value * 2 * math.pi)) / 2,
                )!;
                return Transform.translate(
                  offset: Offset(0, -constraints.maxHeight * .12),
                  child: Transform.scale(
                    scale: .75 * (1 + .07 * beat),
                    child: SizedBox(
                      width: constraints.maxWidth * .8,
                      child: Text(
                        'Entre\nAqui',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: (constraints.maxWidth * .20).clamp(18, 38),
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          letterSpacing: 1,
                          color: color,
                          shadows: [
                            const Shadow(
                              color: Color(0xFF071825),
                              blurRadius: 3,
                              offset: Offset(0, 2),
                            ),
                            Shadow(
                              color: color.withValues(alpha: .85),
                              blurRadius: 7 + beat * 5,
                            ),
                            Shadow(
                              color: color.withValues(alpha: .55),
                              blurRadius: 15 + beat * 8,
                            ),
                          ],
                        ),
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
