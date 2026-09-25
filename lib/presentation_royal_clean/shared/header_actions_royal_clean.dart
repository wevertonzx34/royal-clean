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
    builder: (context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Notificações',
                    style: TextStyle(
                      color: Color(0xFF092F43),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar notificações',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF092F43),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Icon(
              Icons.public_rounded,
              color: Color(0xFF007F9F),
              size: 44,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma notificação por aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF092F43),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enquanto isso, explore as novidades e parcerias da Royal Clean.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF607783), height: 1.5),
            ),
          ],
        ),
      ),
    ),
  );
}

class NotificationButtonRoyalClean extends StatelessWidget {
  final Color? color;
  const NotificationButtonRoyalClean({super.key, this.color});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Notificações',
    onPressed: () => showNotificationsRoyalClean(context),
    icon: Icon(Icons.public_rounded, color: color),
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
