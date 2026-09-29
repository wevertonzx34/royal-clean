import 'package:royal_clean/presentation_royal_clean/shared/layout_button_royal_clean.dart';
import 'image_action_royal_clean.dart';
import '../../core_royal_clean/services/touch_feedback_royal_clean.dart';
import 'package:flutter/material.dart';
import 'neon_image_royal_clean.dart';
import 'wall_light_royal_clean.dart';

/// Preserves the dashboard state while its panel is closed.
class OverviewShortcutRoyalClean extends StatefulWidget {
  final Widget child;
  final double? height;
  final double overlayBottomInset;
  final double overlayTopInset;
  final ValueNotifier<bool>? openState;
  final Widget? foreground;
  final Future<void> Function()? onHomeActivate;
  const OverviewShortcutRoyalClean({
    super.key,
    required this.child,
    this.height,
    this.overlayBottomInset = 16,
    this.overlayTopInset = 8,
    this.openState,
    this.foreground,
    this.onHomeActivate,
  });
  @override
  State<OverviewShortcutRoyalClean> createState() => _OverviewShortcutState();
}

class _OverviewShortcutState extends State<OverviewShortcutRoyalClean> {
  final _localOpen = ValueNotifier<bool>(false);
  final _homeTouch = ValueNotifier<int>(0);
  ValueNotifier<bool> get _state => widget.openState ?? _localOpen;
  @override
  void dispose() {
    _localOpen.dispose();
    _homeTouch.dispose();
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
              label: widget.onHomeActivate != null
                  ? 'Abrir My Propriedade'
                  : open
                  ? 'Voltar para royal-home'
                  : 'Royal Home',
              child: LayoutButtonRoyalClean(
                id: 'overview_shortcut_royal_clean.control_01',
                child: ImageActionRoyalClean(
                  key: const ValueKey('overview-image-shortcut'),
                  feedback: TouchFeedbackRoyalClean.homePulse,
                  replayAfterActivation: widget.onHomeActivate != null,
                  onActivate: () async {
                    _state.value = false;
                    _homeTouch.value++;
                    if (widget.onHomeActivate != null) {
                      if (!MediaQuery.disableAnimationsOf(context)) {
                        await Future<void>.delayed(
                          const Duration(milliseconds: 180),
                        );
                      }
                      if (!mounted) return;
                      await widget.onHomeActivate!();
                      if (!mounted) return;
                      _homeTouch.value++;
                    }
                  },
                  builder: (_, flash) => const NeonImageRoyalClean(
                    asset: 'assets/preview/royal-store/royal-home.webp',
                    aspectRatio: 735 / 1245,
                    fit: BoxFit.cover,
                    glow: Color(0xFF7955E8),
                  ),
                ),
              ),
            ),
            WallLightRoyalClean(openState: _state, faultSignal: _homeTouch),
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
