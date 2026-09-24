import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/core_royal_clean/services/biometric_access_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/auth/biometric_gate_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/auth/login_page_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/services/session_preferences_royal_clean.dart';
import 'session_preferences_test.dart' show MemoryPreferences;

class Device {
  String? uid = 'alice', saved;
  bool confirmed = true, supported = true, rejectedByServer = false;
  int validations = 0, prompts = 0;
  late final access = BiometricAccessRoyalClean(
    currentUid: () => uid,
    readEnrollment: () async => saved,
    writeEnrollment: (value) async {
      saved = value;
    },
    checkAvailable: () async => supported,
    authenticate: () async {
      prompts++;
      return confirmed;
    },
    validateSession: () async {
      validations++;
      if (rejectedByServer) throw StateError('Revoked');
    },
  );
}

void main() {
  for (final remember in [true, false]) {
    testWidgets(
      'Successful password login offers biometric consent with remember=$remember',
      (tester) async {
        final device = Device()..uid = null;
        final storage = MemoryPreferences();
        storage.values[SessionPreferencesRoyalClean.rememberKey] = remember;
        await tester.pumpWidget(
          MaterialApp(
            home: LoginPageRoyalClean(
              biometricAccess: device.access,
              sessionPreferences: SessionPreferencesRoyalClean(
                storage: storage,
              ),
              passwordSignIn: (email, password) async {
                device.uid = 'alice';
              },
            ),
            routes: {
              '/account': (_) => const Scaffold(body: Text('Área autorizada')),
            },
          ),
        );
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'alice@example.test');
        await tester.enterText(fields.at(1), 'Senha1234');
        await tester.ensureVisible(find.text('Entrar'));
        tester.testTextInput.log.clear();
        await tester.tap(find.text('Entrar'));
        await tester.pumpAndSettle();
        expect(find.text('Proteger acesso neste aparelho?'), findsOneWidget);
        expect(device.prompts, 0);
        expect(
          tester.testTextInput.log.where(
            (call) =>
                call.method == 'TextInput.finishAutofillContext' &&
                call.arguments == true,
          ),
          isEmpty,
        );
        await tester.tap(find.text(remember ? 'Agora não' : 'Ativar'));
        await tester.pumpAndSettle();
        expect(find.text('Área autorizada'), findsOneWidget);
        expect(device.saved, remember ? null : 'alice');
        expect(device.prompts, 0);
        expect(
          tester.testTextInput.log.any(
            (call) =>
                call.method == 'TextInput.finishAutofillContext' &&
                call.arguments == true,
          ),
          remember,
        );
      },
    );
  }
  test(
    'Post-login consent defers native authentication until cold-start unlock',
    () async {
      final device = Device();
      expect(await device.access.enable(confirmDevice: false), true);
      expect(device.prompts, 0);
      expect(device.access.locked, false);
      final restarted = Device()..saved = device.saved;
      expect(await restarted.access.restore(), true);
      restarted.confirmed = false;
      expect(await restarted.access.unlock(), false);
      expect(restarted.access.locked, true);
      // The native system can return success for fingerprint OR device PIN.
      restarted.confirmed = true;
      expect(await restarted.access.unlock(), true);
      expect(restarted.validations, 1);
      expect(restarted.access.locked, false);
    },
  );

  testWidgets(
    'Login has no biometric entry and app switching does not relock an unlocked profile',
    (tester) async {
      final device = Device()..saved = 'alice';
      await device.access.restore();
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPageRoyalClean(
            biometricAccess: device.access,
            sessionPreferences: SessionPreferencesRoyalClean(
              storage: MemoryPreferences(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Entrar com digital'), findsNothing);
      expect(device.prompts, 0);
      device.access.credentialsAccepted();
      await tester.pumpWidget(
        MaterialApp(
          home: BiometricGateRoyalClean(
            access: device.access,
            builder: (_) => const Scaffold(body: TextField()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Tela preservada');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Tela preservada'), findsOneWidget);
      expect(device.prompts, 0);
      expect(device.access.locked, false);
    },
  );
  test(
    'Opt-in only activates after device confirmation; restoration locks the retained account',
    () async {
      final device = Device()..confirmed = false;
      expect(await device.access.enable(), isFalse);
      expect(device.saved, isNull);
      device.confirmed = true;
      expect(await device.access.enable(), isTrue);
      expect(device.saved, 'alice');
      expect(await device.access.restore(), isTrue);
      expect(device.access.locked, isTrue);
      device.confirmed = false;
      expect(await device.access.unlock(), isFalse);
      expect(device.access.locked, isTrue);
      expect(device.validations, 0);
      device.confirmed = true;
      expect(await device.access.unlock(), isTrue);
      expect(device.validations, 1);
      expect(device.access.locked, isFalse);
    },
  );

  test(
    'Biometric success never bypasses revoked Firebase sessions or account binding',
    () async {
      final device = Device()..saved = 'alice';
      await device.access.restore();
      device.rejectedByServer = true;
      await expectLater(device.access.unlock(), throwsStateError);
      expect(device.access.locked, isTrue);
      device.uid = 'bob';
      expect(await device.access.unlock(), isFalse);
      expect(device.access.locked, isTrue);
    },
  );

  test(
    'Unavailable biometrics preserve normal credentials; explicit disable removes enrollment',
    () async {
      final device = Device()..supported = false;
      expect(await device.access.enable(), isFalse);
      expect(device.prompts, 0);
      device.saved = 'alice';
      await device.access.restore();
      device.access.credentialsAccepted();
      expect(device.access.locked, isFalse);
      await device.access.disable();
      expect(device.saved, isNull);
      expect(device.access.enabled, isFalse);
    },
  );

  test(
    'Public preview keeps Perfil for a retained locked session and updates on logout',
    () async {
      final device = Device()..saved = 'alice';
      await device.access.restore();
      final auth = StreamController<bool>();
      final events = <bool>[];
      final subscription = device.access
          .visibleSession(auth.stream)
          .listen(events.add);
      auth.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(events.last, isTrue);
      expect(device.access.locked, isTrue);
      await device.access.unlock();
      await Future<void>.delayed(Duration.zero);
      expect(events.last, isTrue);
      auth.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(events.last, isFalse);
      await subscription.cancel();
      await auth.close();
    },
  );

  testWidgets('Private content never builds while biometric lock is active', (
    tester,
  ) async {
    final device = Device()
      ..saved = 'alice'
      ..confirmed = false;
    await device.access.restore();
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BiometricGateRoyalClean(
          access: device.access,
          builder: (_) {
            builds++;
            return const Text('Protected');
          },
        ),
      ),
    );
    expect(builds, 0);
    expect(find.text('Protected'), findsNothing);
    device.confirmed = false;
    await device.access.unlock();
    await tester.pump();
    expect(builds, 0);
    device.confirmed = true;
    await device.access.unlock();
    await tester.pump();
    expect(find.text('Protected'), findsOneWidget);
  });
}
