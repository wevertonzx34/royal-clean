import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:royal_clean/core_royal_clean/services/intercom_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/shared/header_actions_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/intercom_page_royal_clean.dart';

void main() {
  testWidgets(
    'Reviewed tab is reserved for user evaluations, not admin or read status',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: IntercomPageRoyalClean()),
      );
      expect(find.text('Marcar como avaliada'), findsNothing);
      await tester.tap(find.text('Avaliadas'));
      await tester.pumpAndSettle();
      expect(find.text('Avaliações dos usuários'), findsOneWidget);
      expect(
        find.text('Marcar uma notificação como lida não é uma avaliação.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Publicadas'));
      await tester.pumpAndSettle();
      expect(find.text('Avaliações dos usuários'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test('Expiration is exclusive at the deadline', () {
    final now = DateTime(2026, 9, 25);
    final message = IntercomMessageRoyalClean(
      id: 'one',
      title: 'Aviso',
      body: 'Texto',
      kind: 'Mensagem',
      publishedAt: now,
      expiresAt: now.add(const Duration(days: 1)),
    );
    expect(message.activeAt(now), isTrue);
    expect(message.activeAt(message.expiresAt), isFalse);
  });
  testWidgets(
    'Globe shows new messages, excludes expired ones, and reading clears badge',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final feed = IntercomRoyalClean.instance;
      final now = DateTime.now();
      feed.messages = [
        IntercomMessageRoyalClean(
          id: 'new',
          title: 'Aviso novo',
          body: 'Conteúdo do admin',
          kind: 'Alerta',
          publishedAt: now,
          expiresAt: now.add(const Duration(days: 1)),
        ),
        IntercomMessageRoyalClean(
          id: 'old',
          title: 'Aviso vencido',
          body: 'Anterior',
          kind: 'Mensagem',
          publishedAt: now.subtract(const Duration(days: 2)),
          expiresAt: now.subtract(const Duration(days: 1)),
        ),
      ];
      addTearDown(() => feed.messages = []);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(appBar: null, body: NotificationButtonRoyalClean()),
        ),
      );
      expect(feed.unreadCount, 1);
      await tester.tap(find.byTooltip('Notificações'));
      await tester.pumpAndSettle();
      expect(find.text('Aviso novo'), findsOneWidget);
      expect(find.text('Aviso vencido'), findsNothing);
      await tester.tap(find.text('Marcar como lida'));
      await tester.pumpAndSettle();
      expect(feed.unreadCount, 0);
      expect(find.text('Aviso novo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
