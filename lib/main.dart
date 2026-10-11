import 'core_royal_clean/services/touch_feedback_royal_clean.dart';
import 'dart:async';
import 'core_royal_clean/services/admin_push_royal_clean.dart';
import 'presentation_royal_clean/shared/notifications_panel_royal_clean.dart';
import 'core_royal_clean/services/intercom_royal_clean.dart';
import 'presentation_royal_clean/home/intercom_page_royal_clean.dart';
import 'presentation_royal_clean/home/bling_integration_page_royal_clean.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'presentation_royal_clean/home/bling_data_page_royal_clean.dart';
import 'package:flutter/services.dart';
import 'core_royal_clean/constants/app_routes_royal_clean.dart';
import 'core_royal_clean/theme/app_theme_royal_clean.dart';
import 'core_royal_clean/services/session_preferences_royal_clean.dart';
import 'core_royal_clean/services/biometric_access_royal_clean.dart';
import 'presentation_royal_clean/auth/biometric_gate_royal_clean.dart';
import 'firebase_options.dart';
import 'core_royal_clean/services/web_configuration_royal_clean.dart';
import 'core_royal_clean/services/account_access_royal_clean.dart';
import 'presentation_royal_clean/auth/login_page_royal_clean.dart';
import 'presentation_royal_clean/auth/account_gate_royal_clean.dart';
import 'presentation_royal_clean/auth/registration_page_royal_clean.dart';
import 'presentation_royal_clean/home/user_management_page_royal_clean.dart';
import 'presentation_royal_clean/auth/admin_route_guard_royal_clean.dart';
import 'presentation_royal_clean/home/access_control_page_royal_clean.dart';
import 'presentation_royal_clean/home/create_invite_page_royal_clean.dart';
import 'presentation_royal_clean/home/home_page_royal_clean.dart';
import 'presentation_royal_clean/home/home_background_royal_clean.dart';
import 'presentation_royal_clean/home/status_invite/invite_status_details_page_royal_clean.dart';
import 'presentation_royal_clean/home/status_invite/invite_status_page_royal_clean.dart';
import 'presentation_royal_clean/splash/splash_page_royal_clean.dart';
import 'presentation_royal_clean/preview/preview_page_royal_clean.dart';
import 'presentation_royal_clean/preview/partnership_content_royal_clean.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const testAppCheck =
      !kReleaseMode && (kDebugMode || bool.fromEnvironment('APP_CHECK_DEBUG'));
  adminNotificationOpenedRoyalClean.addListener(() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      royalNotificationNavigator.currentState?.pushNamed('/notifications');
    });
  });
  final firebaseInitialization = Future<void>.sync(() async {
    if (kIsWeb) WebConfigurationRoyalClean.requireAppCheck();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaEnterpriseProvider(
          WebConfigurationRoyalClean.appCheckSiteKey,
        ),
      );
    }
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
    if (!kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: testAppCheck
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: testAppCheck
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
    }
    AccountAccessRoyalClean.instance.start();
    IntercomRoyalClean.instance.start();
    AdminPushRoyalClean.instance.start();
    if (!kReleaseMode && const bool.fromEnvironment('VERIFY_APP_CHECK')) {
      debugPrint(
        'RoyalClean session: retained=${FirebaseAuth.instance.currentUser != null}; biometric=${BiometricAccessRoyalClean.instance.enabled}; locked=${BiometricAccessRoyalClean.instance.locked}',
      );
      unawaited(_verifyAppCheck());
    }
  });
  unawaited(
    firebaseInitialization.catchError((Object error, StackTrace stack) {
      // Keep the public preview available, without logging tokens or personal data.
      debugPrint(
        'RoyalClean initialization unavailable: ${error is FirebaseException ? error.code : error.runtimeType}',
      );
    }),
  );
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

final royalNotificationNavigator = GlobalKey<NavigatorState>();

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
    final access = AccountAccessRoyalClean.instance;
    access.start();
    // AccountGate renders pending access and never builds private content early.
    // Only failed sessions need the explicit retry before navigation.
    if (access.value.status == AccountAccessStatus.unavailable) {
      await access.ready();
    }
  }

  Stream<List<PublicPartnerRoyalClean>> _partnerships({
    bool ads = false,
  }) async* {
    await firebaseInitialization;
    yield* PartnershipContentRoyalClean.watch(ads: ads);
  }

  Widget _admin(WidgetBuilder builder, {Widget? pendingBackground}) =>
      AdminRouteGuardRoyalClean(
        pendingBackground: pendingBackground,
        firebaseInitialization: firebaseInitialization,
        builder: (context) => BiometricGateRoyalClean(builder: builder),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: royalNotificationNavigator,
      title: 'Royal Clean',
      navigatorObservers: [TouchNavigationObserverRoyalClean()],
      debugShowCheckedModeBanner: false,
      theme: AppThemeRoyalClean.theme,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppThemeRoyalClean.systemUiStyle,
        child: kIsWeb && WebConfigurationRoyalClean.visualPreview
            ? Column(
                children: [
                  const Material(
                    color: Color(0xFF092F43),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Prévia visual em validação. Serviços online indisponíveis.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: child!),
                ],
              )
            : child!,
      ),
      initialRoute: AppRoutesRoyalClean.splash,
      routes: {
        '/notifications': (_) =>
            const Scaffold(body: NotificationsPanelRoyalClean()),
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
        '/intercom': (_) => _admin((_) => const IntercomPageRoyalClean()),
        '/bling': (_) => _admin((_) => const BlingIntegrationPageRoyalClean()),
        '/bling-data': (_) => _admin((_) => const BlingDataPageRoyalClean()),
        AppRoutesRoyalClean.home: (_) => _admin(
          (_) => const HomePageRoyalClean(),
          pendingBackground: const HomePendingBackgroundRoyalClean(),
        ),
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
