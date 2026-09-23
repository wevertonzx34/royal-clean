import 'package:flutter/material.dart';
import '../../core_royal_clean/constants/app_routes_royal_clean.dart';
import '../../core_royal_clean/services/auth_service_royal_clean.dart';
import 'home_background_royal_clean.dart';
import 'home_form_royal_clean.dart';

class HomePageRoyalClean extends StatelessWidget {
  const HomePageRoyalClean({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthServiceRoyalClean.signOut();

    if (!context.mounted) return;

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutesRoyalClean.preview, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthServiceRoyalClean.currentUser?.email ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel administrativo'),
        actions: [
          IconButton(
            tooltip: 'Usuários e perfis',
            onPressed: () => Navigator.pushNamed(context, '/users'),
            icon: const Icon(Icons.manage_accounts),
          ),
          IconButton(
            tooltip: 'Meus dados',
            onPressed: () => Navigator.pushNamed(context, '/my-data'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: HomeBackgroundRoyalClean(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isSmall = constraints.maxWidth < 700;
            final double maxWidth = isSmall ? 560 : 720;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmall ? 16 : 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: HomeFormRoyalClean(
                    adminEmail: email,
                    onAccessControlPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutesRoyalClean.accessControl,
                      );
                    },
                    onLogoutPressed: () => _logout(context),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
