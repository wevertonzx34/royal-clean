import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Keeps the original dashboard mounted, including filters and hourly refresh.
class OverviewShortcutRoyalClean extends StatefulWidget {
  final Widget child;
  const OverviewShortcutRoyalClean({super.key, required this.child});
  @override
  State<OverviewShortcutRoyalClean> createState() => _OverviewShortcutState();
}

class _OverviewShortcutState extends State<OverviewShortcutRoyalClean>
    with SingleTickerProviderStateMixin {
  // Ajuste aqui: 1.0 = tamanho original; 1.4 = imagem 40% maior.
  static const double _imageScale = 1.4;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  bool _open = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _pulse.stop();
      _pulse.value = 0.4;
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
    'assets/preview/royal-store/royal-cloused.webp',
    height: 160 * _imageScale,
    width: double.infinity,
    fit: BoxFit.contain,
    cacheWidth: 900,
    color: color,
    colorBlendMode: color == null ? null : BlendMode.srcIn,
  );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340 * _imageScale),
          child: Semantics(
            button: true,
            expanded: _open,
            label: _open ? 'Recolher Visão geral' : 'Abrir Visão geral',
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: const ValueKey('overview-image-shortcut'),
                borderRadius: BorderRadius.circular(24),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () => setState(() => _open = !_open),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: SizedBox(
                        height: 190 * _imageScale,
                        width: double.infinity,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedBuilder(
                              animation: _pulse,
                              // Blur only the image alpha, never a rectangular surface.
                              // Keep these static layers cached while animating opacity.
                              child: RepaintBoundary(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Transform.translate(
                                      offset: const Offset(-3, 0),
                                      child: ImageFiltered(
                                        imageFilter: ui.ImageFilter.blur(
                                          sigmaX: 9,
                                          sigmaY: 9,
                                        ),
                                        child: _image(
                                          color: const Color(0xFF9D44FF),
                                        ),
                                      ),
                                    ),
                                    Transform.translate(
                                      offset: const Offset(3, 2),
                                      child: ImageFiltered(
                                        imageFilter: ui.ImageFilter.blur(
                                          sigmaX: 5,
                                          sigmaY: 5,
                                        ),
                                        child: _image(
                                          color: const Color(0xFF244FC7),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              builder: (context, child) => Opacity(
                                opacity:
                                    0.45 +
                                    Curves.easeInOut.transform(_pulse.value) *
                                        0.4,
                                child: child,
                              ),
                            ),
                            RepaintBoundary(child: _image()),
                          ],
                        ),
                      ),
                    ),
                    ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                _open
                                    ? 'Recolher Visão geral'
                                    : 'Abrir Visão geral',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _open ? Icons.expand_less : Icons.expand_more,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      Visibility(visible: _open, maintainState: true, child: widget.child),
    ],
  );
}
