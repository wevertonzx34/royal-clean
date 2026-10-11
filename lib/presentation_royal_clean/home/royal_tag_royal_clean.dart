import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../shared/layout_button_royal_clean.dart';
import 'avatar_aura_royal_clean.dart';
import 'neon_image_royal_clean.dart';

/// Decorative tag: no navigation, with a cached alpha contour and bounded hops.
class RoyalTagRoyalClean extends StatefulWidget {
  final ValueListenable<int> avatarTap;
  const RoyalTagRoyalClean({super.key, required this.avatarTap});
  @override
  State<RoyalTagRoyalClean> createState() => _RoyalTagState();
}

class _RoyalTagState extends State<RoyalTagRoyalClean>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final _cycle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  late final _boost = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  bool _enabled = false, _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.avatarTap.addListener(_avatarTapped);
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
  void didUpdateWidget(covariant RoyalTagRoyalClean oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarTap != widget.avatarTap) {
      oldWidget.avatarTap.removeListener(_avatarTapped);
      widget.avatarTap.addListener(_avatarTapped);
    }
  }

  void _avatarTapped() {
    if (_enabled && _foreground) _boost.forward(from: 0);
  }

  void _updateMotion() {
    if (_enabled && _foreground) {
      if (!_cycle.isAnimating) _cycle.repeat();
    } else {
      _cycle.stop();
      _boost.stop();
      _cycle.value = 0;
      _boost.value = 0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateMotion();
  }

  @override
  void dispose() {
    widget.avatarTap.removeListener(_avatarTapped);
    WidgetsBinding.instance.removeObserver(this);
    _cycle.dispose();
    _boost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutButtonRoyalClean(
    id: 'home.royal-tag',
    child: AnimatedBuilder(
      animation: Listenable.merge([_cycle, _boost]),
      child: Semantics(
        label: 'Royal Tag, elemento decorativo',
        child: const AvatarAuraRoyalClean(
          asset: 'assets/preview/royal-store/royal-tag.webp',
          particleColor: Color(0xFFC08AFF),
          child: NeonImageRoyalClean(
            asset: 'assets/preview/royal-store/royal-tag.webp',
            aspectRatio: 170 / 300,
            cacheWidth: 300,
            glow: Color(0xFF9955FF),
          ),
        ),
      ),
      builder: (_, child) => Transform.translate(
        key: const ValueKey('royal-tag-jump'),
        offset: Offset(
          0,
          -math.max(
            4 * math.sin(math.pi * _cycle.value),
            12 * math.sin(math.pi * _boost.value),
          ),
        ),
        child: child,
      ),
    ),
  );
}
