import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/widgets.dart';
import 'account_access_royal_clean.dart';
import 'bling_sync_events_royal_clean.dart';

typedef ActiveContactsLoader =
    Future<Map<String, dynamic>> Function(Map<String, dynamic>);

/// Publishes a complete generation atomically. Personal data remains in memory,
/// scoped to the verified administrator and discarded when that access changes.
class ActiveContactsCacheRoyalClean extends ChangeNotifier {
  final ActiveContactsLoader load;
  final DateTime Function() now;
  final String kind;
  ActiveContactsCacheRoyalClean({
    required this.load,
    DateTime Function()? now,
    this.kind = 'activeContacts',
  }) : now = now ?? DateTime.now;
  String? _owner;
  int _generation = 0;
  Future<void>? _pending;
  List<Map<String, dynamic>>? _items;
  DateTime? _loadedAt;
  String? checkedAt, catalogRun;
  Object? error;
  bool get busy => _pending != null;
  bool get hasData => _items != null;
  bool get stale =>
      _loadedAt == null ||
      now().difference(_loadedAt!) >= const Duration(hours: 1);
  void setOwner(String? owner) {
    if (owner == _owner) return;
    _owner = owner;
    _generation++;
    _pending = null;
    _items = null;
    _loadedAt = null;
    checkedAt = catalogRun = null;
    error = null;
    notifyListeners();
  }

  List<Map<String, dynamic>> rows(String role) =>
      (_items ?? const <Map<String, dynamic>>[])
          .where(
            (r) =>
                role == 'all' ||
                (role == 'unclassified'
                    ? (r['roles'] as List? ?? []).isEmpty
                    : (r['roles'] as List? ?? []).contains(role)),
          )
          .toList();
  Future<void> refresh({bool force = false}) {
    if (_owner == null) return Future<void>.value();
    if (_pending != null) return _pending!;
    if (!force && !stale) return Future<void>.value();
    final generation = _generation;
    error = null;
    final task = _read(generation);
    _pending = task;
    notifyListeners();
    return task;
  }

  Future<void> _read(int generation) async {
    try {
      final rows = <Map<String, dynamic>>[];
      String? run, checked;
      int? total;
      for (var page = 1; ; page++) {
        final data = await Future.sync(
          () => load({
            'kind': kind,
            if (kind == 'activeContacts') 'contactRole': 'all',
            'page': page,
            if (run != null) 'catalogRun': run,
          }),
        );
        if (generation != _generation) return;
        if (page > 1 && data['catalogRun'] != run) {
          throw StateError('A base mudou durante a consulta.');
        }
        run = data['catalogRun'] as String?;
        checked = data['checkedAt'] as String?;
        total ??= (data['total'] as num).toInt();
        rows.addAll(
          (data['items'] as List).map(
            (r) => Map<String, dynamic>.from(r as Map),
          ),
        );
        if (data['hasMore'] != true) break;
        if (page >= 10000 || (data['items'] as List).isEmpty) {
          throw StateError('Lista incompleta.');
        }
      }
      if (rows.length != total ||
          rows.map((r) => r['id']).toSet().length != rows.length) {
        throw StateError('Lista incompleta.');
      }
      _items = rows;
      _loadedAt = now();
      checkedAt = checked;
      catalogRun = run;
    } catch (e) {
      if (generation == _generation) error = e;
    } finally {
      if (generation == _generation) {
        _pending = null;
        notifyListeners();
      }
    }
  }
}

class ActiveContactsSessionRoyalClean with WidgetsBindingObserver {
  static final instance = ActiveContactsSessionRoyalClean();
  final cache = ActiveContactsCacheRoyalClean(
    load: (query) async {
      final response =
          await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
              .httpsCallable(
                'blingReadData',
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 55),
                ),
              )
              .call(query);
      return Map<String, dynamic>.from(response.data as Map);
    },
  );
  bool _started = false, _foreground = true;
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    AccountAccessRoyalClean.instance.addListener(_access);
    blingSyncRevisionRoyalClean.addListener(_synced);
    Timer.periodic(const Duration(hours: 1), (_) {
      if (_foreground) unawaited(cache.refresh(force: true));
    });
    _access();
  }

  void _access() {
    final state = AccountAccessRoyalClean.instance.value;
    cache.setOwner(
      state.status == AccountAccessStatus.admin ? state.identity?.uid : null,
    );
    if (state.status == AccountAccessStatus.admin) unawaited(cache.refresh());
  }

  void _synced() {
    if (_foreground) unawaited(cache.refresh(force: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(cache.refresh());
  }
}
