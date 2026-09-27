import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class NeonImageRoyalClean extends StatefulWidget {
  final String asset;
  final double aspectRatio;
  final Color glow;
  final BoxFit fit;
  final double activation;
  const NeonImageRoyalClean({
    super.key,
    required this.asset,
    required this.aspectRatio,
    required this.glow,
    this.fit = BoxFit.contain,
    this.activation = 0,
  });
  @override
  State<NeonImageRoyalClean> createState() => _NeonImageState();
}

class _NeonImageState extends State<NeonImageRoyalClean>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _pulse.stop();
      _pulse.value = .4;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _image({Color? color}) => Image.asset(
    widget.asset,
    fit: widget.fit,
    width: double.infinity,
    cacheWidth: 900,
    color: color,
    colorBlendMode: color == null ? null : BlendMode.srcIn,
  );
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            child: RepaintBoundary(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: _image(color: widget.glow),
              ),
            ),
            builder: (_, child) => Opacity(
              opacity: .45 + Curves.easeInOut.transform(_pulse.value) * .4,
              child: child,
            ),
          ),
          Opacity(
            opacity: widget.activation,
            child: RepaintBoundary(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: _image(color: const Color(0xFF008CFF)),
              ),
            ),
          ),
          RepaintBoundary(child: _image()),
        ],
      ),
    ),
  );
}
