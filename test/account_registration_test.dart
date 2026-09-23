import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/core_royal_clean/services/account_service_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/theme/app_theme_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/auth/account_gate_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/auth/login_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/auth/registration_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/auth/account_ui_royal_clean.dart';

void main() {
  test('Names and emails accept real-world formats', () {
    for (final name in ['João', 'Ana-Maria D’Ávila', '李明']) {
      expect(validateNameRoyalClean(name), isNull);
    }
    expect(validateNameRoyalClean(' '), isNotNull);
    expect(validateNameRoyalClean('<script>'), isNotNull);
    expect(validateEmailRoyalClean('pessoa+loja@example.com'), isNull);
    expect(validateEmailRoyalClean('pessoa @example.com'), isNotNull);
  });
  testWidgets(
    'Login places account actions above email and keeps registration navigation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemeRoyalClean.theme,
          home: const LoginPageRoyalClean(),
          routes: {'/register': (_) => const RegistrationPageRoyalClean()},
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('Novo usuário')).dx,
        lessThan(tester.getCenter(find.text('Esqueci senha')).dx),
      );
      expect(
        tester.getBottomLeft(find.text('Esqueci senha')).dy,
        lessThan(tester.getTopLeft(find.byType(TextFormField).first).dy),
      );
      expect(find.text('Voltar à loja'), findsOneWidget);
      expect(find.text('Continuar com Google'), findsOneWidget);
      expect(find.text('Continuar com Apple'), findsOneWidget);
      await tester.ensureVisible(find.text('Novo usuário'));
      await tester.tap(find.text('Novo usuário'));
      await tester.pumpAndSettle();
      expect(find.byType(RegistrationPageRoyalClean), findsOneWidget);
      expect(find.text('Confirmar e-mail'), findsOneWidget);
      expect(find.text('Confirmar senha'), findsOneWidget);
      expect(find.text('Compro para mim'), findsNothing);
      expect(find.text('Compro para uma empresa'), findsNothing);
      for (final checkbox in tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      )) {
        expect(checkbox.value, isFalse);
      }
    },
  );
  testWidgets(
    'Registration rejects mismatched email/password without calling Firebase',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: RegistrationPageRoyalClean()),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'João da Silva');
      await tester.enterText(fields.at(1), 'joao@example.test');
      await tester.enterText(fields.at(2), 'outro@example.test');
      await tester.enterText(fields.at(3), 'uma senha longa segura');
      await tester.enterText(fields.at(4), 'não confere');
      await tester.ensureVisible(find.text('Concluir cadastro'));
      await tester.tap(find.text('Concluir cadastro'));
      await tester.pumpAndSettle();
      expect(find.text('Os e-mails não conferem.'), findsOneWidget);
      expect(find.text('As senhas não conferem.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Registration, legal pages and role areas adapt to narrow screen and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final child in <Widget>[
        const LoginPageRoyalClean(),
        const RegistrationPageRoyalClean(),
        const LegalPageRoyalClean(privacy: true),
        const LegalPageRoyalClean(privacy: false),
        for (final role in roleLabelsRoyalClean.keys)
          RoleAreaRoyalClean(profile: {'name': 'João da Silva', 'role': role}),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemeRoyalClean.theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: child,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('Private areas fail closed when Firebase initialization fails', (
    tester,
  ) async {
    final init = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: AccountGateRoyalClean(firebaseInitialization: init.future),
      ),
    );
    init.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.byType(RoleAreaRoyalClean), findsNothing);
    expect(find.text('Ir para login'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
