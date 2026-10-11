import '../home/neon_image_royal_clean.dart';
import '../home/avatar_aura_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/shared/layout_button_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/services/touch_feedback_royal_clean.dart';
import '../../core_royal_clean/services/intercom_royal_clean.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/constants/app_routes_royal_clean.dart';
import '../../core_royal_clean/services/account_access_royal_clean.dart';
import 'notifications_panel_royal_clean.dart';

void showNotificationsRoyalClean(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/notifications'),
      builder: (_) => const Scaffold(body: NotificationsPanelRoyalClean()),
    ),
  );
}

class NotificationButtonRoyalClean extends StatelessWidget {
  final Color? color;
  final bool stockNeon;
  final double? iconSize;
  const NotificationButtonRoyalClean({
    super.key,
    this.color,
    this.iconSize,
    this.stockNeon = false,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: IntercomRoyalClean.instance,
    builder: (context, _) {
      final count = IntercomRoyalClean.instance.unreadCount;
      return LayoutButtonRoyalClean(
        id: 'header_actions_royal_clean.control_01',
        alwaysOverlay: stockNeon,
        child: IconButton(
          tooltip: 'Notificações',
          onPressed: tactileTapRoyalClean(
            () => showNotificationsRoyalClean(context),
          ),
          icon: Badge(
            backgroundColor: const Color(0xFFFF80AB),
            textColor: const Color(0xFF092F43),
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            child: stockNeon
                ? SizedBox(
                    width: iconSize ?? 24,
                    height: iconSize ?? 24,
                    child: const AvatarAuraRoyalClean(
                      asset: 'assets/preview/royal-store/royal-news.webp',
                      particles: false,
                      child: NeonImageRoyalClean(
                        asset: 'assets/preview/royal-store/royal-news.webp',
                        aspectRatio: 1,
                        cacheWidth: 120,
                        glow: Color(0xFFC05AFF),
                      ),
                    ),
                  )
                : Image.asset(
                    'assets/preview/royal-store/royal-news.webp',
                    width: iconSize ?? 24,
                    height: iconSize ?? 24,
                    color: color ?? IconTheme.of(context).color,
                    cacheWidth: 120,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
          ),
        ),
      );
    },
  );
}

class MyDataButtonRoyalClean extends StatelessWidget {
  final Color? color;
  final bool stockNeon;
  const MyDataButtonRoyalClean({super.key, this.color, this.stockNeon = false});
  @override
  Widget build(BuildContext context) => LayoutButtonRoyalClean(
    id: 'header_actions_royal_clean.control_02',
    alwaysOverlay: stockNeon,
    child: IconButton(
      tooltip: 'Meus dados',
      icon: stockNeon
          ? const _StockPersonNeon()
          : Icon(Icons.person_outline, color: color),
      onPressed: tactileTapRoyalClean(
        ModalRoute.of(context)?.settings.name == '/my-data'
            ? null
            : () {
                final status = AccountAccessRoyalClean.instance.value.status;
                final route =
                    status == AccountAccessStatus.admin ||
                        status == AccountAccessStatus.profile
                    ? '/my-data'
                    : AppRoutesRoyalClean.login;
                if (ModalRoute.of(context)?.settings.name != route) {
                  Navigator.pushNamed(context, route);
                }
              },
      ),
    ),
  );
}

class HeaderActionsRoyalClean extends StatelessWidget {
  final bool showMyData;
  final Color? color;
  final bool stockNeon;
  const HeaderActionsRoyalClean({
    super.key,
    this.showMyData = true,
    this.color,
    this.stockNeon = false,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      NotificationButtonRoyalClean(color: color, stockNeon: stockNeon),
      if (showMyData)
        MyDataButtonRoyalClean(color: color, stockNeon: stockNeon),
    ],
  );
}

/// Small glyph glow: keeps the hit area and avoids a rectangular outline.
class _StockPersonNeon extends StatefulWidget {
  const _StockPersonNeon();
  @override
  State<_StockPersonNeon> createState() => _StockPersonNeonState();
}

class _StockPersonNeonState extends State<_StockPersonNeon>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _pulse,
      builder: (_, _) => Icon(
        Icons.person,
        color: Colors.white,
        shadows: [
          Shadow(
            color: const Color(0xFFC05AFF),
            blurRadius: 6 + _pulse.value * 3,
          ),
          Shadow(
            color: const Color(0xFFA636FF),
            blurRadius: 12 + _pulse.value * 4,
          ),
        ],
      ),
    ),
  );
}
