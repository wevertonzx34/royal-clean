import 'image_action_royal_clean.dart';
import 'package:flutter/material.dart';
import 'neon_image_royal_clean.dart';

/// Preserves the dashboard state while its panel is closed.
class OverviewShortcutRoyalClean extends StatefulWidget {
  final Widget child;
  final double? height;
  final double overlayBottomInset;
  final double overlayTopInset;
  final ValueNotifier<bool>? openState;
  final Widget? foreground;
  const OverviewShortcutRoyalClean({
    super.key,
    required this.child,
    this.height,
    this.overlayBottomInset = 16,
    this.overlayTopInset = 8,
    this.openState,
    this.foreground,
  });
  @override
  State<OverviewShortcutRoyalClean> createState() => _OverviewShortcutState();
}

class _OverviewShortcutState extends State<OverviewShortcutRoyalClean> {
  final _localOpen = ValueNotifier<bool>(false);
  ValueNotifier<bool> get _state => widget.openState ?? _localOpen;
  @override
  void dispose() {
    _localOpen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _state,
    builder: (context, open, _) => LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        height: widget.height ?? constraints.maxWidth * 1245 / 735,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              button: true,
              expanded: open,
              label: 'Abrir Visão geral',
              child: ImageActionRoyalClean(
                key: const ValueKey('overview-image-shortcut'),
                onActivate: () => _state.value = !open,
                builder: (_, flash) => const NeonImageRoyalClean(
                  asset: 'assets/preview/royal-store/royal-home.webp',
                  aspectRatio: 735 / 1245,
                  fit: BoxFit.cover,
                  glow: Color(0xFF7955E8),
                ),
              ),
            ),
            if (!open && widget.foreground != null) widget.foreground!,
            Visibility(
              key: const ValueKey('overview-panel'),
              visible: open,
              maintainState: true,
              child: Padding(
                padding: EdgeInsets.only(top: widget.overlayTopInset),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      8,
                      0,
                      8,
                      widget.overlayBottomInset,
                    ),
                    child: Column(children: [widget.child]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
