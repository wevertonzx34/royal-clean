import 'package:flutter/material.dart';
import '../auth/admin_route_guard_royal_clean.dart';
import '../shared/layout_button_royal_clean.dart';
import 'dashboard_chart_royal_clean.dart';
import 'image_action_royal_clean.dart';
import 'neon_image_royal_clean.dart';

/// Stock shortcut reuses the home artwork, gesture animation and live dashboard.
class StockDataShortcutRoyalClean extends StatelessWidget {
  final Future<void> Function()? onOpen;
  const StockDataShortcutRoyalClean({super.key, this.onOpen});

  Future<void> _open(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: const Color(0xF0082538),
      builder: (context) => FractionallySizedBox(
        heightFactor: .85,
        child: AdminRouteGuardRoyalClean(
          firebaseInitialization: Future<void>.value(),
          builder: (_) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            child: DashboardChartRoyalClean(
              availableHeight: MediaQuery.sizeOf(context).height * .8,
              overlaySurface: true,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 100,
    height: 100,
    child: Tooltip(
      message: 'Visão geral',
      child: Semantics(
        button: true,
        label: 'Abrir Visão geral do estoque',
        child: LayoutButtonRoyalClean(
          id: 'stock.royal-dados',
          child: ImageActionRoyalClean(
            key: const ValueKey('stock-data-shortcut'),
            pulses: 2,
            replayAfterActivation: true,
            duration: const Duration(milliseconds: 600),
            scaleDepth: .018,
            onActivate: () => onOpen?.call() ?? _open(context),
            builder: (_, flash) => NeonImageRoyalClean(
              asset: 'assets/preview/royal-store/royal-dados.webp',
              aspectRatio: 1,
              cacheWidth: 300,
              glow: const Color(0xFF5CE7EC),
              activation: flash,
              activationGlow: const Color(0xFFC05AFF),
              activationSecondaryGlow: const Color(0xFF1623A8),
            ),
          ),
        ),
      ),
    ),
  );
}
