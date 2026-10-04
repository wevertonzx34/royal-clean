import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Session-local transparent textures. Blur is rendered once, never per frame.
class CachedGlowRoyalClean {
  final ui.Image image;
  final Size contentSize;
  final double padding;
  const CachedGlowRoyalClean(this.image, this.contentSize, this.padding);
  static final _cache =
      <(String, Color, Color?), Future<CachedGlowRoyalClean?>>{};

  static Future<CachedGlowRoyalClean?> load(
    String asset,
    Color color, [
    Color? secondary,
  ]) => _cache.putIfAbsent((asset, color, secondary), () async {
    ui.Image? source;
    ui.Picture? picture;
    try {
      final bytes = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        targetWidth: 240,
      );
      try {
        source = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      final size = Size(source.width.toDouble(), source.height.toDouble());
      const padding = 32.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..translate(padding, padding);
      canvas.saveLayer(
        (Offset.zero & size).inflate(padding),
        Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      );
      canvas.drawImage(
        source,
        Offset.zero,
        Paint()..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
      );
      if (secondary != null) {
        // Tint inside the original alpha; the texture background stays transparent.
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..blendMode = BlendMode.srcIn
            ..shader = LinearGradient(
              colors: [color, secondary],
            ).createShader(Offset.zero & size),
        );
      }
      canvas.restore();
      picture = recorder.endRecording();
      final image = await picture.toImage(
        (size.width + padding * 2).ceil(),
        (size.height + padding * 2).ceil(),
      );
      return CachedGlowRoyalClean(image, size, padding);
    } catch (_) {
      return null;
    } finally {
      source?.dispose();
      picture?.dispose();
    }
  });

  void paint(Canvas canvas, Size size, BoxFit fit, double opacity) {
    if (opacity <= 0 || size.isEmpty) return;
    final fitted = applyBoxFit(fit, contentSize, size);
    final source = Alignment.center
        .inscribe(fitted.source, Offset.zero & contentSize)
        .shift(Offset(padding, padding))
        .inflate(padding);
    final destination = Alignment.center
        .inscribe(fitted.destination, Offset.zero & size)
        .inflate(padding * fitted.destination.width / fitted.source.width);
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity.clamp(0, 1))
        ..filterQuality = FilterQuality.low,
    );
  }
}
