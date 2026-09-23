import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core_royal_clean/constants/app_routes_royal_clean.dart';
import 'core_royal_clean/theme/app_theme_royal_clean.dart';
import 'firebase_options.dart';
import 'presentation_royal_clean/auth/login_page_royal_clean.dart';
import 'presentation_royal_clean/auth/account_gate_royal_clean.dart';
import 'presentation_royal_clean/auth/registration_page_royal_clean.dart';
import 'presentation_royal_clean/home/user_management_page_royal_clean.dart';
import 'presentation_royal_clean/auth/admin_route_guard_royal_clean.dart';
import 'presentation_royal_clean/home/access_control_page_royal_clean.dart';
import 'presentation_royal_clean/home/create_invite_page_royal_clean.dart';
import 'presentation_royal_clean/home/home_page_royal_clean.dart';
import 'presentation_royal_clean/home/status_invite/invite_status_details_page_royal_clean.dart';
import 'presentation_royal_clean/home/status_invite/invite_status_page_royal_clean.dart';
import 'presentation_royal_clean/splash/splash_page_royal_clean.dart';
import 'presentation_royal_clean/preview/preview_page_royal_clean.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseInitialization = Future<void>.sync(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kIsWeb) await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  });
  firebaseInitialization.ignore();
  runApp(RoyalCleanApp(firebaseInitialization: firebaseInitialization));
}

class RoyalCleanApp extends StatelessWidget {
  final Future<void> firebaseInitialization;

  const RoyalCleanApp({super.key, required this.firebaseInitialization});

  Stream<bool> _session() async* {
    try {
      await firebaseInitialization;
      yield* FirebaseAuth.instance.authStateChanges().map(
        (user) => user != null,
      );
    } catch (_) {
      yield false;
    }
  }

  Widget _admin(WidgetBuilder builder) => AdminRouteGuardRoyalClean(
    firebaseInitialization: firebaseInitialization,
    builder: builder,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Royal Clean',
      debugShowCheckedModeBanner: false,
      theme: AppThemeRoyalClean.theme,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: child!,
      ),
      initialRoute: AppRoutesRoyalClean.splash,
      routes: {
        AppRoutesRoyalClean.splash: (_) => SplashPageRoyalClean(
          firebaseInitialization: firebaseInitialization,
        ),
        AppRoutesRoyalClean.login: (_) =>
            LoginPageRoyalClean(firebaseInitialization: firebaseInitialization),
        AppRoutesRoyalClean.preview: (_) =>
            PreviewPageRoyalClean(authenticated: _session()),
        '/register': (_) => RegistrationPageRoyalClean(
          firebaseInitialization: firebaseInitialization,
        ),
        '/account': (_) => AccountGateRoyalClean(
          firebaseInitialization: firebaseInitialization,
        ),
        '/my-data': (_) => AccountGateRoyalClean(
          firebaseInitialization: firebaseInitialization,
          personalData: true,
        ),
        '/users': (_) => _admin((_) => const UserManagementPageRoyalClean()),
        AppRoutesRoyalClean.home: (_) =>
            _admin((_) => const HomePageRoyalClean()),
        AppRoutesRoyalClean.accessControl: (_) =>
            _admin((_) => const AccessControlPageRoyalClean()),
        AppRoutesRoyalClean.createInvite: (_) =>
            _admin((_) => const CreateInvitePageRoyalClean()),
        AppRoutesRoyalClean.inviteStatus: (_) =>
            _admin((_) => const InviteStatusPageRoyalClean()),
      },
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutesRoyalClean.inviteStatusDetails) {
          final args = settings.arguments;
          if (args is Map<String, dynamic>) {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => _admin(
                (_) => InviteStatusDetailsPageRoyalClean(inviteMap: args),
              ),
            );
          }
        }
        return null;
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => PreviewPageRoyalClean(authenticated: _session()),
      ),
    );
  }
}
