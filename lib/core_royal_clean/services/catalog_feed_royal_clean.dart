import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class CatalogFeedRoyalClean {
  static Stream<List<Map<String, dynamic>>> published() => _watch(true);
  static Stream<List<Map<String, dynamic>>> recent() =>
      _watch(true).map(latestTen);

  static Stream<List<Map<String, dynamic>>> _watch(bool publishedOnly) {
    if (Firebase.apps.isEmpty) return Stream.value([]);
    final collection = FirebaseFirestore.instance.collection('products');
    final query = publishedOnly
        ? collection.where('published', isEqualTo: true)
        : collection.where('royalCatalog', isEqualTo: true);
    return query
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((doc) => doc.data()['royalCatalog'] == true)
              .map((doc) => {...doc.data(), 'id': doc.id})
              .toList(),
        )
        .handleError((Object error) {
          /* Keep the last successful view. */
        });
  }

  static List<Map<String, dynamic>> latestTen(List<Map<String, dynamic>> rows) {
    DateTime date(dynamic value) => value is Timestamp
        ? value.toDate()
        : DateTime.tryParse('$value') ?? DateTime(1970);
    final sorted = rows.where((row) => row['archived'] != true).toList()
      ..sort((a, b) {
        final order = date(b['updatedAt']).compareTo(date(a['updatedAt']));
        return order != 0 ? order : '${a['id']}'.compareTo('${b['id']}');
      });
    final seen = <String>{};
    return sorted
        .where((row) => seen.add('${row['productId'] ?? row['id']}'))
        .take(10)
        .toList();
  }
}
