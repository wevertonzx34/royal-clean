import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/office_room_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/shared/alpha_hit_region_royal_clean.dart';

void main() {
  setUpAll(() async {
    for (final name in [
      'royal-papper',
      'royal-pedidos',
      'royal-receita',
      'balao-di',
      'balao-es',
      'balaozin-es',
    ]) {
      await AlphaHitMaskRoyalClean.load(
        'assets/preview/royal-store/$name.webp',
      );
    }
  });
  testWidgets(
    'Office covers viewport and paper opens the invoice action once',
    (tester) async {
      var opened = 0, production = 0, orders = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              disableAnimations: true,
            ),
            child: OfficeRoomPageRoyalClean(
              onOpenProduction: () async => production++,
              onOpenOrders: () async => orders++,
              onOpenNfe: () async {
                opened++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      final background = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is ResizeImage &&
            (w.image as ResizeImage).imageProvider is AssetImage &&
            ((w.image as ResizeImage).imageProvider as AssetImage).assetName
                .endsWith('royal-sala.webp'),
      );
      expect(background, findsOneWidget);
      expect(tester.widget<Image>(background).fit, BoxFit.cover);
      expect(tester.getSize(background), tester.getSize(find.byType(Scaffold)));
      await tester.tap(find.byKey(const ValueKey('royal-papper-shortcut')));
      await tester.pump(const Duration(seconds: 2));
      expect(opened, 1);
      expect(
        find.byKey(const ValueKey('royal-producao-shortcut')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('office-royal-receita-shortcut')),
      );
      await tester.pumpAndSettle();
      expect(production, 1);
      await tester.tap(
        find.byKey(const ValueKey('office-royal-pedidos-shortcut')),
      );
      await tester.pumpAndSettle();
      expect(orders, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
