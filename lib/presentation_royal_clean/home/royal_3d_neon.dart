import 'dart:async';
import 'dart:math' as math;

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Extracts only the blue neon pixels once; the roof and hit area stay intact.
class Royal3dNeon extends StatefulWidget {
  final double activation;
  const Royal3dNeon({super.key, this.activation = 0});
  static Future<({ui.Image core, ui.Image glow})?>? _cached;
  static Future<({ui.Image core, ui.Image glow})?> prepare() =>
      _cached ??= _mask();
  static Future<({ui.Image core, ui.Image glow})?> _mask() async {
    try {
      final bytes = await rootBundle.load(
        'assets/preview/royal-store/royal-3d.webp',
      );
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      final source = frame.image;
      final data = (await source.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final pixels = data.buffer.asUint8List();
      final mask = Uint8List(pixels.length);
      for (var i = 0; i < pixels.length; i += 4) {
        final r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
        // Reject dark metal, neutral reflections, and saturated blue cutout edges.
        final strength =
            ((b - r - 45) / 110).clamp(0.0, 1.0) *
            ((g - 65) / 100).clamp(0.0, 1.0) *
            pixels[i + 3] /
            255;
        final a = ((strength * 1.45).clamp(0.0, 1.0) * 255).round();
        mask[i] = a;
        mask[i + 1] = a;
        mask[i + 2] = a;
        mask[i + 3] = a;
      }
      final result = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        mask,
        source.width,
        source.height,
        ui.PixelFormat.rgba8888,
        result.complete,
      );
      source.dispose();
      final core = await result.future;
      // Cache the soft halo once; no blur filter runs on animation frames.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImage(
        core,
        Offset.zero,
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 2.8, sigmaY: 2.8),
      );
      final picture = recorder.endRecording();
      final glow = await picture.toImage(core.width, core.height);
      picture.dispose();
      return (core: core, glow: glow);
    } catch (_) {
      return null;
    }
  }

  @override
  State<Royal3dNeon> createState() => _Royal3dNeonState();
}

class _Royal3dNeonState extends State<Royal3dNeon>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _flow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  ({ui.Image core, ui.Image glow})? _mask;
  bool _enabled = false, _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Royal3dNeon.prepare().then((mask) {
      if (mounted) setState(() => _mask = mask);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _update();
  }

  void _update() {
    if (_enabled && _foreground) {
      if (!_flow.isAnimating) _flow.repeat();
    } else {
      _flow.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _update();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        'assets/preview/royal-store/royal-3d.webp',
        fit: BoxFit.contain,
        cacheWidth: 900,
        gaplessPlayback: true,
      ),
      if (_mask != null)
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _NeonPainter(
                    _mask!,
                    _flow,
                    _enabled && _foreground,
                    widget.activation,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _NeonPainter extends CustomPainter {
  final ({ui.Image core, ui.Image glow}) mask;
  final Animation<double> flow;
  final bool animated;
  final double activation;
  _NeonPainter(this.mask, this.flow, this.animated, this.activation)
    : super(repaint: flow);
  @override
  void paint(Canvas canvas, Size size) {
    final source = Size(
      mask.core.width.toDouble(),
      mask.core.height.toDouble(),
    );
    final rect = Alignment.center.inscribe(
      applyBoxFit(BoxFit.contain, source, size).destination,
      Offset.zero & size,
    );
    final phase = flow.value;
    final dip =
        animated &&
        activation < .02 &&
        ((phase > .70 && phase < .715) || (phase > .745 && phase < .765));
    final wave = animated ? (1 + math.sin(phase * math.pi * 4)) / 2 : .5;
    final brightness = (.48 + .26 * wave + (animated ? activation * .24 : 0))
        .clamp(0.0, .98);
    // Saturated blue halo with a cyan-white core gives depth without washing
    // out the metal roof. Both follow precisely the original neon pixels.
    canvas.drawImageRect(
      mask.glow,
      Offset.zero & source,
      rect,
      Paint()
        ..blendMode = BlendMode.screen
        ..colorFilter = ColorFilter.mode(
          const Color(
            0xFF008CFF,
          ).withValues(alpha: dip ? .10 : .35 + .24 * wave),
          BlendMode.srcIn,
        )
        ..filterQuality = FilterQuality.low,
    );
    canvas.drawImageRect(
      mask.core,
      Offset.zero & source,
      rect,
      Paint()
        ..colorFilter = ColorFilter.mode(
          dip
              ? const Color(0x99020C18)
              : const Color(0xFFBEF4FF).withValues(alpha: brightness),
          BlendMode.srcIn,
        )
        ..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(covariant _NeonPainter old) =>
      old.mask != mask ||
      old.animated != animated ||
      old.activation != activation;
}
