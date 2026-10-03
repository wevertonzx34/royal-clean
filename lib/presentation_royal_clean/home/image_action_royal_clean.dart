import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/touch_feedback_royal_clean.dart';

/// One tactile response and a finite visual sequence before activating a shortcut.
class ImageActionRoyalClean extends StatefulWidget {
  final FutureOr<void> Function() onActivate;
  final FutureOr<void> Function()? onLongActivate;
  final Widget Function(BuildContext context, double flash) builder;
  final int pulses;
  final Duration duration;
  final double scaleDepth;
  final bool replayAfterActivation;
  final bool activateBeforeAnimation;
  final int replayVersion;
  final VoidCallback? feedback;
  const ImageActionRoyalClean({
    super.key,
    required this.onActivate,
    this.onLongActivate,
    required this.builder,
    this.pulses = 1,
    this.duration = const Duration(milliseconds: 160),
    this.scaleDepth = .006,
    this.replayAfterActivation = false,
    this.activateBeforeAnimation = false,
    this.replayVersion = 0,
    this.feedback,
  });

  @override
  State<ImageActionRoyalClean> createState() => _ImageActionState();
}

class _ImageActionState extends State<ImageActionRoyalClean>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this);
  bool _busy = false;

  @override
  void didUpdateWidget(covariant ImageActionRoyalClean oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replayVersion != widget.replayVersion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _busy ||
            MediaQuery.disableAnimationsOf(context) ||
            !TickerMode.valuesOf(context).enabled) {
          return;
        }
        _animation.duration = widget.duration;
        _animation.forward(from: 0);
      });
    }
  }

  Future<void> _activate([bool longPress = false]) async {
    if (_busy) return;
    _busy = true;
    (widget.feedback ?? TouchFeedbackRoyalClean.pulse)();
    try {
      final activatedEarly = widget.activateBeforeAnimation && !longPress;
      if (activatedEarly) await widget.onActivate();
      if (!mounted) return;
      if (!MediaQuery.disableAnimationsOf(context) &&
          TickerMode.valuesOf(context).enabled) {
        _animation.duration = widget.duration;
        await _animation.forward(from: 0).orCancel;
      }
      if (!mounted) return;
      if (!activatedEarly) {
        await (longPress ? widget.onLongActivate!() : widget.onActivate());
      }
      if (mounted && widget.replayAfterActivation) {
        // The returning route re-enables TickerMode on the next frame.
        await WidgetsBinding.instance.endOfFrame;
      }
      if (mounted &&
          widget.replayAfterActivation &&
          !MediaQuery.disableAnimationsOf(context) &&
          TickerMode.valuesOf(context).enabled) {
        _animation.duration = widget.duration;
        await _animation.forward(from: 0).orCancel;
      }
    } on TickerCanceled {
      // A disposed shortcut must not open a route after it leaves the screen.
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: _activate,
    onLongPress: widget.onLongActivate == null ? null : () => _activate(true),
    child: AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final wave = math.sin(_animation.value * math.pi * widget.pulses);
        final flash = wave * wave;
        return Transform.scale(
          scale: 1 - widget.scaleDepth * flash,
          child: widget.builder(context, flash),
        );
      },
    ),
  );
}
