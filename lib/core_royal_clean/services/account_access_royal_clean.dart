import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'admin_access_royal_clean.dart';

enum AccountAccessStatus {
  checking,
  signedOut,
  admin,
  profile,
  registration,
  denied,
  unavailable,
}

class AccountIdentity {
  final String uid;
  final String? email;
  final bool verified;
  const AccountIdentity(this.uid, this.email, this.verified);
  @override
  bool operator ==(Object other) =>
      other is AccountIdentity &&
      uid == other.uid &&
      email == other.email &&
      verified == other.verified;
  @override
  int get hashCode => Object.hash(uid, email, verified);
}

class AccountRecord {
  final Map<String, dynamic>? data;
  final bool confirmed;
  const AccountRecord(this.data, {required this.confirmed});
}

class AccountAccessState {
  final AccountAccessStatus status;
  final AccountIdentity? identity;
  final Map<String, dynamic>? profile;
  const AccountAccessState(this.status, {this.identity, this.profile});
}

/// One live, server-confirmed permission subscription per signed-in identity.
/// No permissions are persisted on disk and no cached record grants access.
class AccountAccessRoyalClean extends ValueNotifier<AccountAccessState> {
  final Stream<AccountIdentity?> Function() identities;
  final Stream<AccountRecord> Function(String collection, String uid) records;
  AccountAccessRoyalClean({required this.identities, required this.records})
    : super(const AccountAccessState(AccountAccessStatus.checking));

  static final instance = AccountAccessRoyalClean(
    identities: () => FirebaseAuth.instance.userChanges().map(
      (user) => user == null
          ? null
          : AccountIdentity(user.uid, user.email, user.emailVerified),
    ),
    records: (collection, uid) => FirebaseFirestore.instance
        .doc('$collection/$uid')
        .snapshots(includeMetadataChanges: true)
        .map(
          (doc) => AccountRecord(
            doc.data(),
            confirmed:
                !doc.metadata.isFromCache && !doc.metadata.hasPendingWrites,
          ),
        ),
  );

  StreamSubscription<AccountIdentity?>? _auth;
  StreamSubscription<AccountRecord>? _admin;
  StreamSubscription<AccountRecord>? _profile;
  AccountIdentity? _identity;
  AccountRecord? _adminRecord;
  AccountRecord? _profileRecord;
  bool _adminFailed = false, _profileFailed = false;
  int _generation = 0;
  bool get started => _auth != null;

  void start() {
    if (started) return;
    _auth = identities().listen(
      _onIdentity,
      onError: (Object error) {
        _generation++;
        _identity = null;
        unawaited(_admin?.cancel());
        unawaited(_profile?.cancel());
        _admin = _profile = null;
        value = const AccountAccessState(AccountAccessStatus.unavailable);
      },
    );
  }

  void _onIdentity(AccountIdentity? identity, {bool refresh = false}) {
    if (!refresh && identity != null && identity == _identity) return;
    final generation = ++_generation;
    unawaited(_admin?.cancel());
    unawaited(_profile?.cancel());
    _admin = _profile = null;
    _identity = identity;
    _adminRecord = _profileRecord = null;
    _adminFailed = _profileFailed = false;
    _emit(
      identity == null
          ? AccountAccessStatus.signedOut
          : AccountAccessStatus.checking,
    );
    if (identity == null) return;
    _admin = records('admin', identity.uid).listen(
      (record) {
        if (generation != _generation) return;
        _adminRecord = record;
        _adminFailed = false;
        if (record.confirmed &&
            record.data == null &&
            identity.verified &&
            _profile == null) {
          _profile = records('users', identity.uid).listen(
            (profile) {
              if (generation != _generation) return;
              _profileRecord = profile;
              _profileFailed = false;
              _resolve();
            },
            onError: (Object error) {
              if (generation == _generation) {
                _profileRecord = null;
                _profileFailed = true;
                _emit(AccountAccessStatus.unavailable);
              }
            },
          );
        }
        _resolve();
      },
      onError: (Object error) {
        if (generation == _generation) {
          _adminRecord = null;
          _adminFailed = true;
          _emit(AccountAccessStatus.unavailable);
        }
      },
    );
  }

  void _resolve() {
    final admin = _adminRecord;
    if (_adminFailed || (admin?.data == null && _profileFailed)) {
      _emit(AccountAccessStatus.unavailable);
    } else if (admin == null || !admin.confirmed) {
      _emit(AccountAccessStatus.checking);
    } else if (admin.data != null) {
      _emit(
        isActiveAdminRoyalClean(admin.data, _identity?.email)
            ? AccountAccessStatus.admin
            : AccountAccessStatus.denied,
      );
    } else if (!_identity!.verified) {
      _emit(AccountAccessStatus.registration);
    } else if (_profileRecord == null || !_profileRecord!.confirmed) {
      _emit(AccountAccessStatus.checking);
    } else if (_profileRecord!.data == null) {
      _emit(AccountAccessStatus.registration);
    } else {
      final profile = _profileRecord!.data!;
      _emit(
        profile['active'] == true &&
                const {
                  'master',
                  'consumer',
                  'collaborator',
                  'promoter',
                }.contains(profile['role'])
            ? AccountAccessStatus.profile
            : AccountAccessStatus.denied,
        profile: profile,
      );
    }
  }

  void _emit(AccountAccessStatus status, {Map<String, dynamic>? profile}) {
    value = AccountAccessState(status, identity: _identity, profile: profile);
  }

  Future<void> ready() async {
    start();
    if (value.status == AccountAccessStatus.unavailable && _identity != null) {
      _onIdentity(_identity, refresh: true);
    }
    final completed = Completer<void>();
    void check() {
      if (value.status != AccountAccessStatus.checking &&
          !completed.isCompleted) {
        completed.complete();
      }
    }

    addListener(check);
    check();
    try {
      await completed.future.timeout(const Duration(seconds: 12));
      if (value.status == AccountAccessStatus.unavailable ||
          value.status == AccountAccessStatus.signedOut) {
        throw StateError('Session unavailable');
      }
    } finally {
      removeListener(check);
    }
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_auth?.cancel());
    unawaited(_admin?.cancel());
    unawaited(_profile?.cancel());
    super.dispose();
  }
}
