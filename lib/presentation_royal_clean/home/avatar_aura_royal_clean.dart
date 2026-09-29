import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Decorative aurora behind the avatar; never participates in hit testing.
class AvatarAuraRoyalClean extends StatefulWidget {
  final double activation;
  const AvatarAuraRoyalClean({super.key, this.activation = 0});

  @override
  State<AvatarAuraRoyalClean> createState() => _AvatarAuraState();
}

class _AvatarAuraState extends State<AvatarAuraRoyalClean>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _flow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );
  bool _foreground = true;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled =
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
    if (_enabled && _foreground) {
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
        child: CustomPaint(painter: _AuraPainter(_flow, widget.activation)),
      ),
    ),
  );
}

class _AuraPainter extends CustomPainter {
  final Animation<double> flow;
  final double activation;
  _AuraPainter(this.flow, this.activation) : super(repaint: flow);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    // A small fixed set of translucent ribbons; no full-screen blur or layers.
    for (var i = 0; i < 10; i++) {
      final age = (flow.value + i * .173) % 1;
      final envelope = math.sin(age * math.pi);
      final side = i.isEven ? -1.0 : 1.0;
      final y = (1.08 - age * 1.18) * size.height;
      final x = (.5 + side * (.34 + .06 * math.sin(age * 5 + i))) * size.width;
      final length = size.height * (.20 + (i % 3) * .035);
      final width = size.width * (.11 + .025 * math.sin(age * math.pi));
      final sway = math.sin(age * math.pi * 2 + i) * size.width * .10;
      final tip = Offset(x + sway, y - length);
      final ribbon = Path()
        ..moveTo(x - width, y)
        ..cubicTo(
          x - width * 1.1,
          y - length * .42,
          tip.dx - width * .22,
          tip.dy + length * .2,
          tip.dx,
          tip.dy,
        )
        ..cubicTo(
          tip.dx + width * .03,
          tip.dy + length * .35,
          x + width,
          y - length * .35,
          x + width,
          y,
        )
        ..quadraticBezierTo(x, y + length * .12, x - width, y);
      final alpha = envelope * (.30 + activation * .09);
      paint.shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFF7139D6).withValues(alpha: 0),
          const Color(0xFFA05BFF).withValues(alpha: alpha),
          const Color(0xFFF3BBDC).withValues(alpha: alpha * .65),
          const Color(0xFFFFF3FF).withValues(alpha: 0),
        ],
        stops: const [0, .38, .78, 1],
      ).createShader(Rect.fromLTWH(x - width, tip.dy, width * 2, length));
      canvas.drawPath(ribbon, paint);
      // Fine luminous strand follows each ribbon, tapering toward its tip.
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = size.width * .0035;
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..cubicTo(
            x + sway,
            y - length * .4,
            tip.dx - width * .1,
            tip.dy + length * .25,
            tip.dx,
            tip.dy,
          ),
        paint,
      );
      paint.style = PaintingStyle.fill;
    }
    for (var i = 0; i < 14; i++) {
      final age = (flow.value + i * .381966) % 1;
      final side = i.isEven ? -1.0 : 1.0;
      final center = Offset(
        size.width * (.5 + side * .43 + .045 * math.sin(age * 6 + i)),
        size.height * (1 - age * 1.06),
      );
      final alpha = math.pow(math.sin(age * math.pi), 2).toDouble() * .6;
      final radius = size.width * (i % 3 == 0 ? .012 : .006);
      paint.shader = RadialGradient(
        colors: [
          (i.isEven ? Colors.white : const Color(0xFFFFC7E4)).withValues(
            alpha: alpha,
          ),
          const Color(0xFFA675FF).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuraPainter oldDelegate) =>
      oldDelegate.activation != activation || oldDelegate.flow != flow;
}
