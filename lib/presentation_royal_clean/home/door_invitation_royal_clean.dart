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
                  offset: Offset(
                    -constraints.maxWidth * .015,
                    -constraints.maxHeight * .12,
                  ),
                  child: Transform.scale(
                    scale: .75 * (1 + .035 * beat),
                    child: SizedBox(
                      width: constraints.maxWidth * .8,
                      child: Text(
                        'Entre\nAqui',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontFamily: 'RoyalSignature',
                          fontSize: (constraints.maxWidth * .27).clamp(22, 52),
                          fontWeight: FontWeight.w400,
                          height: .95,
                          letterSpacing: 0,
                          color: Color.lerp(color, Colors.white, .25),
                          shadows: [
                            const Shadow(
                              color: Color(0xFF071825),
                              blurRadius: 3,
                              offset: Offset(0, 2),
                            ),
                            Shadow(
                              color: color.withValues(alpha: .85),
                              blurRadius: 4 + beat * 2,
                            ),
                            Shadow(
                              color: color.withValues(alpha: .45),
                              blurRadius: 10 + beat * 4,
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
