import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'image_action_royal_clean.dart';
import 'neon_image_royal_clean.dart';

/// Decorative placeholder: touch feedback only, until its destination is defined.
class OfficeShortcutRoyalClean extends StatelessWidget {
  final bool isProduction;
  const OfficeShortcutRoyalClean({super.key}) : isProduction = false;
  const OfficeShortcutRoyalClean.production({super.key}) : isProduction = true;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: isProduction ? 'Royal Produção' : 'Royal Office',
    hint: 'Atalho em preparação',
    child: ImageActionRoyalClean(
      key: ValueKey(
        isProduction ? 'royal-producao-shortcut' : 'royal-office-shortcut',
      ),
      pulses: 2,
      duration: const Duration(milliseconds: 600),
      scaleDepth: .018,
      onActivate: () {},
      builder: (_, flash) => Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: _OfficeVapor(
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
  );
}

class _OfficeVapor extends StatefulWidget {
  final double activation;
  final bool isProduction;
  const _OfficeVapor({required this.activation, required this.isProduction});
  @override
  State<_OfficeVapor> createState() => _OfficeVaporState();
}

class _OfficeVaporState extends State<_OfficeVapor>
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
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _VaporPainter(
        _flow,
        widget.activation,
        _animate,
        widget.isProduction,
      ),
    ),
  );
}

class _VaporPainter extends CustomPainter {
  final Animation<double> flow;
  final double activation;
  final bool animated;
  final bool isProduction;
  _VaporPainter(this.flow, this.activation, this.animated, this.isProduction)
    : super(repaint: flow);

  @override
  void paint(Canvas canvas, Size size) {
    if (!animated) return;
    // Follow the silhouette of the office, including its sloping roof and base.
    final corners = isProduction
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
    final paint = Paint();
    final scale = size.width / 191;
    // Fixed particle budget, soft radial gradients; no full-screen blur/filter.
    for (var i = 0; i < 24; i++) {
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
      final radius = (4 + 14 * age) * scale;
      final alpha = math.sin(age * math.pi) * (.23 + .12 * activation);
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

  @override
  bool shouldRepaint(covariant _VaporPainter oldDelegate) =>
      oldDelegate.activation != activation ||
      oldDelegate.animated != animated ||
      oldDelegate.isProduction != isProduction;
}
