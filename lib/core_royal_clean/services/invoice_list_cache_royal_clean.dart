import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/widgets.dart';
import 'account_access_royal_clean.dart';
import 'active_contacts_cache_royal_clean.dart';
import 'bling_sync_events_royal_clean.dart';

/// Uses the server's exact half-open calendar interval and fiscal membership.
List<Map<String, dynamic>> invoicesInBarRoyalClean(
  List<Map<String, dynamic>> rows, {
  required String start,
  String? endExclusive,
  required String metric,
}) {
  return rows.where((row) {
    final date = (row['date'] as String? ?? '').split(RegExp('[ T]')).first;
    final parsed = DateTime.tryParse(date);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        parsed == null ||
        parsed.toIso8601String().substring(0, 10) != date) {
      return false;
    }
    return date.compareTo(start) >= 0 &&
        (endExclusive == null || date.compareTo(endExclusive) < 0) &&
        (row['metricKeys'] as List? ?? []).contains(metric);
  }).toList();
}

String invoiceDateTimeRoyalClean(String raw) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}:\d{2}(?::\d{2})?))?',
  ).firstMatch(raw);
  if (match == null) return 'Data e hora não informadas';
  return '${match[3]}/${match[2]}/${match[1]} • ${match[4] ?? 'horário não informado'}';
}

class InvoiceListSessionRoyalClean with WidgetsBindingObserver {
  static final instance = InvoiceListSessionRoyalClean();
  final cache = ActiveContactsCacheRoyalClean(
    kind: 'invoiceCatalog',
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
