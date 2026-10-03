import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../firebase_options.dart';
import 'account_access_royal_clean.dart';

final adminNotificationOpenedRoyalClean = ValueNotifier<int>(0);
final _notifications = FlutterLocalNotificationsPlugin();
int adminNotificationIdRoyalClean(String event) => event.codeUnits.fold<int>(
  0,
  (hash, unit) => (hash * 31 + unit) & 0x7fffffff,
);
bool _localReady = false;
Future<void> _initializeLocal() async {
  if (_localReady) return;
  await _notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('royal_dados'),
    ),
    onDidReceiveNotificationResponse: (_) =>
        adminNotificationOpenedRoyalClean.value++,
  );
  _localReady = true;
}

Future<void> clearReadAdminNotificationsRoyalClean(Iterable<String> ids) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _initializeLocal();
    for (final id in ids) {
      await _notifications.cancel(id: adminNotificationIdRoyalClean(id));
    }
  } catch (_) {
    // Reading remains available if the system notification service is unavailable.
  }
}

@pragma('vm:entry-point')
Future<void> receiveAdminPushRoyalClean(RemoteMessage message) async {
  if (kDebugMode) debugPrint('RoyalClean admin push received');
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
    final uid = message.data['uid'] as String?,
        event = message.data['eventId'] as String?;
    if (message.data['type'] != 'bling' ||
        uid == null ||
        event == null ||
        !RegExp(
          r'^(products|contacts|invoices|proposals|care)_[a-zA-Z0-9_-]+$',
        ).hasMatch(event)) {
      return;
    }
    final auth = FirebaseAuth.instance;
    if (auth.currentUser?.uid != uid) return;
    await auth.currentUser!.reload();
    if (auth.currentUser?.uid != uid ||
        auth.currentUser?.emailVerified != true) {
      return;
    }
    final db = FirebaseFirestore.instance;
    final admin =
        (await db
                .doc('admin/$uid')
                .get(const GetOptions(source: Source.server)))
            .data();
    if (admin?['ativo'] != true ||
        admin?['eAdministrador'] != true ||
        (admin?['email'] as String?)?.toLowerCase() !=
            auth.currentUser?.email?.toLowerCase()) {
      return;
    }
    final data =
        (await db
                .doc('admin_bling_events/$event')
                .get(const GetOptions(source: Source.server)))
            .data();
    if (data == null ||
        auth.currentUser?.uid != uid ||
        !(data['expiresAt'] as Timestamp).toDate().isAfter(DateTime.now())) {
      return;
    }
    await _initializeLocal();
    // Stable id replaces a retried push instead of duplicating it in the tray.
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    if (preferences.getStringList('intercom.seen.$uid')?.contains(event) ==
        true) {
      return;
    }
    final id = adminNotificationIdRoyalClean(event);
    await _notifications.show(
      id: id,
      title: data['title'] as String,
      body: data['body'] as String,
      payload: event,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'bling_admin',
          'Bling • Administração',
          channelDescription: 'Novos produtos, contatos e notas de saída',
          icon: 'royal_dados',
          largeIcon: const DrawableResourceAndroidBitmap('royal_dados'),
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.private,
          onlyAlertOnce: true,
          styleInformation: BigTextStyleInformation(data['body'] as String),
        ),
      ),
    );
  } catch (error, stack) {
    if (kDebugMode) {
      debugPrint(
        'RoyalClean admin push unavailable: ${error is FirebaseException ? error.code : error.runtimeType}',
      );
      debugPrintStack(stackTrace: stack, maxFrames: 6);
    }
    // Fail closed: offline/expired sessions must never display cached private content.
    // The durable in-app feed remains available after the next authorized connection.
  }
}

class AdminPushRoyalClean {
  static final instance = AdminPushRoyalClean();
  String? _uid;
  bool _started = false;
  bool _handledLaunch = false;
  int _generation = 0;
  Timer? _retry;
  void start() {
    if (_started || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _started = true;
    FirebaseMessaging.onBackgroundMessage(receiveAdminPushRoyalClean);
    FirebaseMessaging.onMessage.listen(receiveAdminPushRoyalClean);
    FirebaseMessaging.instance.onTokenRefresh.listen(
      (_) => unawaited(_register()),
    );
    AccountAccessRoyalClean.instance.addListener(_changed);
    _changed();
  }

  void _changed() {
    final state = AccountAccessRoyalClean.instance.value;
    // Revalidation/connectivity is not logout. Keep the token while the same
    // identity is checked; each received event still requires fresh server access.
    if (_uid != null &&
        state.identity?.uid == _uid &&
        (state.status == AccountAccessStatus.checking ||
            state.status == AccountAccessStatus.unavailable)) {
      return;
    }
    final uid = state.status == AccountAccessStatus.admin
        ? state.identity?.uid
        : null;
    if (uid == _uid) return;
    _uid = uid;
    _generation++;
    _retry?.cancel();
    if (uid == null) {
      unawaited(_clear());
    } else {
      unawaited(_register());
    }
  }

  Future<void> _clear() async {
    try {
      await _initializeLocal();
      await _notifications.cancelAll();
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _register() async {
    final uid = _uid, generation = _generation;
    if (uid == null) return;
    try {
      await _initializeLocal();
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || _uid != uid || generation != _generation) return;
      await FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      ).httpsCallable('registerAdminNotifications').call({'token': token});
      final launch = await _notifications.getNotificationAppLaunchDetails();
      if (!_handledLaunch && launch?.didNotificationLaunchApp == true) {
        _handledLaunch = true;
        adminNotificationOpenedRoyalClean.value++;
      }
    } catch (_) {
      if (_uid == uid && generation == _generation) {
        _retry = Timer(
          const Duration(minutes: 1),
          () => unawaited(_register()),
        );
      }
    }
  }
}
