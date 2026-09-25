import 'package:flutter/material.dart';
import '../../core_royal_clean/constants/app_routes_royal_clean.dart';
import 'home_background_royal_clean.dart';
import '../auth/logout_royal_clean.dart';
import 'home_form_royal_clean.dart';
import '../shared/header_actions_royal_clean.dart';

class HomePageRoyalClean extends StatelessWidget {
  const HomePageRoyalClean({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel administrativo'),
        actions: const [HeaderActionsRoyalClean()],
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
                    onAccessControlPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutesRoyalClean.accessControl,
                      );
                    },
                    onLogoutPressed: () => logoutToPreviewRoyalClean(context),
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
