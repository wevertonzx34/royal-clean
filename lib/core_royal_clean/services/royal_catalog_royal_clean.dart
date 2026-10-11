import 'dart:convert';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoyalCatalogRoyalClean {
  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
  static Future<Map<String, dynamic>> call(Map<String, dynamic> input) async {
    final result =
        await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
            .httpsCallable(
              'royalCatalog',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 60),
              ),
            )
            .call(input);
    return Map<String, dynamic>.from(result.data as Map);
  }

  static String _key(String id) =>
      'royal.catalog.draft.v1.${FirebaseAuth.instance.currentUser?.uid}.$id';
  static Future<void> draft(String id, Map<String, dynamic> value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final key = 'royal.catalog.draft.v1.$uid.$id';
    await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(value),
    );
    try {
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      await call({'action': 'draft', 'id': id, 'draft': value});
    } catch (_) {
      /* Local draft remains available offline. */
    }
  }

  static Future<List<Map<String, dynamic>>> localDrafts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    final prefix = 'royal.catalog.draft.v1.$uid.';
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys().where((k) => k.startsWith(prefix)).map((key) {
      final value = Map<String, dynamic>.from(
        jsonDecode(prefs.getString(key)!) as Map,
      );
      return {...value, 'id': key.substring(prefix.length)};
    }).toList();
  }

  static Future<Map<String, dynamic>?> readDraft(String id) async {
    final value = (await SharedPreferences.getInstance()).getString(_key(id));
    return value == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  static Future<void> clearDraft(String id) async =>
      (await SharedPreferences.getInstance()).remove(_key(id));
}

int catalogCentsRoyalClean(String value) =>
    (double.parse(value.replaceAll(',', '.')) * 100).round();
String catalogMoneyRoyalClean(dynamic value) => value is num
    ? 'R\$ ${(value / 100).toStringAsFixed(2).replaceAll('.', ',')}'
    : 'Sob orçamento';
