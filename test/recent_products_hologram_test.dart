import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/core_royal_clean/services/catalog_feed_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/recent_products_hologram_royal_clean.dart';

Map<String, dynamic> product(int index) => {
  'id': '$index',
  'productId': '$index',
  'title': 'Produto $index',
  'imageUrl': 'https://example.test/$index.jpg',
  'updatedAt': DateTime(
    2026,
    1,
    1,
  ).add(Duration(days: index)).toIso8601String(),
};

void main() {
  test(
    'Latest ten are newest first and deduplicate box/unit presentations',
    () {
      final rows = CatalogFeedRoyalClean.latestTen([
        for (var i = 0; i < 12; i++) product(i),
        {...product(11), 'id': '11-box'},
        {...product(20), 'archived': true},
      ]);
      expect(rows.length, 10);
      expect(rows.first['productId'], '11');
      expect(rows.last['productId'], '2');
    },
  );
  testWidgets(
    'Empty feed keeps default; populated feed rotates by swipe and opens only on tap',
    (tester) async {
      final feed = StreamController<List<Map<String, dynamic>>>();
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: RecentProductsHologramRoyalClean(
                    products: feed.stream,
                    onOpen: () => opens++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      feed.add([]);
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      feed.add([for (var i = 0; i < 12; i++) product(i)]);
      await tester.pumpAndSettle();
      expect(find.text('Produto 11 · 1/10'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      final target = find.byKey(const ValueKey('produtos-royal-gif-shortcut'));
      await tester.tapAt(tester.getTopLeft(target) + const Offset(2, 2));
      expect(opens, 0);
      await tester.drag(find.byType(PageView), const Offset(-180, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        closeTo(1, .01),
      );
      expect(opens, 0);
      feed.add([product(20), product(11)]);
      await tester.pumpAndSettle();
      expect(find.text('Produto 20 · 1/2'), findsOneWidget);
      expect(
        tester.widget<PageView>(find.byType(PageView)).controller!.page,
        0,
      );
      await tester.tapAt(tester.getCenter(target));
      expect(opens, 1);
      feed.add([product(20)]);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => feed.close());
      expect(tester.takeException(), isNull);
    },
  );
}
