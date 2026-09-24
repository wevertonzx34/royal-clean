import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/core_royal_clean/services/account_access_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/auth/logout_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/auth/login_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/preview/preview_page_royal_clean.dart';

void main() {
  late StreamController<AccountIdentity?> auth;
  late Map<String, StreamController<AccountRecord>> documents;
  late AccountAccessRoyalClean access;
  late int subscriptions;
  const identity = AccountIdentity('admin1', 'admin@test.com', true);
  const validAdmin = {
    'email': 'admin@test.com',
    'ativo': true,
    'eAdministrador': true,
  };
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    auth = StreamController<AccountIdentity?>.broadcast();
    documents = {};
    subscriptions = 0;
    access = AccountAccessRoyalClean(
      identities: () => auth.stream,
      records: (collection, uid) {
        subscriptions++;
        return (documents['$collection/$uid'] ??=
                StreamController<AccountRecord>.broadcast())
            .stream;
      },
    );
    access.start();
  });
  tearDown(() async {
    access.dispose();
    await auth.close();
    for (final controller in documents.values) {
      await controller.close();
    }
  });

  test(
    'Server confirmation is required; token refresh preserves the live session; revocation blocks',
    () async {
      auth.add(identity);
      await flush();
      final admin = documents['admin/admin1']!;
      admin.add(const AccountRecord(validAdmin, confirmed: false));
      await flush();
      expect(access.value.status, AccountAccessStatus.checking);
      admin.add(const AccountRecord(validAdmin, confirmed: true));
      await flush();
      await access.ready();
      expect(access.value.status, AccountAccessStatus.admin);
      auth.add(identity);
      await flush();
      expect(subscriptions, 1);
      expect(access.value.status, AccountAccessStatus.admin);
      admin.add(
        const AccountRecord({
          'email': 'admin@test.com',
          'ativo': false,
          'eAdministrador': true,
        }, confirmed: true),
      );
      await flush();
      expect(access.value.status, AccountAccessStatus.denied);
      admin.addError(StateError('offline'));
      await flush();
      expect(access.value.status, AccountAccessStatus.unavailable);
    },
  );

  test('Sign out and identity changes discard previous permissions', () async {
    auth.add(identity);
    await flush();
    documents['admin/admin1']!.add(
      const AccountRecord(validAdmin, confirmed: true),
    );
    await flush();
    auth.add(null);
    await flush();
    expect(access.value.status, AccountAccessStatus.signedOut);
    auth.add(const AccountIdentity('consumer2', 'consumer@test.com', true));
    await flush();
    documents['admin/admin1']!.add(
      const AccountRecord(validAdmin, confirmed: true),
    );
    await flush();
    expect(access.value.status, AccountAccessStatus.checking);
    documents['admin/consumer2']!.add(
      const AccountRecord(null, confirmed: true),
    );
    await flush();
    documents['users/consumer2']!.add(
      const AccountRecord({
        'active': true,
        'role': 'consumer',
      }, confirmed: true),
    );
    await flush();
    expect(access.value.status, AccountAccessStatus.profile);
    expect(access.value.identity?.uid, 'consumer2');
    documents['users/consumer2']!.add(
      const AccountRecord({'active': true, 'role': 'admin'}, confirmed: true),
    );
    await flush();
    expect(access.value.status, AccountAccessStatus.denied);
  });

  testWidgets('Profile waits on preview and opens exactly once when ready', (
    tester,
  ) async {
    final ready = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: PreviewPageRoyalClean(
          authenticated: Stream.value(true),
          prepareAccount: () => ready.future,
        ),
        routes: {
          '/account': (_) => const Scaffold(body: Text('Perfil pronto')),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pump();
    expect(find.byType(PreviewPageRoyalClean), findsOneWidget);
    expect(find.text('Minha conta'), findsNothing);
    ready.complete();
    await tester.pumpAndSettle();
    expect(find.text('Perfil pronto'), findsOneWidget);
  });

  testWidgets(
    'Logout navigates even when auth disposes the source widget before completion',
    (tester) async {
      final signedIn = ValueNotifier(true);
      addTearDown(signedIn.dispose);
      final complete = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: signedIn,
            builder: (context, value, _) => value
                ? Builder(
                    builder: (buttonContext) => Scaffold(
                      body: TextButton(
                        onPressed: () => logoutToPreviewRoyalClean(
                          buttonContext,
                          signOut: () async {
                            signedIn.value = false;
                            await complete.future;
                          },
                        ),
                        child: const Text('Sair'),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          routes: {
            '/preview': (_) => const Scaffold(body: Text('Loja pública Login')),
          },
        ),
      );
      await tester.tap(find.text('Sair'));
      await tester.pump();
      expect(find.text('Sair'), findsNothing);
      complete.complete();
      await tester.pumpAndSettle();
      expect(find.text('Loja pública Login'), findsOneWidget);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        false,
      );
    },
  );

  testWidgets('Switching apps keeps the current route and entered form state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const PreviewPageRoyalClean(),
        routes: {
          '/login': (_) => LoginPageRoyalClean(
            firebaseInitialization: Completer<void>().future,
          ),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'preservado@example.com',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('preservado@example.com'), findsOneWidget);
    expect(find.byType(PreviewPageRoyalClean), findsNothing);
  });
}
