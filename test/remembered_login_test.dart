import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/core_royal_clean/services/remembered_login_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/services/session_preferences_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/auth/login_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/auth/logout_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/preview/preview_page_royal_clean.dart';
import 'biometric_access_test.dart' show Device;
import 'session_preferences_test.dart' show MemoryPreferences;

void main() {
  testWidgets(
    'Remembered login survives logout without retaining a private session or storing the password',
    (tester) async {
      String? savedEmail;
      final memory = RememberedLoginRoyalClean(
        read: () async => savedEmail,
        write: (value) async {
          savedEmail = value;
        },
      );
      final preferences = SessionPreferencesRoyalClean(
        storage: MemoryPreferences(),
      );
      final device = Device()..uid = null;
      Widget login() => LoginPageRoyalClean(
        rememberedLogin: memory,
        sessionPreferences: preferences,
        biometricAccess: device.access,
        passwordSignIn: (email, password) async {
          device.uid = 'alice';
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: login(),
          routes: {
            '/account': (context) => Scaffold(
              body: TextButton(
                onPressed: () => logoutToPreviewRoyalClean(
                  context,
                  signOut: () async {
                    device.uid = null;
                    await device.access.disable();
                  },
                ),
                child: const Text('Sair'),
              ),
            ),
            '/preview': (_) => const PreviewPageRoyalClean(),
            '/login': (_) => login(),
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'alice@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Senha1234');
      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ativar'));
      await tester.pumpAndSettle();
      expect(device.access.enabled, true);
      expect(savedEmail, 'alice@example.test');
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
      expect(device.uid, isNull);
      expect(device.access.enabled, false);
      expect(find.text('Login'), findsOneWidget);
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[0].controller!.text, 'alice@example.test');
      expect(fields[1].controller!.text, isEmpty);
      expect(fields[1].autofillHints, contains(AutofillHints.password));
      expect(find.text('Entrar com digital'), findsNothing);
    },
  );

  testWidgets(
    'Unchecking remember deletes the saved email and stops requesting autofill',
    (tester) async {
      String? saved = 'alice@example.test';
      final memory = RememberedLoginRoyalClean(
        read: () async => saved,
        write: (value) async {
          saved = value;
        },
      );
      final prefs = SessionPreferencesRoyalClean(storage: MemoryPreferences());
      final device = Device()..uid = null;
      Widget app() => MaterialApp(
        home: LoginPageRoyalClean(
          rememberedLogin: memory,
          sessionPreferences: prefs,
          biometricAccess: device.access,
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('alice@example.test'), findsOneWidget);
      await tester.ensureVisible(find.text('Manter conectado'));
      await tester.tap(find.text('Manter conectado'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[0].controller!.text, isEmpty);
      expect(fields[1].autofillHints, isNull);
    },
  );

  testWidgets('A failed login cannot replace the remembered email', (
    tester,
  ) async {
    String? saved = 'previous@example.test';
    final memory = RememberedLoginRoyalClean(
      read: () async => saved,
      write: (value) async {
        saved = value;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPageRoyalClean(
          rememberedLogin: memory,
          sessionPreferences: SessionPreferencesRoyalClean(
            storage: MemoryPreferences(),
          ),
          biometricAccess: (Device()..uid = null).access,
          passwordSignIn: (_, _) async =>
              throw StateError('Invalid credentials'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'other@example.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Invalid123');
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(saved, 'previous@example.test');
  });
}
