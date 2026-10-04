import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:royal_clean/core_royal_clean/services/account_access_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/services/layout_approvals_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/production_drawer_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/shared/layout_button_royal_clean.dart';

void main() {
  final access = AccountAccessRoyalClean.instance;
  var sequence = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    access.value = AccountAccessState(
      AccountAccessStatus.admin,
      identity: AccountIdentity('production-layout-${sequence++}', null, true),
    );
  });
  tearDown(
    () =>
        access.value = const AccountAccessState(AccountAccessStatus.signedOut),
  );

  testWidgets('Drawer fits a small phone and orders opens once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var opened = 0, products = 0, revenue = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: ProductionDrawerRoyalClean(
              onOpenOrders: () async {
                opened++;
              },
              onOpenProducts: () async => products++,
              onOpenRevenue: () async => revenue++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Produtos'), findsOneWidget);
    expect(find.text('Produção'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('royal-produtos-shortcut')));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('royal-pedidos-shortcut')));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('royal-receita-shortcut')));
    await tester.pump(const Duration(seconds: 2));
    expect(opened, 1);
    expect(products, 1);
    expect(revenue, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Admin can long-press every title and image to edit its button', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(360, 800), disableAnimations: true),
          child: Scaffold(
            body: ProductionDrawerRoyalClean(
              captureLayoutPreview: _emptyPreview,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(LayoutApprovalsRoyalClean.instance.authorized, isTrue);
    final productsEdit = LayoutButtonRoyalClean.adminLongPressOf(
      tester.element(find.byKey(const ValueKey('royal-produtos-shortcut'))),
    );
    expect(productsEdit, isNotNull);
    productsEdit!();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pump(const Duration(milliseconds: 200));

    for (final entry in const {
      'Produtos': 'production.royal-produtos',
      'Pedidos': 'production.royal-pedidos',
      'Produção': 'production.royal-receita',
    }.entries) {
      final title = entry.key;
      final gesture = await tester.startGesture(
        tester.getCenter(find.text(title)),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('OK'), findsOneWidget, reason: title);
      await tester.tap(find.text('OK'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        LayoutApprovalsRoyalClean.instance.export(),
        contains(entry.value),
        reason: title,
      );
    }

    await tester.longPress(
      find.byKey(const ValueKey('royal-produtos-shortcut')),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('OK'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
  });
}

Future<Uint8List?> _emptyPreview() async => null;
