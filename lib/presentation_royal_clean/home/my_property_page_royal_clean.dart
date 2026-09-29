import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core_royal_clean/services/touch_feedback_royal_clean.dart';
import '../shared/header_actions_royal_clean.dart';
import 'image_action_royal_clean.dart';

class MyPropertyPageRoyalClean extends StatelessWidget {
  const MyPropertyPageRoyalClean({super.key});

  @override
  Widget build(BuildContext context) =>
      const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Color(0xFF030322),
          body: _PropertyScene(interactive: true),
        ),
      );
}

class MyPropertyBackgroundRoyalClean extends StatelessWidget {
  const MyPropertyBackgroundRoyalClean({super.key});

  @override
  Widget build(BuildContext context) =>
      const _PropertyScene(interactive: false);
}

/// Artwork and interactive overlays share one cover transform and crop.
class _PropertyScene extends StatelessWidget {
  final bool interactive;
  const _PropertyScene({required this.interactive});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final coverScale = math.max(
        constraints.maxWidth / 432,
        constraints.maxHeight / 768,
      );
      return SizedBox.expand(
        child: FittedBox(
          key: const ValueKey('property-cover'),
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: 432,
            height: 768,
            child: _PropertyArtwork(
              interactive: interactive,
              visibleWidth: constraints.maxWidth / coverScale,
            ),
          ),
        ),
      );
    },
  );
}

/// Logical canvas preserves the original artwork's 2250:4000 proportions.
class _PropertyArtwork extends StatelessWidget {
  final bool interactive;
  final double visibleWidth;
  const _PropertyArtwork({
    required this.interactive,
    required this.visibleWidth,
  });
  static const pink = Color(0xFFFFB9DE);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final scale = width / 2250;
      final imageHeight = 4000 * scale;
      final profileWidth = math.min(width * .615 * 1.4, visibleWidth);
      return SingleChildScrollView(
        child: SizedBox(
          width: width,
          height: math.max(constraints.maxHeight, imageHeight),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: imageHeight,
                child: Image.asset(
                  'assets/preview/royal-store/royal-pixels.webp',
                  fit: BoxFit.fill,
                  cacheWidth: 1080,
                  excludeFromSemantics: true,
                ),
              ),
              if (interactive) ...[
                Positioned(
                  top: imageHeight * .07,
                  left: (width - profileWidth) / 2,
                  width: profileWidth,
                  child: Semantics(
                    button: true,
                    label: 'Royal Perfil',
                    hint: 'Atalho em preparação',
                    child: ImageActionRoyalClean(
                      key: const ValueKey('royal-perfil-shortcut'),
                      pulses: 2,
                      scaleDepth: .008,
                      duration: const Duration(milliseconds: 500),
                      onActivate: () {},
                      builder: (context, flash) => Image.asset(
                        'assets/preview/royal-store/royal-perfil.webp',
                        width: width,
                        fit: BoxFit.fitWidth,
                        cacheWidth: 1080,
                        color: Color.lerp(Colors.white, pink, flash * .25),
                        colorBlendMode: BlendMode.modulate,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: imageHeight * .07 + profileWidth * 825 / 2263 + 8,
                  left: width * .2,
                  right: width * .2,
                  child: const Text(
                    'My propriedade',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: pink,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(color: Color(0xAAFF7EC6), blurRadius: 8),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 1200 * scale - 24,
                  left: math.max(0, 295 * scale - 24 + width * .03),
                  child: _PinkNeon(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        key: const ValueKey('property-back'),
                        tooltip: 'Voltar',
                        iconSize: 19,
                        onPressed: tactileTapRoyalClean(
                          () => Navigator.of(context).maybePop(),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 1080 * scale - 24 + imageHeight * .02,
                  left: (1740 * scale - 48).clamp(
                    0.0,
                    math.max(0.0, width - 96),
                  ),
                  child: _PinkNeon(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.translate(
                          offset: Offset(width * .01, 0),
                          child: const NotificationButtonRoyalClean(
                            color: pink,
                            iconSize: 23.52,
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(-width * .02, 0),
                          child: const MyDataButtonRoyalClean(color: pink),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _PinkNeon extends StatefulWidget {
  final Widget child;
  const _PinkNeon({required this.child});
  @override
  State<_PinkNeon> createState() => _PinkNeonState();
}

class _PinkNeonState extends State<_PinkNeon>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateAnimation();
  }

  void _updateAnimation() {
    if (_foreground &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _pulse,
      child: widget.child,
      builder: (context, child) => IconTheme(
        data: IconThemeData(
          color: _PropertyArtwork.pink,
          shadows: [
            Shadow(
              color: const Color(
                0xFFFF79C6,
              ).withValues(alpha: .45 + .25 * _pulse.value),
              blurRadius: 4 + 5 * _pulse.value,
            ),
          ],
        ),
        child: child!,
      ),
    ),
  );
}
