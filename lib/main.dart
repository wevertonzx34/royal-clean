import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core_royal_clean/constants/app_routes_royal_clean.dart';
import 'core_royal_clean/theme/app_theme_royal_clean.dart';
import 'core_royal_clean/services/session_preferences_royal_clean.dart';
import 'core_royal_clean/services/biometric_access_royal_clean.dart';
import 'presentation_royal_clean/auth/biometric_gate_royal_clean.dart';
import 'firebase_options.dart';
import 'core_royal_clean/services/account_access_royal_clean.dart';
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
import 'presentation_royal_clean/preview/partnership_content_royal_clean.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseInitialization = Future<void>.sync(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    var biometricSession = false;
    try {
      biometricSession = await BiometricAccessRoyalClean.instance.restore();
    } catch (_) {
      // A corrupt/unavailable device binding must never expose a restored session.
      await FirebaseAuth.instance.signOut();
    }
    if (!biometricSession) {
      await SessionPreferencesRoyalClean.instance.restore(
        signOut: () => FirebaseAuth.instance.signOut(),
        configureWebPersistence: kIsWeb
            ? (remember) => FirebaseAuth.instance.setPersistence(
                remember ? Persistence.LOCAL : Persistence.NONE,
              )
            : null,
      );
    }
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
    AccountAccessRoyalClean.instance.start();
    if (kDebugMode && const bool.fromEnvironment('VERIFY_APP_CHECK')) {
      debugPrint(
        'RoyalClean session: retained=${FirebaseAuth.instance.currentUser != null}; biometric=${BiometricAccessRoyalClean.instance.enabled}; locked=${BiometricAccessRoyalClean.instance.locked}',
      );
      unawaited(_verifyAppCheck());
    }
  });
  firebaseInitialization.ignore();
  runApp(RoyalCleanApp(firebaseInitialization: firebaseInitialization));
}

Future<void> _verifyAppCheck() async {
  try {
    final token = await FirebaseAppCheck.instance
        .getToken(true)
        .timeout(const Duration(seconds: 20));
    debugPrint(
      'RoyalClean AppCheck verification: ${token != null && token.isNotEmpty ? 'OK' : 'EMPTY'}',
    );
  } catch (_) {
    debugPrint('RoyalClean AppCheck verification: FAILED');
  }
}

class RoyalCleanApp extends StatelessWidget {
  final Future<void> firebaseInitialization;

  const RoyalCleanApp({super.key, required this.firebaseInitialization});

  Stream<bool> _session() async* {
    try {
      await firebaseInitialization;
      yield* BiometricAccessRoyalClean.instance.visibleSession(
        FirebaseAuth.instance.authStateChanges().map((user) => user != null),
      );
    } catch (_) {
      yield false;
    }
  }

  Future<void> _prepareAccount() async {
    await firebaseInitialization;
    final biometric = BiometricAccessRoyalClean.instance;
    if (biometric.locked && !await biometric.unlock()) {
      throw const BiometricCancelledRoyalClean();
    }
    await AccountAccessRoyalClean.instance.ready();
  }

  Stream<List<PublicPartnerRoyalClean>> _partnerships({
    bool ads = false,
  }) async* {
    await firebaseInitialization;
    yield* PartnershipContentRoyalClean.watch(ads: ads);
  }

  Widget _admin(WidgetBuilder builder) => AdminRouteGuardRoyalClean(
    firebaseInitialization: firebaseInitialization,
    builder: (context) => BiometricGateRoyalClean(builder: builder),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Royal Clean',
      debugShowCheckedModeBanner: false,
      theme: AppThemeRoyalClean.theme,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppThemeRoyalClean.systemUiStyle,
        child: child!,
      ),
      initialRoute: AppRoutesRoyalClean.splash,
      routes: {
        AppRoutesRoyalClean.splash: (_) => SplashPageRoyalClean(
          firebaseInitialization: firebaseInitialization,
        ),
        AppRoutesRoyalClean.login: (_) =>
            LoginPageRoyalClean(firebaseInitialization: firebaseInitialization),
        AppRoutesRoyalClean.preview: (_) => PreviewPageRoyalClean(
          partners: _partnerships(),
          partnerAds: _partnerships(ads: true),
          authenticated: _session(),
          prepareAccount: _prepareAccount,
        ),
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
        builder: (_) => PreviewPageRoyalClean(
          partners: _partnerships(),
          partnerAds: _partnerships(ads: true),
          authenticated: _session(),
          prepareAccount: _prepareAccount,
        ),
      ),
    );
  }
}
