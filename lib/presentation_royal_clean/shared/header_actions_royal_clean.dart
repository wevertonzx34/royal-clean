import 'package:royal_clean/presentation_royal_clean/shared/layout_button_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/services/touch_feedback_royal_clean.dart';
import '../../core_royal_clean/services/intercom_royal_clean.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/constants/app_routes_royal_clean.dart';
import '../../core_royal_clean/services/account_access_royal_clean.dart';

void showNotificationsRoyalClean(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pushNamed('/notifications');
}

class NotificationButtonRoyalClean extends StatelessWidget {
  final Color? color;
  final double? iconSize;
  const NotificationButtonRoyalClean({super.key, this.color, this.iconSize});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: IntercomRoyalClean.instance,
    builder: (context, _) {
      final count = IntercomRoyalClean.instance.unreadCount;
      return LayoutButtonRoyalClean(
        id: 'header_actions_royal_clean.control_01',
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
            child: Icon(Icons.public_rounded, color: color, size: iconSize),
          ),
        ),
      );
    },
  );
}

class MyDataButtonRoyalClean extends StatelessWidget {
  final Color? color;
  const MyDataButtonRoyalClean({super.key, this.color});
  @override
  Widget build(BuildContext context) => LayoutButtonRoyalClean(
    id: 'header_actions_royal_clean.control_02',
    child: IconButton(
      tooltip: 'Meus dados',
      icon: Icon(Icons.person_outline, color: color),
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
  const HeaderActionsRoyalClean({
    super.key,
    this.showMyData = true,
    this.color,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      NotificationButtonRoyalClean(color: color),
      if (showMyData) MyDataButtonRoyalClean(color: color),
    ],
  );
}
