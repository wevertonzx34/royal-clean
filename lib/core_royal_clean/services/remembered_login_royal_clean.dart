import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers only the last successfully authenticated email on this device.
/// Password autofill is delegated to the user's operating-system provider.
class RememberedLoginRoyalClean {
  final Future<String?> Function() read;
  final Future<void> Function(String?) write;
  const RememberedLoginRoyalClean({required this.read, required this.write});

  static const _storage = FlutterSecureStorage();
  static const _key = 'royal_clean.remembered_email';
  static final instance = RememberedLoginRoyalClean(
    read: () => _storage.read(key: _key),
    write: (email) => email == null
        ? _storage.delete(key: _key)
        : _storage.write(key: _key, value: email.trim()),
  );
}
