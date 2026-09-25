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
          title: 'Interfone',
          subtitle: 'Publique mensagens e acompanhe os avisos da Royal Clean.',
          icon: Icons.campaign_outlined,
          onPressed: () => Navigator.pushNamed(context, '/intercom'),
        ),
        const SizedBox(height: 14),
        HomePrimaryButtonRoyalClean(
          title: 'Controle de acesso',
          subtitle: 'Gerencie convites de identificação de novos cadastros.',
          icon: Icons.admin_panel_settings_rounded,
          onPressed: onAccessControlPressed,
        ),
        const SizedBox(height: 14),
        HomePrimaryButtonRoyalClean(
          title: 'Integração Bling',
          subtitle: 'Configure a conexão segura do catálogo Royal Clean.',
          icon: Icons.hub_outlined,
          onPressed: () => Navigator.pushNamed(context, '/bling'),
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
