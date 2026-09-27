import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/widgets.dart';
import 'account_access_royal_clean.dart';
import 'active_contacts_cache_royal_clean.dart';
import 'bling_sync_events_royal_clean.dart';

class ProductListSessionRoyalClean with WidgetsBindingObserver {
  static final instance = ProductListSessionRoyalClean();
  final cache = ActiveContactsCacheRoyalClean(
    kind: 'productCatalog',
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
