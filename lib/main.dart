import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core_royal_clean/constants/app_routes_royal_clean.dart';
import 'core_royal_clean/theme/app_theme_royal_clean.dart';
import 'firebase_options.dart';
import 'presentation_royal_clean/auth/login_page_royal_clean.dart';
import 'presentation_royal_clean/home/access_control_page_royal_clean.dart';
import 'presentation_royal_clean/home/create_invite_page_royal_clean.dart';
import 'presentation_royal_clean/home/home_page_royal_clean.dart';
import 'presentation_royal_clean/home/rules_control_page_royal_clean.dart';
import 'presentation_royal_clean/home/status_invite/invite_status_details_page_royal_clean.dart';
import 'presentation_royal_clean/home/status_invite/invite_status_page_royal_clean.dart';
import 'presentation_royal_clean/splash/splash_page_royal_clean.dart';
import 'presentation_royal_clean/preview/preview_page_royal_clean.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseInitialization = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(RoyalCleanApp(firebaseInitialization: firebaseInitialization));
}

class RoyalCleanApp extends StatelessWidget {
  final Future<void> firebaseInitialization;

  const RoyalCleanApp({super.key, required this.firebaseInitialization});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Royal Clean',
      debugShowCheckedModeBanner: false,
      theme: AppThemeRoyalClean.theme,
      initialRoute: AppRoutesRoyalClean.splash,
      routes: {
        AppRoutesRoyalClean.splash: (_) => SplashPageRoyalClean(
          firebaseInitialization: firebaseInitialization,
        ),
        AppRoutesRoyalClean.login: (_) => const LoginPageRoyalClean(),
        AppRoutesRoyalClean.preview: (_) => const PreviewPageRoyalClean(),
        AppRoutesRoyalClean.home: (_) => const HomePageRoyalClean(),
        AppRoutesRoyalClean.accessControl: (_) =>
            const AccessControlPageRoyalClean(),
        AppRoutesRoyalClean.rulesControl: (_) =>
            const RulesControlPageRoyalClean(),
        AppRoutesRoyalClean.createInvite: (_) =>
            const CreateInvitePageRoyalClean(),
        AppRoutesRoyalClean.inviteStatus: (_) =>
            const InviteStatusPageRoyalClean(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutesRoyalClean.inviteStatusDetails) {
          final args = settings.arguments;
          if (args is Map<String, dynamic>) {
            return MaterialPageRoute(
              builder: (_) =>
                  InviteStatusDetailsPageRoyalClean(inviteMap: args),
            );
          }
        }
        return null;
      },
    );
  }
}
