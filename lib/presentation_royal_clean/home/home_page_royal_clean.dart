import 'package:flutter/material.dart';
import '../../core_royal_clean/constants/app_routes_royal_clean.dart';
import '../../core_royal_clean/services/auth_service_royal_clean.dart';
import '../auth/login_page_royal_clean.dart';
import 'home_background_royal_clean.dart';
import 'home_form_royal_clean.dart';

class HomePageRoyalClean extends StatelessWidget {
  const HomePageRoyalClean({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthServiceRoyalClean.signOut();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPageRoyalClean()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthServiceRoyalClean.currentUser?.email ?? '-';

    return Scaffold(
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
                    onRulesControlPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutesRoyalClean.rulesControl,
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
