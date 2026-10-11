import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:royal_clean/core_royal_clean/services/account_access_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/services/layout_approvals_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/production_drawer_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/shared/layout_button_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/avatar_aura_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/shared/alpha_hit_region_royal_clean.dart';

void main() {
  setUpAll(() async {
    for (final name in ['royal-gaveta', 'produtos-royal']) {
      await AlphaHitMaskRoyalClean.load(
        'assets/preview/royal-store/$name.webp',
      );
    }
  });
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
    // Approved defaults position the buttons through the overlay on the next frame.
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    final hologram = find.byKey(const ValueKey('produtos-royal-gif-shortcut'));
    expect(hologram, findsOneWidget);
    await tester.tapAt(tester.getTopLeft(hologram) + const Offset(8, 8));
    await tester.pump(const Duration(seconds: 2));
    expect(products, 1); // Transparent corners no longer activate the hologram.
    await tester.tapAt(tester.getCenter(hologram));
    await tester.pump(const Duration(seconds: 2));
    expect(products, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Selecting a button swaps exact geometry and only the principal emits purple ash',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var orders = 0, revenue = 0;
      Widget drawer() => MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            disableAnimations: true,
          ),
          child: Scaffold(
            body: ProductionDrawerRoyalClean(
              onOpenOrders: () async => orders++,
              onOpenProducts: () async {},
              onOpenRevenue: () async => revenue++,
              captureLayoutPreview: _emptyPreview,
            ),
          ),
        ),
      );
      Finder button(String name) =>
          find.byKey(ValueKey('royal-$name-shortcut'));
      AvatarAuraRoyalClean aura(String name) => tester.widget(
        find.descendant(
          of: button(name),
          matching: find.byType(AvatarAuraRoyalClean),
        ),
      );
      await tester.pumpWidget(drawer());
      await tester.pumpAndSettle();
      // Exercise an approved admin position, not only the default slot layout.
      await tester.longPress(button('produtos'));
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(180, 400), const Offset(12, -25));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final principal = tester.getRect(button('produtos'));
      final secondary = tester.getRect(button('pedidos'));
      final third = tester.getRect(button('receita'));
      await tester.tap(button('pedidos'));
      await tester.pumpAndSettle();
      expect(orders, 1);
      expect(tester.getRect(button('pedidos')), principal);
      expect(tester.getRect(button('produtos')), secondary);
      expect(aura('pedidos').particles, isTrue);
      expect(aura('pedidos').particleColor, const Color(0xFFC08AFF));
      expect(aura('produtos').particles, isFalse);
      expect(aura('receita').particles, isFalse);
      await tester.tap(button('receita'));
      await tester.pumpAndSettle();
      expect(revenue, 1);
      expect(tester.getRect(button('receita')), principal);
      expect(tester.getRect(button('pedidos')), third);
      expect(tester.getRect(button('produtos')), secondary);
      expect(aura('receita').particles, isTrue);
      expect(aura('pedidos').particles, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(drawer());
      await tester.pumpAndSettle();
      expect(tester.getRect(button('receita')), principal);
      expect(tester.getRect(button('pedidos')), third);
      expect(aura('receita').particles, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
