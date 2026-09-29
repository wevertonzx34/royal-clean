import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:royal_clean/core_royal_clean/services/account_access_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/title_layout_guide_royal_clean.dart';

void main() {
  final access = AccountAccessRoyalClean.instance;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    access.value = const AccountAccessState(
      AccountAccessStatus.admin,
      identity: AccountIdentity('guide-test', null, true),
    );
  });
  tearDown(
    () =>
        access.value = const AccountAccessState(AccountAccessStatus.signedOut),
  );
  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(432, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TitleLayoutGuideRoyalClean(
            defaultY: .3,
            child: ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final title = find.byKey(const ValueKey('layout-guide-title'));
  testWidgets('Only admin can enter the guide', (tester) async {
    access.value = const AccountAccessState(
      AccountAccessStatus.profile,
      identity: AccountIdentity('consumer', null, true),
    );
    await mount(tester);
    await tester.longPress(title);
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsNothing);
  });
  testWidgets(
    'Drag cancel restores; OK persists and reloads normalized position',
    (tester) async {
      await mount(tester);
      final original = tester.getTopLeft(title);
      await tester.longPress(title);
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(210, 400), const Offset(25, 90));
      await tester.pump();
      expect(tester.getTopLeft(title).dy, greaterThan(original.dy));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(title), original);
      await tester.longPress(title);
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(210, 400), const Offset(25, 90));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final data =
          jsonDecode(
                prefs.getString(
                  'layout_guide.my_property.title.v1.guide-test',
                )!,
              )
              as Map;
      expect(data['y'], greaterThan(.3));
      final saved = tester.getTopLeft(title);
      await tester.pumpWidget(const SizedBox.shrink());
      await mount(tester);
      expect(tester.getTopLeft(title), saved);
      await tester.longPress(title);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restaurar'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(title), original);
    },
  );
  testWidgets('Two fingers scale and translate; loss of admin cancels editor', (
    tester,
  ) async {
    await mount(tester);
    await tester.longPress(title);
    await tester.pumpAndSettle();
    final a = await tester.startGesture(const Offset(160, 400), pointer: 1);
    final b = await tester.startGesture(const Offset(260, 400), pointer: 2);
    await tester.pump();
    await a.moveTo(const Offset(140, 430));
    await b.moveTo(const Offset(280, 430));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final data =
        jsonDecode(
              prefs.getString('layout_guide.my_property.title.v1.guide-test')!,
            )
            as Map;
    expect(data['fontSize'], greaterThan(16));
    expect(data['y'], greaterThan(.3));
    await tester.longPress(title);
    await tester.pumpAndSettle();
    access.value = const AccountAccessState(AccountAccessStatus.signedOut);
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
