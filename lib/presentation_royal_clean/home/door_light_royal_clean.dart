import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Decorative light; the underlying door retains the entire touch target.
class DoorLightRoyalClean extends StatefulWidget {
  final double activation;
  const DoorLightRoyalClean({super.key, this.activation = 0});

  @override
  State<DoorLightRoyalClean> createState() => _DoorLightState();
}

class _DoorLightState extends State<DoorLightRoyalClean>
    with SingleTickerProviderStateMixin {
  static const _width = .63 * .95;
  static const _height = .015 * 1.70;
  // Keep the previous right and bottom edges fixed, relative to the door.
  static const _right = .815;
  static const _bottom = .06 * .99 - .10 + .015;
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _pulse.stop();
      _pulse.value = .5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _bar() => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_pulse.value);
        final baseColor = Color.lerp(
          const Color(0xFF89CFF0),
          const Color(0xFFF8F6F0),
          t,
        )!;
        final color = Color.lerp(
          baseColor,
          const Color(0xFFF4B6CE),
          widget.activation,
        )!;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .55 + .35 * t),
                blurRadius: 8 + 8 * t,
                spreadRadius: 1 + 2 * t,
              ),
              BoxShadow(color: color, blurRadius: 3),
            ],
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final length = constraints.maxWidth * _width;
          final thickness = constraints.maxHeight * _height;
          final originalTop = constraints.maxHeight * (_bottom - _height);
          final verticalLength = length * .75;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: constraints.maxWidth * (_right - _width),
                top: originalTop,
                width: length,
                height: thickness,
                child: _bar(),
              ),
              Positioned(
                left: constraints.maxWidth * .91 - verticalLength / 2,
                // Cumulative offset; preserve the shortened bar's length.
                top: originalTop + constraints.maxHeight * .52 - length * .125,
                width: verticalLength,
                height: thickness,
                child: Transform.rotate(angle: math.pi / 2, child: _bar()),
              ),
            ],
          );
        },
      ),
    ),
  );
}
