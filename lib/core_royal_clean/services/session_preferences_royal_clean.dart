import 'package:shared_preferences/shared_preferences.dart';

/// Stores only a user preference. Credentials remain managed by Firebase/Auth.
class SessionPreferencesRoyalClean {
  SessionPreferencesRoyalClean({SharedPreferencesAsync? storage})
    : _storage = storage ?? SharedPreferencesAsync();

  static final instance = SessionPreferencesRoyalClean();
  static const rememberKey = 'royal_clean.remember_session';
  final SharedPreferencesAsync _storage;

  Future<bool> read() async => await _storage.getBool(rememberKey) ?? true;

  Future<void> save(bool remember) => _storage.setBool(rememberKey, remember);

  /// Called once on startup, before any route can observe the Firebase session.
  /// Native Firebase persists auth itself; a temporary session is cleared here.
  /// Do not sign out on pause: OAuth and email verification leave the app briefly.
  Future<void> restore({
    required Future<void> Function() signOut,
    Future<void> Function(bool)? configureWebPersistence,
  }) async {
    final remember = await read();
    if (!remember) await signOut();
    await configureWebPersistence?.call(remember);
  }
}
