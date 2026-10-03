import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:royal_clean/core_royal_clean/services/layout_approvals_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/services/account_access_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/door_invitation_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/shared/layout_button_royal_clean.dart';

void main() {
  testWidgets('Overlay edits independently and retains tap after moving', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final access = AccountAccessRoyalClean.instance;
    access.value = const AccountAccessState(
      AccountAccessStatus.admin,
      identity: AccountIdentity('logo-guide-test', null, true),
    );
    addTearDown(
      () => access.value = const AccountAccessState(
        AccountAccessStatus.signedOut,
      ),
    );
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DoorTestPage(
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 250,
                  height: 420,
                  child: LayoutButtonRoyalClean(
                    id: 'test.parent-door',
                    capturePreview: () async => null,
                    child: GestureDetector(
                      onTap: () => taps++,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: Colors.blue),
                          DoorInvitationRoyalClean(
                            onActivate: () async {
                              taps++;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final logo = find.byKey(const ValueKey('door-logo-image'));
    await tester.runAsync(
      () => precacheImage(
        const ResizeImage(
          AssetImage('assets/preview/royal-store/logo-porta.webp'),
          width: 300,
        ),
        tester.element(logo),
      ),
    );
    await tester.pumpAndSettle();
    final original = tester.getCenter(logo);
    await tester.tap(logo);
    await tester.pumpAndSettle();
    expect(taps, 1);
    await tester.longPress(logo);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsOneWidget);
    expect(taps, 1);
    await tester.dragFrom(original, const Offset(80, 100));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      LayoutApprovalsRoyalClean.instance.export(),
      contains('home.door-logo'),
    );
    final moved = tester.getCenter(logo);
    expect(moved.dy, greaterThan(original.dy));
    await tester.tapAt(moved);
    await tester.pumpAndSettle();
    expect(taps, 2);
    expect(tester.takeException(), isNull);
  });
}

class DoorTestPage extends StatelessWidget {
  final Widget child;
  const DoorTestPage({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
