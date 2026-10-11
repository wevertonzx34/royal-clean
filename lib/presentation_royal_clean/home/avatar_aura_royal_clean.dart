import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Alpha-derived energy behind the original image; the child owns hit testing.
class AvatarAuraRoyalClean extends StatefulWidget {
  final double activation;
  final Widget child;
  final String asset;
  final bool particles;
  final Color? particleColor;
  final Color? contourColor;
  const AvatarAuraRoyalClean({
    super.key,
    this.activation = 0,
    required this.child,
    this.asset = 'assets/preview/royal-store/royal-avatar.webp',
    this.particles = true,
    this.particleColor,
    this.contourColor,
  });
  static Future<void> prepare([
    String asset = 'assets/preview/royal-store/royal-avatar.webp',
  ]) async {
    await _Silhouette.load(asset);
  }

  @override
  State<AvatarAuraRoyalClean> createState() => _AvatarAuraState();
}

class _AvatarAuraState extends State<AvatarAuraRoyalClean>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _flow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  );
  bool _foreground = true, _enabled = false;
  _Silhouette? _shape;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final asset = widget.asset;
    unawaited(
      _Silhouette.load(asset).then((shape) {
        if (mounted && widget.asset == asset) setState(() => _shape = shape);
      }),
    );
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
  void didUpdateWidget(covariant AvatarAuraRoyalClean oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _shape = null;
      final asset = widget.asset;
      unawaited(
        _Silhouette.load(asset).then((shape) {
          if (mounted && widget.asset == asset) setState(() => _shape = shape);
        }),
      );
    }
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
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      if (_shape != null)
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _AuraPainter(
                    _flow,
                    widget.activation,
                    _shape!,
                    widget.particles,
                    widget.particleColor,
                    widget.contourColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      widget.child,
      if (_shape != null)
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _RimPainter(_shape!, widget.contourColor),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// One low-resolution alpha scan per session. No decoding/readback during frames.
class _Silhouette {
  final List<Offset> left, right;
  final ui.Image rim, glow;
  final double ratio;
  _Silhouette(this.left, this.right, this.rim, this.glow, this.ratio);
  static final _cached = <String, Future<_Silhouette?>>{};
  static Future<_Silhouette?> load([
    String asset = 'assets/preview/royal-store/royal-avatar.webp',
  ]) => _cached.putIfAbsent(asset, () => _read(asset));
  static Future<_Silhouette?> _read(String asset) async {
    try {
      final bytes = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(),
        targetWidth: 240,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      final w = image.width, h = image.height;
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final pixels = rgba.buffer.asUint8List();
      final imageContour =
          asset != 'assets/preview/royal-store/royal-avatar.webp';
      int alpha(int x, int y) => x < 0 || y < 0 || x >= w || y >= h
          ? 0
          : imageContour
          ? (pixels[(y * w + x) * 4 + 3] > 100 ? 255 : 0)
          : pixels[(y * w + x) * 4 + 3];
      final left = <Offset>[], right = <Offset>[];
      for (var y = 0; y < h; y += 3) {
        var lo = w, hi = -1;
        for (var x = 0; x < w; x++) {
          if (alpha(x, y) > 100) {
            lo = math.min(lo, x);
            hi = math.max(hi, x);
          }
        }
        if (hi >= lo) {
          left.add(Offset(lo / w, y / h));
          right.add(Offset(hi / w, y / h));
        }
      }
      // Narrow inward reflection follows actual alpha, never washes over the face.
      final edge = Uint8List(w * h * 4);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final a = alpha(x, y);
          final neighbor = math.min(
            math.min(alpha(x - 2, y), alpha(x + 2, y)),
            math.min(alpha(x, y - 2), alpha(x, y + 2)),
          );
          final strength = math.max(0, a - neighbor);
          final i = (y * w + x) * 4;
          final opacity = strength * .38 / 255;
          // decodeImageFromPixels expects premultiplied RGBA.
          edge[i] = (164 * opacity).round();
          edge[i + 1] = (120 * opacity).round();
          edge[i + 2] = (255 * opacity).round();
          edge[i + 3] = (255 * opacity).round();
        }
      }
      final ready = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        edge,
        w,
        h,
        ui.PixelFormat.rgba8888,
        ready.complete,
      );
      image.dispose();
      final rim = await ready.future;
      final recorder = ui.PictureRecorder();
      final padding = w * .25;
      final canvas = Canvas(recorder)..translate(padding, padding);
      for (final layer in const [
        (0xFF123CF2, .42, .18, .048),
        (0xFF763CFF, .43, .075, .026),
        (0xFFA866FF, .50, .030, .014),
        (0xFF8EEAFF, .48, .012, .008),
      ]) {
        // Follow every alpha cutout without joining disconnected image edges.
        // Rasterize once; animation only reuses the cached transparent texture.
        canvas.saveLayer(
          (Offset.zero & Size(w.toDouble(), h.toDouble())).inflate(padding),
          Paint()
            ..imageFilter = ui.ImageFilter.blur(
              sigmaX: w * layer.$4,
              sigmaY: w * layer.$4,
            ),
        );
        canvas.drawImage(
          rim,
          Offset.zero,
          Paint()
            ..colorFilter = ColorFilter.mode(
              Color(layer.$1).withValues(alpha: layer.$2),
              BlendMode.srcIn,
            ),
        );
        canvas.restore();
      }
      final picture = recorder.endRecording();
      final glow = await picture.toImage(
        (w + padding * 2).ceil(),
        (h + padding * 2).ceil(),
      );
      picture.dispose();
      return _Silhouette(left, right, rim, glow, w / h);
    } catch (_) {
      return null;
    } // Original image remains usable if decoding fails.
  }

  Rect rect(Size size) {
    final fitted = applyBoxFit(
      BoxFit.contain,
      Size(ratio, 1),
      size,
    ).destination;
    return Alignment.center.inscribe(fitted, Offset.zero & size);
  }
}

class _AuraPainter extends CustomPainter {
  final Animation<double> flow;
  final double activation;
  final _Silhouette shape;
  final bool particles;
  final Color? particleColor;
  final Color? contourColor;
  _AuraPainter(
    this.flow,
    this.activation,
    this.shape,
    this.particles,
    this.particleColor,
    this.contourColor,
  ) : super(repaint: flow);
  @override
  void paint(Canvas canvas, Size size) {
    if (shape.left.isEmpty) return;
    final r = shape.rect(size), w = r.width, h = r.height;
    Offset map(Offset p) => Offset(r.left + p.dx * w, r.top + p.dy * h);
    final t = flow.value * math.pi * 2;
    final pulse = .92 + .08 * math.sin(t) + activation * .18;
    // Preserve the four colored contours without four GPU blur passes per frame.
    canvas.drawImageRect(
      shape.glow,
      Rect.fromLTWH(
        0,
        0,
        shape.glow.width.toDouble(),
        shape.glow.height.toDouble(),
      ),
      r.inflate(w * .25),
      Paint()
        ..color = Colors.white.withValues(alpha: pulse.clamp(0, 1))
        ..colorFilter = contourColor == null
            ? null
            : ColorFilter.mode(contourColor!, BlendMode.srcIn)
        ..filterQuality = FilterQuality.low,
    );
    if (!particles) return;
    // Small irregular flakes instead of round vapor volumes. Fixed seeds and
    // fade-in/out keep each loop continuous without random frame allocations.
    void ash(Offset center, int seed, double age, double opacity) {
      final radius = w * (.0028 + (seed % 4) * .0012) * 1.02;
      final fade = math.pow(math.sin(math.pi * age), 1.5).toDouble();
      final color =
          particleColor ??
          Color.lerp(
            const Color(0xFFC8BADC),
            const Color(0xFF9EC8E5),
            (seed % 5) / 4,
          )!;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(math.sin(t + seed * 1.7) * .65 + seed);
      final flake = Path()
        ..moveTo(-radius, -radius * .25)
        ..lineTo(-radius * .2, -radius * .65)
        ..lineTo(radius * .8, -radius * .1)
        ..lineTo(radius * .3, radius * .65)
        ..lineTo(-radius * .55, radius * .4)
        ..close();
      canvas.drawPath(
        flake,
        Paint()
          ..color = color.withValues(
            alpha: (fade * opacity * pulse).clamp(0, 1),
          ),
      );
      canvas.restore();
    }

    // Gentle upward drift from both sides, from shoes to hood. No clouds,
    // particle blur, or additional compositing layers are needed.
    for (var i = 0; i < 134; i++) {
      final points = i.isEven ? shape.left : shape.right;
      final side = i.isEven ? -1.0 : 1.0;
      final age = (flow.value * (i % 3 == 0 ? 2 : 1) + i * .618034) % 1;
      final anchor = map(points[((i ~/ 2) * (points.length - 1) / 66).round()]);
      final sway = math.sin(t + i * 1.7 + age * 2) * w * .015;
      ash(
        anchor + Offset(side * w * (.022 + age * .055) + sway, -h * .15 * age),
        i,
        age,
        .65,
      );
    }
    // 174 flakes versus 109 (~60% more), without extra blur/compositing.
    // Independent origins, heights and curved wind drift avoid visible rows.
    final head = (map(shape.left.first) + map(shape.right.first)) / 2;
    double noise(int seed) {
      final value = math.sin(seed * 127.1 + 311.7) * 43758.5453;
      return value - value.floorToDouble();
    }

    for (var i = 0; i < 40; i++) {
      final seed = i + 134;
      final spread = noise(seed) * 2 - 1;
      final phase = noise(seed + 83) * math.pi * 2;
      final age = (flow.value * (i % 4 == 0 ? 2 : 1) + noise(seed + 29)) % 1;
      final height = h * .23 * .9 * (.65 + .35 * noise(seed + 47));
      final gust = math.sin(t + phase + age * 3) * w * .032;
      final eddy = math.sin(t * 2 + phase * 1.7 + age * 5) * w * .010;
      final drift = spread * w * (.05 + age * .09);
      final lift = -height * age + h * .007 * math.sin(t + phase);
      ash(
        head +
            Offset(
              drift + gust + eddy,
              h * (.006 + noise(seed + 61) * .015) + lift,
            ),
        seed,
        age,
        .60,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AuraPainter old) =>
      old.activation != activation ||
      old.shape != shape ||
      old.flow != flow ||
      old.particles != particles ||
      old.particleColor != particleColor ||
      old.contourColor != contourColor;
}

class _RimPainter extends CustomPainter {
  final _Silhouette shape;
  final Color? color;
  _RimPainter(this.shape, this.color);
  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
    shape.rim,
    Rect.fromLTWH(
      0,
      0,
      shape.rim.width.toDouble(),
      shape.rim.height.toDouble(),
    ),
    shape.rect(size),
    Paint()
      ..filterQuality = FilterQuality.low
      ..colorFilter = color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
  );
  @override
  bool shouldRepaint(covariant _RimPainter old) =>
      old.shape != shape || old.color != color;
}
