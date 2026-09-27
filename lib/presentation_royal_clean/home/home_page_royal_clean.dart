import 'package:flutter/material.dart';
import '../../core_royal_clean/constants/app_routes_royal_clean.dart';
import 'home_background_royal_clean.dart';
import '../auth/logout_royal_clean.dart';
import 'home_form_royal_clean.dart';
import '../shared/header_actions_royal_clean.dart';
import 'dashboard_chart_royal_clean.dart';
import 'overview_shortcut_royal_clean.dart';

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

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmall ? 16 : 24,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    OverviewShortcutRoyalClean(
                      child: DashboardChartRoyalClean(
                        availableHeight: constraints.maxHeight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: HomeFormRoyalClean(
                        onAccessControlPressed: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutesRoyalClean.accessControl,
                          );
                        },
                        onLogoutPressed: () =>
                            logoutToPreviewRoyalClean(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
