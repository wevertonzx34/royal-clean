import '../constants/layout_defaults_royal_clean.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'account_access_royal_clean.dart';

/// Admin-local layout approvals. Stable IDs are also used by the source defaults.
class LayoutApprovalRoyalClean {
  final double dx, dy, scale;
  const LayoutApprovalRoyalClean({this.dx = 0, this.dy = 0, this.scale = 1});
  bool get original => dx == 0 && dy == 0 && scale == 1;
  Map<String, double> toJson() => {'dx': dx, 'dy': dy, 'scale': scale};
  static LayoutApprovalRoyalClean? parse(dynamic value) {
    if (value is! Map) return null;
    final x = value['dx'], y = value['dy'], s = value['scale'];
    if (x is! num ||
        y is! num ||
        s is! num ||
        !x.isFinite ||
        !y.isFinite ||
        !s.isFinite) {
      return null;
    }
    return LayoutApprovalRoyalClean(
      dx: x.toDouble().clamp(-1, 1),
      dy: y.toDouble().clamp(-1, 1),
      scale: s.toDouble().clamp(.5, 2.5),
    );
  }
}

class LayoutApprovalsRoyalClean extends ChangeNotifier {
  static final instance = LayoutApprovalsRoyalClean();
  final _access = AccountAccessRoyalClean.instance;
  final Map<String, LayoutApprovalRoyalClean> _values = {};
  String? _uid;
  int _generation = 0;
  bool _started = false;
  bool get authorized =>
      _uid != null &&
      _access.value.status == AccountAccessStatus.admin &&
      _access.value.identity?.uid == _uid;
  void start() {
    if (_started) return;
    _started = true;
    _access.addListener(_accountChanged);
    _accountChanged();
  }

  void _accountChanged() {
    final next = _access.value.status == AccountAccessStatus.admin
        ? _access.value.identity?.uid
        : null;
    if (next == _uid) return;
    _uid = next;
    _values.clear();
    final generation = ++_generation;
    notifyListeners();
    if (next != null) _load(next, generation);
  }

  Future<void> _load(String uid, int generation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('layout_approvals.v1.$uid');
      if (raw == null || generation != _generation) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      data.forEach((id, value) {
        final record = LayoutApprovalRoyalClean.parse(value);
        if (record != null) _values.putIfAbsent(id, () => record);
      });
      notifyListeners();
    } catch (_) {
      /* Corrupt local data cannot block the app. */
    }
  }

  LayoutApprovalRoyalClean get(String id) =>
      (authorized ? _values[id] : null) ??
      LayoutApprovalRoyalClean.parse(layoutSourceDefaultsRoyalClean[id]) ??
      const LayoutApprovalRoyalClean();
  Future<void> save(String id, LayoutApprovalRoyalClean value) async {
    final uid = _uid;
    if (!authorized) throw StateError('Admin required');
    final prefs = await SharedPreferences.getInstance();
    if (!authorized || uid != _uid) throw StateError('Session changed');
    final next = {..._values, id: value};
    if (!await prefs.setString(
      'layout_approvals.v1.$uid',
      jsonEncode(next.map((k, v) => MapEntry(k, v.toJson()))),
    )) {
      throw StateError('Save failed');
    }
    if (!authorized || uid != _uid) throw StateError('Session changed');
    _values[id] = value;
    notifyListeners();
  }

  String export() => jsonEncode({
    'version': 1,
    'coordinateSpace': 'viewportDelta',
    'elements': _values.map((k, v) => MapEntry(k, v.toJson())),
  });
}
