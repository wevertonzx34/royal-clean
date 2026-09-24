import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class BiometricCancelledRoyalClean implements Exception {
  const BiometricCancelledRoyalClean();
}

/// Device-local unlock of an existing Firebase session, never a server role.
/// Stores only the opted-in UID in protected storage, not passwords or copies of tokens.
class BiometricAccessRoyalClean extends ChangeNotifier {
  BiometricAccessRoyalClean({
    required this.currentUid,
    required this.readEnrollment,
    required this.writeEnrollment,
    required this.checkAvailable,
    required this.authenticate,
    required this.validateSession,
  });

  static const _key = 'royal_clean.biometric_uid';
  static const _storage = FlutterSecureStorage();
  static final _local = LocalAuthentication();
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  static final instance = BiometricAccessRoyalClean(
    currentUid: () => FirebaseAuth.instance.currentUser?.uid,
    readEnrollment: () async => _supported ? _storage.read(key: _key) : null,
    writeEnrollment: (uid) async {
      if (!_supported) return;
      if (uid == null) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: uid);
      }
    },
    checkAvailable: () async => _supported && await _local.isDeviceSupported(),
    authenticate: () => _local.authenticate(
      localizedReason:
          'Use a digital, o PIN, o padrão ou a senha deste aparelho para acessar a Royal Clean.',
      authMessages: const [
        AndroidAuthMessages(
          signInTitle: 'Acessar Royal Clean',
          signInHint: 'Confirme sua identidade',
          cancelButton: 'Cancelar',
        ),
      ],
      biometricOnly: false,
      persistAcrossBackgrounding: true,
    ),
    validateSession: () async {
      await FirebaseAuth.instance.currentUser?.reload();
      if (FirebaseAuth.instance.currentUser == null) {
        throw StateError('Sessão encerrada');
      }
      await FirebaseAuth.instance.currentUser!.getIdToken(true);
    },
  );

  final String? Function() currentUid;
  final Future<String?> Function() readEnrollment;
  final Future<void> Function(String?) writeEnrollment;
  final Future<bool> Function() checkAvailable;
  final Future<bool> Function() authenticate;
  final Future<void> Function() validateSession;
  String? _enrolledUid;
  bool _locked = false, _authenticating = false;
  bool get locked => _locked;
  bool get enabled => currentUid() != null && currentUid() == _enrolledUid;

  /// True means the retained Firebase session needs a biometric/password unlock.
  Future<bool> restore() async {
    _enrolledUid = await readEnrollment();
    _locked = enabled;
    notifyListeners();
    return _locked;
  }

  void credentialsAccepted() {
    _locked = false;
    notifyListeners();
  }

  Future<bool> enable({bool confirmDevice = true}) async {
    final uid = currentUid();
    if (uid == null || _authenticating || !await checkAvailable()) return false;
    _authenticating = true;
    try {
      // A successful account login already authenticates enrollment consent.
      // The native challenge is required on the next cold-start unlock.
      if ((confirmDevice && !await authenticate()) || currentUid() != uid) {
        return false;
      }
      await writeEnrollment(uid);
      if (currentUid() != uid) {
        await writeEnrollment(null);
        return false;
      }
      _enrolledUid = uid;
      _locked = false;
      notifyListeners();
      return true;
    } finally {
      _authenticating = false;
    }
  }

  Future<bool> unlock() async {
    final uid = currentUid();
    if (!enabled || uid == null || _authenticating) return false;
    _authenticating = true;
    try {
      if (!await checkAvailable() ||
          !await authenticate() ||
          currentUid() != uid) {
        return false;
      }
      await validateSession();
      if (currentUid() != uid) return false;
      _locked = false;
      notifyListeners();
      return true;
    } finally {
      _authenticating = false;
    }
  }

  Future<void> disable() async {
    try {
      await writeEnrollment(null);
    } finally {
      _enrolledUid = null;
      _locked = false;
      notifyListeners();
    }
  }

  Stream<bool> visibleSession(Stream<bool> auth) =>
      Stream<bool>.multi((controller) {
        var signedIn = false;
        // Public UI may show "Perfil" for a retained session. Private widgets
        // still require unlock; the label itself grants no access.
        void publish() => controller.add(signedIn);
        addListener(publish);
        final subscription = auth.listen((value) {
          signedIn = value;
          publish();
        }, onError: controller.addError);
        controller.onCancel = () async {
          removeListener(publish);
          await subscription.cancel();
        };
      });
}
