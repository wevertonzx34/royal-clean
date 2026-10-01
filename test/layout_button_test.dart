import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:royal_clean/core_royal_clean/services/account_access_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/services/layout_approvals_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/shared/layout_button_royal_clean.dart';

void main() {
  final access = AccountAccessRoyalClean.instance;
  int sequence = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    access.value = AccountAccessState(
      AccountAccessStatus.admin,
      identity: AccountIdentity('button-test-${sequence++}', null, true),
    );
  });
  tearDown(
    () =>
        access.value = const AccountAccessState(AccountAccessStatus.signedOut),
  );
  Future<void> mount(
    WidgetTester tester,
    VoidCallback action, {
    double maxScale = 2.5,
    bool freeMovement = false,
  }) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LayoutButtonRoyalClean(
              id: 'test.button',
              maxScale: maxScale,
              freeMovement: freeMovement,
              capturePreview: () async => null,
              child: ElevatedButton(
                onPressed: action,
                child: const Text('Original action'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Free drag and second-finger zoom stop at 140% without tapping the action',
    (tester) async {
      var taps = 0;
      await mount(tester, () => taps++, maxScale: 1.4, freeMovement: true);
      final target = find.byType(ElevatedButton);
      final original = tester.getSize(target);
      await tester.longPress(target);
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(200, 450), const Offset(70, 70));
      final first = await tester.startGesture(
        const Offset(180, 460),
        pointer: 1,
      );
      final second = await tester.startGesture(
        const Offset(220, 460),
        pointer: 2,
      );
      await tester.pump();
      await first.moveTo(const Offset(80, 460));
      await second.moveTo(const Offset(330, 460));
      await tester.pump();
      await first.up();
      await second.up();
      expect(taps, 0);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final actual = tester.getRect(target);
      expect(actual.width, closeTo(original.width * 1.4, .1));
      await tester.tapAt(actual.center);
      expect(taps, 1);
    },
  );

  testWidgets(
    'Tap preserves action, long press edits; cancel leaves original',
    (tester) async {
      var taps = 0;
      await mount(tester, () => taps++);
      final original = tester.getCenter(find.text('Original action'));
      await tester.tap(find.text('Original action'));
      expect(taps, 1);
      await tester.longPress(find.text('Original action'));
      await tester.pumpAndSettle();
      expect(find.text('OK'), findsOneWidget);
      expect(taps, 1);
      await tester.dragFrom(const Offset(200, 400), const Offset(60, 100));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.text('Original action')), original);
    },
  );
  testWidgets(
    'Confirmed moved control remains clickable; restore returns origin',
    (tester) async {
      var taps = 0;
      await mount(tester, () => taps++);
      final original = tester.getCenter(find.text('Original action'));
      await tester.longPress(find.text('Original action'));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(200, 400), const Offset(60, 100));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Original action'), findsOneWidget);
      final moved = tester.getCenter(find.text('Original action'));
      expect(moved.dy, greaterThan(original.dy));
      await tester.tapAt(moved);
      expect(taps, 1);
      await tester.longPress(find.text('Original action'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restaurar'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.text('Original action')), original);
    },
  );
  testWidgets('Consumer cannot edit; permission loss closes guide', (
    tester,
  ) async {
    await mount(tester, () {});
    await tester.longPress(find.text('Original action'));
    await tester.pumpAndSettle();
    access.value = const AccountAccessState(
      AccountAccessStatus.profile,
      identity: AccountIdentity('consumer', null, true),
    );
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsNothing);
    await tester.longPress(find.text('Original action'));
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsNothing);
    expect(LayoutApprovalsRoyalClean.instance.authorized, isFalse);
  });
}
