import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Decorative light painted in the same coordinate space as the warehouse.
class StockLightingRoyalClean extends StatefulWidget {
  final ValueListenable<int> trigger;
  const StockLightingRoyalClean({super.key, required this.trigger});

  @override
  State<StockLightingRoyalClean> createState() => _StockLightingState();
}

class _StockLightingState extends State<StockLightingRoyalClean>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  late final _touch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final _repaint = Listenable.merge([_ambient, _touch]);
  bool _foreground = true;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.trigger.addListener(_flash);
  }

  @override
  void didUpdateWidget(covariant StockLightingRoyalClean oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      oldWidget.trigger.removeListener(_flash);
      widget.trigger.addListener(_flash);
    }
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
      if (!_ambient.isAnimating) _ambient.repeat();
    } else {
      _ambient.stop();
      _touch.stop();
      _touch.value = 0;
    }
  }

  void _flash() {
    if (_enabled && _foreground && !_touch.isAnimating) {
      _touch.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_flash);
    WidgetsBinding.instance.removeObserver(this);
    _ambient.dispose();
    _touch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _WarehouseLightPainter(_ambient, _touch, _repaint),
        ),
      ),
    ),
  );
}

class _WarehouseLightPainter extends CustomPainter {
  final Animation<double> ambient;
  final Animation<double> touch;
  _WarehouseLightPainter(this.ambient, this.touch, Listenable repaint)
    : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    // Window centers and beam ends, measured against royal-stoque.
    const windows = [
      (Offset(.069, .159), Offset(.24, .50), .13),
      (Offset(.173, .251), Offset(.32, .54), .095),
      (Offset(.263, .298), Offset(.39, .53), .075),
      (Offset(.930, .163), Offset(.74, .50), .13),
      (Offset(.831, .244), Offset(.68, .54), .095),
      (Offset(.761, .294), Offset(.64, .53), .075),
      (Offset(.503, .372), Offset(.425, .59), .12),
      (Offset(.637, .372), Offset(.57, .59), .12),
    ];
    final phase = ambient.value * math.pi * 2;
    final touchWave = math.pow(math.sin(touch.value * math.pi), 2).toDouble();
    // One gentle dip per 24-second cycle, with a long quiet interval.
    final dip = ambient.value > .94
        ? math.pow(math.sin((ambient.value - .94) / .06 * math.pi), 2) * .18
        : 0.0;
    final paint = Paint();
    Offset point(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    for (var i = 0; i < windows.length; i++) {
      final (origin, end, spread) = windows[i];
      final start = point(origin);
      final drift = math.sin(phase + i * .6) * .008;
      final finish = point(Offset(end.dx + drift, end.dy));
      final intensity =
          (.09 + .022 * math.sin(phase + i * .5) + .055 * touchWave) * 1.6;
      final beam = Path()
        ..moveTo(start.dx - size.width * .014, start.dy)
        ..lineTo(start.dx + size.width * .014, start.dy)
        ..lineTo(finish.dx + size.width * spread, finish.dy)
        ..quadraticBezierTo(
          finish.dx,
          finish.dy + size.height * .035,
          finish.dx - size.width * spread,
          finish.dy,
        )
        ..close();
      canvas.save();
      canvas.clipPath(beam);
      paint.shader =
          RadialGradient(
            colors: [
              const Color(0xFFE6F7FF).withValues(alpha: intensity * (1 - dip)),
              const Color(0xFFACDFFF).withValues(alpha: intensity * .48),
              Colors.transparent,
            ],
            stops: const [0, .45, 1],
          ).createShader(
            Rect.fromCircle(center: start, radius: (finish - start).distance),
          );
      canvas.drawPath(beam, paint);
      canvas.restore();
      // Soft reflections move slowly below the rear windows, on the floor.
      if (i >= 6) {
        final rect = Rect.fromCenter(
          center: point(
            Offset(end.dx + drift * 2, .72 + .012 * math.sin(phase + i)),
          ),
          width: size.width * .14,
          height: size.height * .28,
        );
        paint.shader = RadialGradient(
          colors: [
            const Color(
              0xFFD9F3FF,
            ).withValues(alpha: (.05 + touchWave * .04) * 1.6),
            Colors.transparent,
          ],
        ).createShader(rect);
        canvas.drawOval(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WarehouseLightPainter oldDelegate) =>
      oldDelegate.ambient != ambient || oldDelegate.touch != touch;
}
