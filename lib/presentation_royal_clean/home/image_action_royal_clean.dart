import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/touch_feedback_royal_clean.dart';

/// One tactile response and a finite visual sequence before activating a shortcut.
class ImageActionRoyalClean extends StatefulWidget {
  final FutureOr<void> Function() onActivate;
  final Widget Function(BuildContext context, double flash) builder;
  final int pulses;
  final Duration duration;
  final double scaleDepth;
  final bool replayAfterActivation;
  const ImageActionRoyalClean({
    super.key,
    required this.onActivate,
    required this.builder,
    this.pulses = 1,
    this.duration = const Duration(milliseconds: 160),
    this.scaleDepth = .006,
    this.replayAfterActivation = false,
  });

  @override
  State<ImageActionRoyalClean> createState() => _ImageActionState();
}

class _ImageActionState extends State<ImageActionRoyalClean>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this);
  bool _busy = false;

  Future<void> _activate() async {
    if (_busy) return;
    _busy = true;
    TouchFeedbackRoyalClean.pulse();
    try {
      if (!MediaQuery.disableAnimationsOf(context) &&
          TickerMode.valuesOf(context).enabled) {
        _animation.duration = widget.duration;
        await _animation.forward(from: 0).orCancel;
      }
      if (!mounted) return;
      await widget.onActivate();
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
