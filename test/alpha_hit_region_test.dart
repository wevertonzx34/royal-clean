import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:royal_clean/core_royal_clean/services/account_access_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/services/layout_approvals_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/shared/alpha_hit_region_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/shared/layout_button_royal_clean.dart';

void main() {
  const names = [
    'royal-papper',
    'royal-pedidos',
    'royal-receita',
    'royal-gaveta',
    'produtos-royal',
  ];
  setUpAll(() async {
    for (final name in names) {
      expect(
        await AlphaHitMaskRoyalClean.load(
          'assets/preview/royal-store/$name.webp',
        ),
        isNotNull,
      );
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AccountAccessRoyalClean.instance.value = const AccountAccessState(
      AccountAccessStatus.admin,
      identity: AccountIdentity('alpha-hit-admin', null, true),
    );
  });
  tearDown(
    () => AccountAccessRoyalClean.instance.value = const AccountAccessState(
      AccountAccessStatus.signedOut,
    ),
  );

  test('Mask rejects transparent pixels and contain letterboxing', () {
    final mask = AlphaHitMaskRoyalClean(
      3,
      3,
      Uint8List.fromList([0, 0, 0, 0, 255, 0, 0, 0, 0]),
    );
    expect(mask.contains(const Offset(100, 50), const Size(200, 100)), isTrue);
    expect(mask.contains(const Offset(10, 50), const Size(200, 100)), isFalse);
    expect(mask.contains(const Offset(55, 5), const Size(200, 100)), isFalse);
  });

  for (final name in names) {
    testWidgets('$name limits tap and admin editing after move and resize', (
      tester,
    ) async {
      final asset = 'assets/preview/royal-store/$name.webp';
      final mask = (await tester.runAsync(
        () => AlphaHitMaskRoyalClean.load(asset),
      ))!;
      var taps = 0;
      const targetKey = ValueKey('alpha-control');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 120,
                child: LayoutButtonRoyalClean(
                  id: 'alpha.$name',
                  layoutScope: 'app',
                  alwaysOverlay: true,
                  freeMovement: true,
                  hitTestAsset: asset,
                  capturePreview: () async => null,
                  child: GestureDetector(
                    key: targetKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await LayoutApprovalsRoyalClean.instance.save(
          'app/alpha.$name',
          const LayoutApprovalRoyalClean(dx: .08, dy: .06, scale: 1.7),
        );
      });
      await tester.pumpAndSettle();
      final bounds = tester.getRect(find.byKey(targetKey));
      expect(bounds.width, closeTo(340, .01));
      final corner = bounds.topLeft + const Offset(2, 2);
      await tester.tapAt(corner);
      expect(taps, 0);
      final gesture = await tester.startGesture(corner);
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      expect(find.text('OK'), findsNothing);
      // Pick a real opaque pixel near the center of the asset.
      final candidates = <Offset>[];
      for (var y = 0; y < mask.height; y++) {
        for (var x = 0; x < mask.width; x++) {
          if (mask.alpha[y * mask.width + x] > 100) {
            candidates.add(
              Offset((x + .5) / mask.width, (y + .5) / mask.height),
            );
          }
        }
      }
      candidates.sort(
        (a, b) => (a - const Offset(.5, .5)).distanceSquared.compareTo(
          (b - const Offset(.5, .5)).distanceSquared,
        ),
      );
      final fitted = Alignment.center.inscribe(
        applyBoxFit(
          BoxFit.contain,
          Size(mask.width.toDouble(), mask.height.toDouble()),
          bounds.size,
        ).destination,
        bounds,
      );
      final point =
          fitted.topLeft +
          Offset(
            candidates.first.dx * fitted.width,
            candidates.first.dy * fitted.height,
          );
      await tester.tapAt(point);
      expect(taps, 1);
      final hold = await tester.startGesture(point);
      await tester.pump(const Duration(milliseconds: 700));
      await hold.up();
      await tester.pumpAndSettle();
      expect(find.text('OK'), findsOneWidget);
      expect(taps, 1);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
}
