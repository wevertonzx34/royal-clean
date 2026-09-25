import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/home_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/access_control_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/auth/account_ui_royal_clean.dart';

void main() {
  testWidgets('Admin opens notifications without leaving the panel', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomePageRoyalClean()));
    expect(find.byIcon(Icons.manage_accounts), findsNothing);
    expect(find.byTooltip('Meus dados'), findsOneWidget);
    await tester.tap(find.byTooltip('Notificações'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma notificação por aqui.'), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar notificações'));
    await tester.pumpAndSettle();
    expect(find.byType(HomePageRoyalClean), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Access control contains users action and shared shortcuts at 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: const AccessControlPageRoyalClean(),
          routes: {
            '/users': (_) => const Scaffold(body: Text('Users destination')),
          },
        ),
      );
      expect(find.byTooltip('Notificações'), findsOneWidget);
      expect(find.byTooltip('Meus dados'), findsOneWidget);
      expect(find.byIcon(Icons.manage_accounts), findsOneWidget);
      await tester.tap(find.text('Usuários e perfis'));
      await tester.pumpAndSettle();
      expect(find.text('Users destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Account pages keep notifications and do not stack My data on itself',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/my-data',
          routes: {
            '/my-data': (_) => const AccountLayoutRoyalClean(
              title: 'Meus dados',
              child: Text('Profile'),
            ),
          },
        ),
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.person_outline),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Notificações'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma notificação por aqui.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
