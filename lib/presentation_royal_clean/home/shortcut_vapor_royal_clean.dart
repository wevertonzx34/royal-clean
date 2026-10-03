import 'dart:math' as math;
import 'package:flutter/material.dart';

class ShortcutVaporRoyalClean extends StatefulWidget {
  final double activation;
  final bool isProduction;
  final bool isDoor;
  const ShortcutVaporRoyalClean({
    super.key,
    required this.activation,
    this.isProduction = false,
    this.isDoor = false,
  });
  @override
  State<ShortcutVaporRoyalClean> createState() => _ShortcutVaporState();
}

class _ShortcutVaporState extends State<ShortcutVaporRoyalClean>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _flow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  bool _foreground = true;
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _updateMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateMotion();
  }

  void _updateMotion() {
    if (_animate && _foreground) {
      if (!_flow.isAnimating) _flow.repeat();
    } else {
      _flow.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _VaporPainter(
            _flow,
            widget.activation,
            _animate,
            widget.isProduction,
            widget.isDoor,
          ),
        ),
      ),
    ),
  );
}

class _VaporPainter extends CustomPainter {
  final Animation<double> flow;
  final double activation;
  final bool animated;
  final bool isProduction;
  final bool isDoor;
  _VaporPainter(
    this.flow,
    this.activation,
    this.animated,
    this.isProduction,
    this.isDoor,
  ) : super(repaint: flow);

  @override
  void paint(Canvas canvas, Size size) {
    if (!animated) return;
    // Follow the silhouette of the office, including its sloping roof and base.
    final corners = isDoor
        ? [
            Offset(size.width * .05, size.height * .015),
            Offset(size.width * .95, size.height * .015),
            Offset(size.width * .95, size.height * .99),
            Offset(size.width * .05, size.height * .99),
          ]
        : isProduction
        ? [
            Offset(size.width * .015, size.height * .48),
            Offset(size.width * .99, size.height * .025),
            Offset(size.width * .99, size.height * .25),
            Offset(size.width * .015, size.height * .98),
          ]
        : [
            Offset(size.width * .025, size.height * .285),
            Offset(size.width * .975, size.height * .012),
            Offset(size.width * .975, size.height * .975),
            Offset(size.width * .025, size.height * .70),
          ];
    if (!isDoor) {
      _paintSmoke(canvas, size, corners);
      return;
    }
    final paint = Paint();
    final scale = size.width / 191;
    // Fixed particle budget, soft radial gradients; no full-screen blur/filter.
    for (var i = 0; i < (isDoor ? 32 : 24); i++) {
      final edge = i % 4;
      final origin = Offset.lerp(
        corners[edge],
        corners[(edge + 1) % 4],
        ((i * .381966) % .86) + .07,
      )!;
      final age = (flow.value + i * .618034) % 1;
      final tangent = corners[(edge + 1) % 4] - corners[edge];
      final normal = Offset(tangent.dy, -tangent.dx) / tangent.distance;
      final drift = (7 + 29 * age) * scale;
      final center =
          origin +
          normal * drift +
          Offset(math.sin(age * math.pi * 3 + i) * 7, -27 * age) * scale;
      final radius = (4 + 14 * age) * scale * (isDoor ? 1.2 : 1.0);
      final alpha =
          math.sin(age * math.pi) *
          (.23 + .12 * activation) *
          (isDoor ? 1.4 : 1.0);
      paint.shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: alpha),
          const Color(0xFFDDF8FF).withValues(alpha: alpha * .45),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, .4, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _paintSmoke(Canvas canvas, Size size, List<Offset> corners) {
    final scale = size.width / 191;
    // Office: 34 emitters (~40% more), with the extra ten on the roof.
    // staggered lifetimes and curved, fading wisps replace round puffs.
    for (var i = 0; i < (isProduction ? 24 : 34); i++) {
      final edge = !isProduction && i >= 24 ? 0 : i % 4;
      final origin = Offset.lerp(
        corners[edge],
        corners[(edge + 1) % 4],
        ((i * .381966) % .86) + .07,
      )!;
      final age = (flow.value + i * .618034) % 1;
      final tangent = corners[(edge + 1) % 4] - corners[edge];
      final normal = Offset(tangent.dy, -tangent.dx) / tangent.distance;
      final sway = math.sin(age * math.pi * 2 + i * 1.7);
      final base =
          origin +
          normal * (5 + 13 * age) * scale +
          Offset(sway * 5, -34 * age) * scale;
      final length = (23 + (i % 5) * 5 + age * 17) * scale;
      final bend = (sway * 9 + normal.dx * 6) * scale;
      final breadth =
          (2.8 + age * 4.5 + (i % 3) * .8) * scale * (isProduction ? 1 : 1.25);
      final tip = base + Offset(bend * .6, -length);
      final smoke = Path()
        ..moveTo(base.dx - breadth * .3, base.dy)
        ..cubicTo(
          base.dx - breadth + bend,
          base.dy - length * .30,
          tip.dx - breadth * .9,
          tip.dy + length * .3,
          tip.dx - breadth * .35,
          tip.dy,
        )
        ..quadraticBezierTo(
          tip.dx,
          tip.dy - breadth * .35,
          tip.dx + breadth * .35,
          tip.dy,
        )
        ..cubicTo(
          tip.dx + breadth * 1.3,
          tip.dy + length * .24,
          base.dx + breadth + bend,
          base.dy - length * .48,
          base.dx + breadth * .3,
          base.dy,
        )
        ..close();
      final alpha = math.sin(age * math.pi) * (.23 + .12 * activation) * 1.6;
      final shader =
          LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.transparent,
              const Color(0xFFE2EBEF).withValues(alpha: alpha),
              const Color(0xFFBED7E3).withValues(alpha: alpha * .65),
              Colors.transparent,
            ],
            stops: const [0, .25, .60, 1],
          ).createShader(
            Rect.fromLTRB(
              base.dx - length,
              tip.dy - breadth,
              base.dx + length,
              base.dy,
            ),
          );
      canvas.drawPath(
        smoke,
        Paint()
          ..shader = shader
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * scale),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VaporPainter oldDelegate) =>
      oldDelegate.activation != activation ||
      oldDelegate.animated != animated ||
      oldDelegate.isProduction != isProduction ||
      oldDelegate.isDoor != isDoor;
}
