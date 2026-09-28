import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/auth/my_data_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/auth/phone_verification_royal_clean.dart';

class _User extends Fake implements User {
  @override
  String get uid => 'consumer';
  @override
  String? get email => 'consumer@example.test';
  @override
  String? get displayName => 'Consumidor Teste';
  @override
  String? get phoneNumber => '+5562999998888';
}

void main() {
  test('Brazilian phone normalization preserves the SMS target', () {
    expect(profilePhoneRoyalClean('(62) 99999-8888'), '+5562999998888');
    expect(profilePhoneRoyalClean('+55 62 99999-8888'), '+5562999998888');
    expect(profilePhoneRoyalClean('123'), isNull);
  });
  testWidgets(
    'Consumer can save minimal PF data then upgrade to PJ without roles in payload',
    (tester) async {
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: MyDataPageRoyalClean(
            user: _User(),
            profile: const {},
            loadData: () async => {
              'name': 'Consumidor Teste',
              'phone': '5562999998888',
            },
            saveData: (value) async {
              saved = value;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pessoa física'), findsOneWidget);
      expect(find.text('Telefone confirmado'), findsOneWidget);
      final save = find.text('Salvar dados');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved?['personType'], 'individual');
      expect(saved?['cpf'], '');
      expect(saved?.containsKey('role'), false);
      final type = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(type);
      await tester.tap(type);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pessoa jurídica').last);
      await tester.pumpAndSettle();
      Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.ensureVisible(field('CNPJ'));
      await tester.enterText(field('CNPJ'), '62.581.826/0001-49');
      await tester.ensureVisible(field('Razão social'));
      await tester.enterText(field('Razão social'), 'Royal Clean LTDA');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved?['personType'], 'company');
      expect(saved?['companyLegalName'], 'Royal Clean LTDA');
      expect(saved?.containsKey('phoneVerified'), false);
      expect(tester.takeException(), isNull);
    },
  );
}
