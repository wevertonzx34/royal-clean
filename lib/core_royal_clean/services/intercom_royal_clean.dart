import 'dart:async';
import 'admin_push_royal_clean.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'account_access_royal_clean.dart';
import 'biometric_access_royal_clean.dart';
import 'bling_sync_events_royal_clean.dart';

class IntercomMessageRoyalClean {
  final String id, title, body, kind;
  final DateTime publishedAt, expiresAt;
  final DateTime? occurredAt;
  DateTime get displayDate => occurredAt ?? publishedAt;
  bool isToday(DateTime now) {
    final date = displayDate.toLocal();
    final today = now.toLocal();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  const IntercomMessageRoyalClean({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.publishedAt,
    required this.expiresAt,
    this.occurredAt,
  });
  bool activeAt(DateTime now) => expiresAt.isAfter(now);
  factory IntercomMessageRoyalClean.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return IntercomMessageRoyalClean(
      id: doc.id,
      occurredAt: data['occurredAt'] is Timestamp
          ? (data['occurredAt'] as Timestamp).toDate()
          : DateTime.tryParse('${data['occurredAt'] ?? ''}'),
      title: data['title'] as String,
      body: data['body'] as String,
      kind: data['kind'] as String,
      publishedAt: (data['publishedAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
    );
  }
}

/// Public Interfone and a separately authorized, private admin feed.
class IntercomRoyalClean extends ChangeNotifier {
  static final instance = IntercomRoyalClean();
  List<IntercomMessageRoyalClean> messages = [];
  List<IntercomMessageRoyalClean> _privateMessages = [];
  StreamSubscription<dynamic>? _privateFeed, _sync;
  String? _adminReader;
  int _privateGeneration = 0;
  String? _syncVersion;
  Timer? _privateRetry;
  Set<String> _seen = {};
  String _reader = 'visitor';
  bool loading = false;
  String? error;
  StreamSubscription<dynamic>? _feed, _auth;
  Timer? _clock;
  bool _started = false;
  List<IntercomMessageRoyalClean> get active =>
      [
          ...messages,
          ..._privateMessages,
        ].where((message) => message.activeAt(DateTime.now())).toList()
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  bool isUnread(IntercomMessageRoyalClean message) =>
      !_seen.contains(message.id);
  int get unreadCount => active.where(isUnread).length;

  void start() {
    if (_started) return;
    _started = true;
    AccountAccessRoyalClean.instance.addListener(_adminChanged);
    BiometricAccessRoyalClean.instance.addListener(_adminChanged);
    _adminChanged();
    _auth = FirebaseAuth.instance.authStateChanges().listen((user) async {
      final reader = user?.uid ?? 'visitor';
      _reader = reader;
      _seen = {};
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_reader == reader) {
          _seen = {...?prefs.getStringList('intercom.seen.$reader'), ..._seen};
          notifyListeners();
        }
      } catch (_) {
        /* In-memory read state remains available. */
      }
    });
    _clock = Timer.periodic(
      const Duration(seconds: 30),
      (_) => notifyListeners(),
    );
    reload();
  }

  void _adminChanged({bool force = false}) {
    final access = AccountAccessRoyalClean.instance.value;
    final uid =
        access.status == AccountAccessStatus.admin &&
            !BiometricAccessRoyalClean.instance.locked
        ? access.identity?.uid
        : null;
    if (uid == _adminReader && !force) return;
    final changedIdentity = uid != _adminReader;
    _adminReader = uid;
    _privateRetry?.cancel();
    final generation = ++_privateGeneration;
    unawaited(_privateFeed?.cancel());
    unawaited(_sync?.cancel());
    if (changedIdentity) {
      _privateMessages = [];
      _syncVersion = null;
    }
    notifyListeners();
    if (uid == null) return;
    _privateFeed = FirebaseFirestore.instance
        .collection('admin_bling_events')
        .orderBy('publishedAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (_adminReader != uid ||
                generation != _privateGeneration ||
                snapshot.metadata.isFromCache) {
              return;
            }
            _privateMessages = snapshot.docs
                .map(IntercomMessageRoyalClean.fromDoc)
                .toList();
            notifyListeners();
          },
          onError: (Object failure) {
            if (generation != _privateGeneration) return;
            if (failure is FirebaseException &&
                failure.code == 'permission-denied') {
              _privateMessages = [];
            }
            notifyListeners();
            _privateRetry = Timer(const Duration(seconds: 30), () {
              if (generation != _privateGeneration) return;
              _adminChanged(force: true);
            });
          },
        );
    _sync = FirebaseFirestore.instance
        .collection('admin_bling_sync')
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            if (_adminReader != uid ||
                generation != _privateGeneration ||
                snapshot.metadata.isFromCache) {
              return;
            }
            final parts =
                snapshot.docs
                    .map((doc) => '${doc.id}:${doc.data()['runId']}')
                    .toList()
                  ..sort();
            final version = parts.join('|');
            if (version == _syncVersion) return;
            final previous = (_syncVersion ?? '').split('|').toSet();
            blingChangedGroupsRoyalClean = parts
                .where((part) => !previous.contains(part))
                .map((part) => part.split(':').first)
                .toSet();
            _syncVersion = version;
            if (version.isNotEmpty) blingSyncRevisionRoyalClean.value++;
          },
          onError: (Object _) {
            if (generation != _privateGeneration) return;
            _privateRetry?.cancel();
            _privateRetry = Timer(const Duration(seconds: 15), () {
              if (generation == _privateGeneration) _adminChanged(force: true);
            });
          },
        );
  }

  void reload() {
    if (!_started) return;
    unawaited(_feed?.cancel());
    loading = true;
    error = null;
    notifyListeners();
    _feed = FirebaseFirestore.instance
        .collection('intercom_messages')
        .orderBy('publishedAt', descending: true)
        .limit(200)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) {
            try {
              messages = snapshot.docs
                  .where((doc) => !doc.metadata.hasPendingWrites)
                  .map(IntercomMessageRoyalClean.fromDoc)
                  .toList();
              loading = false;
              error = snapshot.metadata.isFromCache
                  ? 'Sem confirmação do servidor. As mensagens podem estar desatualizadas.'
                  : null;
            } catch (_) {
              loading = false;
              error = 'Não foi possível carregar as mensagens.';
            }
            notifyListeners();
          },
          onError: (Object failure) {
            loading = false;
            error =
                failure is FirebaseException &&
                    failure.code == 'permission-denied'
                ? 'Notificações indisponíveis. As regras do Interfone precisam estar publicadas no Firebase.'
                : 'Não foi possível atualizar as notificações. Verifique a conexão e tente novamente.';
            notifyListeners();
          },
        );
  }

  Future<void> markRead(Iterable<String> ids) async {
    final readIds = ids.toList();
    _seen.addAll(readIds);
    unawaited(clearReadAdminNotificationsRoyalClean(readIds));
    final reader = _reader;
    final saved = _seen.toList();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('intercom.seen.$reader', saved);
    } catch (_) {
      /* Failure to remember reading must not hide messages. */
    }
  }

  static Future<void> publish({
    required String id,
    required String title,
    required String body,
    required String kind,
    required DateTime expiresAt,
  }) async {
    final db = FirebaseFirestore.instance;
    final reference = db.collection('intercom_messages').doc(id);
    // Transactions fail offline; do not claim publication for queued local writes.
    await db.runTransaction((transaction) async {
      final previous = await transaction.get(reference);
      if (previous.exists) {
        return; // A retry of the same submission cannot duplicate it.
      }
      transaction.set(reference, {
        'title': title.trim(),
        'body': body.trim(),
        'kind': kind,
        'publishedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
      });
    });
  }

  @override
  void dispose() {
    _privateRetry?.cancel();
    AccountAccessRoyalClean.instance.removeListener(_adminChanged);
    BiometricAccessRoyalClean.instance.removeListener(_adminChanged);
    unawaited(_privateFeed?.cancel());
    unawaited(_sync?.cancel());
    unawaited(_feed?.cancel());
    unawaited(_auth?.cancel());
    _clock?.cancel();
    super.dispose();
  }
}

String intercomDateRoyalClean(DateTime value) {
  final date = value.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} às ${two(date.hour)}:${two(date.minute)}';
}
