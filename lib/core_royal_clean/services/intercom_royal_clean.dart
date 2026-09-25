import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IntercomMessageRoyalClean {
  final String id, title, body, kind;
  final DateTime publishedAt, expiresAt;
  const IntercomMessageRoyalClean({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.publishedAt,
    required this.expiresAt,
  });
  bool activeAt(DateTime now) => expiresAt.isAfter(now);
  factory IntercomMessageRoyalClean.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return IntercomMessageRoyalClean(
      id: doc.id,
      title: data['title'] as String,
      body: data['body'] as String,
      kind: data['kind'] as String,
      publishedAt: (data['publishedAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
    );
  }
}

/// Public messages only. Personal information and review records are never in this feed.
class IntercomRoyalClean extends ChangeNotifier {
  static final instance = IntercomRoyalClean();
  List<IntercomMessageRoyalClean> messages = [];
  Set<String> _seen = {};
  String _reader = 'visitor';
  bool loading = false;
  String? error;
  StreamSubscription<dynamic>? _feed, _auth;
  Timer? _clock;
  bool _started = false;
  List<IntercomMessageRoyalClean> get active =>
      messages.where((message) => message.activeAt(DateTime.now())).toList();
  bool isUnread(IntercomMessageRoyalClean message) =>
      !_seen.contains(message.id);
  int get unreadCount => active.where(isUnread).length;

  void start() {
    if (_started) return;
    _started = true;
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
    _seen.addAll(ids);
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
