import '../../core_royal_clean/services/intercom_royal_clean.dart';
import 'notifications_panel_royal_clean.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/constants/app_routes_royal_clean.dart';
import '../../core_royal_clean/services/account_access_royal_clean.dart';

void showNotificationsRoyalClean(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => const NotificationsPanelRoyalClean(),
  );
}

class NotificationButtonRoyalClean extends StatelessWidget {
  final Color? color;
  const NotificationButtonRoyalClean({super.key, this.color});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: IntercomRoyalClean.instance,
    builder: (context, _) {
      final count = IntercomRoyalClean.instance.unreadCount;
      return IconButton(
        tooltip: 'Notificações',
        onPressed: () => showNotificationsRoyalClean(context),
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          child: Icon(Icons.public_rounded, color: color),
        ),
      );
    },
  );
}

class MyDataButtonRoyalClean extends StatelessWidget {
  final Color? color;
  const MyDataButtonRoyalClean({super.key, this.color});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Meus dados',
    icon: Icon(Icons.person_outline, color: color),
    onPressed: ModalRoute.of(context)?.settings.name == '/my-data'
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
