import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// One compact alpha mask per asset, reused across controls and screen visits.
/// Pointer checks sample the cached mask; they do not decode or paint images.
class AlphaHitMaskRoyalClean {
  final int width, height;
  final Uint8List alpha;
  AlphaHitMaskRoyalClean(this.width, this.height, this.alpha);
  static final _cache = <String, Future<AlphaHitMaskRoyalClean?>>{};
  static Future<AlphaHitMaskRoyalClean?> load(String asset) =>
      _cache.putIfAbsent(asset, () async {
        ui.Image? image;
        try {
          final bytes = await rootBundle.load(asset);
          final codec = await ui.instantiateImageCodec(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
            targetWidth: 320,
          );
          try {
            image = (await codec.getNextFrame()).image;
          } finally {
            codec.dispose();
          }
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          if (data == null) return null;
          final pixels = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          final alpha = Uint8List(image.width * image.height);
          for (var i = 0; i < alpha.length; i++) {
            alpha[i] = pixels[i * 4 + 3];
          }
          return AlphaHitMaskRoyalClean(image.width, image.height, alpha);
        } catch (_) {
          return null;
        } finally {
          image?.dispose();
        }
      });

  bool contains(Offset point, Size size) {
    final fitted = applyBoxFit(
      BoxFit.contain,
      Size(width.toDouble(), height.toDouble()),
      size,
    ).destination;
    final rect = Alignment.center.inscribe(fitted, Offset.zero & size);
    if (rect.isEmpty || !rect.contains(point)) return false;
    final x = ((point.dx - rect.left) * width / rect.width).floor().clamp(
      0,
      width - 1,
    );
    final y = ((point.dy - rect.top) * height / rect.height).floor().clamp(
      0,
      height - 1,
    );
    return alpha[y * width + x] > 100;
  }
}

class AlphaHitRegionRoyalClean extends StatefulWidget {
  final String asset;
  final Widget child;
  const AlphaHitRegionRoyalClean({
    super.key,
    required this.asset,
    required this.child,
  });
  @override
  State<AlphaHitRegionRoyalClean> createState() => _AlphaHitRegionState();
}

class _AlphaHitRegionState extends State<AlphaHitRegionRoyalClean> {
  AlphaHitMaskRoyalClean? _mask;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _mask = null;
    final asset = widget.asset;
    AlphaHitMaskRoyalClean.load(asset).then((mask) {
      if (mounted && widget.asset == asset) setState(() => _mask = mask);
    });
  }

  @override
  void didUpdateWidget(covariant AlphaHitRegionRoyalClean oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) _load();
  }

  @override
  Widget build(BuildContext context) =>
      _AlphaHitBox(mask: _mask, child: widget.child);
}

class _AlphaHitBox extends SingleChildRenderObjectWidget {
  final AlphaHitMaskRoyalClean? mask;
  const _AlphaHitBox({required this.mask, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _AlphaHitRenderBox(mask);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _AlphaHitRenderBox renderObject,
  ) {
    renderObject.mask = mask;
  }
}

class _AlphaHitRenderBox extends RenderProxyBox {
  AlphaHitMaskRoyalClean? mask;
  _AlphaHitRenderBox(this.mask);
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) =>
      (mask?.contains(position, size) ?? false) &&
      super.hitTest(result, position: position);
}

/// The live product carousel uses a circular silhouette instead of an asset.
class CircleHitRegionRoyalClean extends SingleChildRenderObjectWidget {
  const CircleHitRegionRoyalClean({super.key, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _CircleHitRenderBox();
}

class _CircleHitRenderBox extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final radius = size.shortestSide / 2;
    return (position - size.center(Offset.zero)).distanceSquared <=
            radius * radius &&
        super.hitTest(result, position: position);
  }
}
