import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/stock_data_shortcut_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/image_action_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/stock_lighting_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/stock_functions_page_royal_clean.dart';

void main() {
  testWidgets(
    'Stock data shortcut preserves home dimensions and opens overview',
    (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: StockDataShortcutRoyalClean(
                  onOpen: () async {
                    opens++;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final target = find.byKey(const ValueKey('stock-data-shortcut'));
      expect(tester.getSize(target), const Size(100, 100));
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Immediate feedback runs once before the 120 ms animation ends', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ImageActionRoyalClean(
            activateBeforeAnimation: true,
            duration: const Duration(milliseconds: 120),
            onActivate: () {
              calls++;
            },
            builder: (_, flash) => const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ImageActionRoyalClean));
    expect(calls, 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
  testWidgets('Royal 3D tap flashes windows; hold only opens property', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(432, 912));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var visits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StockBackgroundRoyalClean(
            showOffice: true,
            onOpenProperty: () async {
              visits++;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final target = find.byKey(const ValueKey('royal-3d-shortcut'));
    final trigger = tester
        .widget<StockLightingRoyalClean>(find.byType(StockLightingRoyalClean))
        .trigger;
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(trigger.value, 1);
    expect(visits, 0);
    await tester.longPress(target);
    await tester.pumpAndSettle();
    expect(visits, 1);
    expect(trigger.value, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Stock background covers mobile viewport with accessible standard header',
    (tester) async {
      for (final size in [const Size(320, 640), const Size(800, 400)]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: StockFunctionsPageRoyalClean(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Funções de estoque'), findsOneWidget);
        final background = find.byType(Image).first;
        final rendered = tester.getRect(background);
        expect(rendered.left, lessThanOrEqualTo(0));
        expect(rendered.top, lessThanOrEqualTo(0));
        expect(rendered.right, greaterThanOrEqualTo(size.width));
        expect(rendered.bottom, greaterThanOrEqualTo(size.height));
        expect(
          tester.widget<FittedBox>(find.byType(FittedBox).first).fit,
          BoxFit.cover,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}
