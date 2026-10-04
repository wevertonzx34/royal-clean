import 'dart:async';
import 'package:flutter/material.dart';
import 'cached_glow_royal_clean.dart';

class NeonImageRoyalClean extends StatefulWidget {
  final String asset;
  final double aspectRatio;
  final Color glow;
  final BoxFit fit;
  final double activation;
  final Color activationGlow;
  final Color? activationSecondaryGlow;
  final int cacheWidth;
  const NeonImageRoyalClean({
    super.key,
    required this.asset,
    required this.aspectRatio,
    required this.glow,
    this.fit = BoxFit.contain,
    this.activation = 0,
    this.activationGlow = const Color(0xFF008CFF),
    this.activationSecondaryGlow,
    this.cacheWidth = 900,
  });
  static Future<void> prepare(String asset, Color glow) async {
    await CachedGlowRoyalClean.load(asset, glow);
  }

  @override
  State<NeonImageRoyalClean> createState() => _NeonImageState();
}

class _NeonImageState extends State<NeonImageRoyalClean>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  CachedGlowRoyalClean? _glow, _activation;
  bool _foreground = true, _enabled = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void _load() {
    final generation = ++_generation;
    _glow = _activation = null;
    unawaited(
      Future.wait([
        CachedGlowRoyalClean.load(widget.asset, widget.glow),
        CachedGlowRoyalClean.load(
          widget.asset,
          widget.activationGlow,
          widget.activationSecondaryGlow,
        ),
      ]).then((textures) {
        if (mounted && generation == _generation) {
          setState(() {
            _glow = textures[0];
            _activation = textures[1];
          });
        }
      }),
    );
  }

  @override
  void didUpdateWidget(covariant NeonImageRoyalClean oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset ||
        oldWidget.glow != widget.glow ||
        oldWidget.activationGlow != widget.activationGlow ||
        oldWidget.activationSecondaryGlow != widget.activationSecondaryGlow) {
      _load();
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
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      if (!_enabled) _pulse.value = .4;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _GlowPainter(
                  _pulse,
                  _glow,
                  _activation,
                  widget.activation,
                  widget.fit,
                ),
              ),
            ),
          ),
          RepaintBoundary(
            child: Image.asset(
              widget.asset,
              fit: widget.fit,
              width: double.infinity,
              cacheWidth: widget.cacheWidth,
              gaplessPlayback: true,
            ),
          ),
        ],
      ),
    ),
  );
}

class _GlowPainter extends CustomPainter {
  final Animation<double> pulse;
  final CachedGlowRoyalClean? glow, activated;
  final double activation;
  final BoxFit fit;
  _GlowPainter(this.pulse, this.glow, this.activated, this.activation, this.fit)
    : super(repaint: pulse);
  @override
  void paint(Canvas canvas, Size size) {
    glow?.paint(
      canvas,
      size,
      fit,
      .45 + Curves.easeInOut.transform(pulse.value) * .4,
    );
    activated?.paint(canvas, size, fit, activation);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) =>
      old.glow != glow ||
      old.activated != activated ||
      old.activation != activation ||
      old.fit != fit;
}
