import 'package:flutter/material.dart';
import 'home_buttons_royal_clean.dart';

class HomeFormRoyalClean extends StatelessWidget {
  final String adminEmail;
  final VoidCallback onAccessControlPressed;
  final VoidCallback onLogoutPressed;

  const HomeFormRoyalClean({
    super.key,
    required this.adminEmail,
    required this.onAccessControlPressed,
    required this.onLogoutPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xB8062B3D),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF155A78)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Painel administrativo', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              Text('Admin autenticado:', style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              SelectableText(adminEmail, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        const SizedBox(height: 18),
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
