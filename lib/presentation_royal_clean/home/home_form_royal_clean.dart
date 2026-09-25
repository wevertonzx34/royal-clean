import 'package:flutter/material.dart';
import 'home_buttons_royal_clean.dart';

class HomeFormRoyalClean extends StatelessWidget {
  final VoidCallback onAccessControlPressed;
  final VoidCallback onLogoutPressed;

  const HomeFormRoyalClean({
    super.key,
    required this.onAccessControlPressed,
    required this.onLogoutPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomePrimaryButtonRoyalClean(
          title: 'Controle de acesso',
          subtitle: 'Gerencie convites de identificação de novos cadastros.',
          icon: Icons.admin_panel_settings_rounded,
          onPressed: onAccessControlPressed,
        ),
        const SizedBox(height: 26),
        OutlinedButton.icon(
          onPressed: onLogoutPressed,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sair'),
        ),
      ],
    );
  }
}
