import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Decorative wall light; its invisible source is at the top centre.
class WallLightRoyalClean extends StatefulWidget {
  final ValueListenable<bool> openState;
  const WallLightRoyalClean({super.key, required this.openState});

  static const width = 300.0;
  static const height = 520.0;

  @override
  State<WallLightRoyalClean> createState() => _WallLightState();
}

class _WallLightState extends State<WallLightRoyalClean>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this);
  Timer? _pause;
  bool _enabled = false;
  bool _interaction = false;
  int _pulses = 4;
  int _cycle = 0;

  @override
  void initState() {
    super.initState();
    widget.openState.addListener(_onToggle);
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) _scheduleFault();
    });
  }

  @override
  void didUpdateWidget(covariant WallLightRoyalClean oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openState != widget.openState) {
      oldWidget.openState.removeListener(_onToggle);
      widget.openState.addListener(_onToggle);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _pause?.cancel();
    if (!_enabled) {
      _animation.stop();
      _animation.value = 1;
    } else if (!_animation.isAnimating) {
      _scheduleFault();
    }
  }

  void _scheduleFault() {
    _pause?.cancel();
    if (!_enabled) return;
    _pause = Timer(Duration(seconds: _cycle++ % 2 == 0 ? 16 : 23), () {
      if (!mounted || !_enabled) return;
      _interaction = false;
      _animation.duration = const Duration(milliseconds: 720);
      _animation.forward(from: 0);
    });
  }

  void _onToggle() {
    if (!_enabled) return;
    _pause?.cancel();
    _interaction = true;
    _pulses = widget.openState.value ? 4 : 2;
    _animation.duration = Duration(milliseconds: _pulses == 4 ? 1440 : 1300);
    _animation.forward(from: 0);
  }

  @override
  void dispose() {
    widget.openState.removeListener(_onToggle);
    _pause?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = math.min(
            1.0,
            math.min(
              constraints.maxWidth / WallLightRoyalClean.width,
              constraints.maxHeight * .8 / WallLightRoyalClean.height,
            ),
          );
          final width = WallLightRoyalClean.width * scale;
          final height = WallLightRoyalClean.height * scale;
          return Stack(
            children: [
              Positioned(
                left:
                    (constraints.maxWidth - width) / 2 -
                    constraints.maxWidth * .15,
                top: constraints.maxHeight * .10,
                width: width,
                height: height,
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, _) {
                      final running = _enabled && _animation.isAnimating;
                      final wave = math.sin(
                        _animation.value * math.pi * _pulses,
                      );
                      final flash = running && _interaction ? wave * wave : 0.0;
                      final t = _animation.value;
                      final fault =
                          running &&
                          !_interaction &&
                          ((t > .08 && t < .20) ||
                              (t > .30 && t < .36) ||
                              (t > .52 && t < .67));
                      return Opacity(
                        opacity: fault ? .28 : 1,
                        child: CustomPaint(
                          painter: _WallLightPainter(flash: flash),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _WallLightPainter extends CustomPainter {
  final double flash;
  const _WallLightPainter({this.flash = 0});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(
      size.width / WallLightRoyalClean.width,
      size.height / WallLightRoyalClean.height,
    );
    const bounds = Rect.fromLTWH(0, 0, 300, 520);
    final tint = Color.lerp(
      const Color(0xFF008FFF),
      const Color(0xFF45DEFF),
      flash,
    )!;
    // A diffuse wall reflection blends the beam into the underlying texture.
    canvas.drawOval(
      const Rect.fromLTWH(35, 15, 230, 450),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -.7),
          radius: .85,
          colors: [
            tint.withValues(alpha: .24 + flash * .22),
            tint.withValues(alpha: 0),
          ],
        ).createShader(bounds)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    // Layered soft cones spread downward, fading before the lower edge.
    for (final spread in [1.0, .72, .42]) {
      final halfWidth = 140 * spread;
      final cone = Path()
        ..moveTo(150, 0)
        ..cubicTo(
          150 - 12 * spread,
          100,
          150 - halfWidth,
          360,
          150 - halfWidth,
          490,
        )
        ..quadraticBezierTo(150, 520, 150 + halfWidth, 490)
        ..cubicTo(150 + halfWidth, 360, 150 + 12 * spread, 100, 150, 0)
        ..close();
      canvas.drawPath(
        cone,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(
                const Color(0xFF88E3FF),
                const Color(0xFFB5F4FF),
                flash,
              )!.withValues(alpha: .55 + flash * .30),
              tint.withValues(alpha: .36 + flash * .30),
              tint.withValues(alpha: .13 + flash * .16),
              tint.withValues(alpha: 0),
            ],
            stops: const [0, .18, .60, 1],
          ).createShader(bounds)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 19),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WallLightPainter oldDelegate) =>
      oldDelegate.flash != flash;
}
