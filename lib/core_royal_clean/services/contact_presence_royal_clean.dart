import 'dart:async';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Foreground heartbeat; signing in alone never means a person is online.
class ContactPresenceRoyalClean with WidgetsBindingObserver {
  ContactPresenceRoyalClean._();
  static final instance = ContactPresenceRoyalClean._();
  final _session = List.generate(
    24,
    (_) => Random.secure().nextInt(16).toRadixString(16),
  ).join();
  Timer? _timer;
  bool _started = false, _foreground = true, _sending = false;
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    FirebaseAuth.instance.userChanges().listen((_) => _restart());
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    if (FirebaseAuth.instance.currentUser == null) return;
    unawaited(_send());
    if (_foreground) {
      _timer = Timer.periodic(
        const Duration(seconds: 60),
        (_) => unawaited(_send()),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _restart();
  }

  Future<void> _send() async {
    if (_sending || FirebaseAuth.instance.currentUser?.emailVerified != true) {
      return;
    }
    _sending = true;
    try {
      await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
          .httpsCallable('royalContactPresence')
          .call({'session': _session, 'foreground': _foreground});
    } catch (_) {
      // Offline or denied heartbeats expire server-side. Never log credentials.
    } finally {
      _sending = false;
    }
  }
}
