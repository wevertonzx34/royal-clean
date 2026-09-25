import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/main.dart';
import 'package:royal_clean/core_royal_clean/constants/app_routes_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/services/admin_access_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/auth/admin_route_guard_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/preview/preview_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/home_form_royal_clean.dart';

void main() {
  test('Admin requires matching email and strict boolean permissions', () {
    const valid = {
      'email': 'ADMIN@example.test',
      'ativo': true,
      'eAdministrador': true,
    };
    expect(isActiveAdminRoyalClean(valid, 'admin@example.test'), isTrue);
    for (final record in <Map<String, dynamic>?>[
      null,
      {},
      {...valid, 'ativo': false},
      {...valid, 'eAdministrador': false},
      {...valid, 'ativo': 'true'},
      {...valid, 'email': 'other@example.test'},
    ]) {
      expect(isActiveAdminRoyalClean(record, 'admin@example.test'), isFalse);
    }
    expect(isActiveAdminRoyalClean(valid, null), isFalse);
  });

  testWidgets(
    'Public preview opens despite Firebase failure; all admin routes are guarded',
    (tester) async {
      final initialization = Completer<void>();
      await tester.pumpWidget(
        RoyalCleanApp(firebaseInitialization: initialization.future),
      );
      initialization.completeError(StateError('Firebase unavailable'));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(PreviewPageRoyalClean), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      for (final route in [
        AppRoutesRoyalClean.home,
        AppRoutesRoyalClean.accessControl,
        AppRoutesRoyalClean.createInvite,
        AppRoutesRoyalClean.inviteStatus,
        AppRoutesRoyalClean.inviteStatusDetails,
        '/users',
        '/intercom',
        '/bling',
        '/bling-data',
      ]) {
        navigator.pushNamed(route, arguments: <String, dynamic>{});
        await tester.pumpAndSettle();
        expect(find.byType(AdminRouteGuardRoyalClean), findsOneWidget);
        expect(find.byType(HomeFormRoyalClean), findsNothing);
        expect(find.text('Ir para login'), findsOneWidget);
        navigator.pop();
        await tester.pumpAndSettle();
      }
      navigator.pushNamed('/rules-control');
      await tester.pumpAndSettle();
      expect(find.byType(PreviewPageRoyalClean), findsOneWidget);
      expect(find.text('Controle de regras'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Public preview opens even when Firebase never completes', (
    tester,
  ) async {
    await tester.pumpWidget(
      RoyalCleanApp(firebaseInitialization: Completer<void>().future),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(PreviewPageRoyalClean), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Protected content builds only while authorized and disappears on revocation',
    (tester) async {
      final access = StreamController<AdminAccessRoyalClean>();
      addTearDown(access.close);
      var builds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AdminRouteGuardRoyalClean(
            firebaseInitialization: Future<void>.value(),
            accessStream: () => access.stream,
            builder: (_) {
              builds++;
              return const Scaffold(body: Text('PRIVATE DATA'));
            },
          ),
        ),
      );
      await tester.pump();
      expect(builds, 0);
      for (final state in [
        AdminAccessRoyalClean.signedOut,
        AdminAccessRoyalClean.denied,
        AdminAccessRoyalClean.unavailable,
      ]) {
        access.add(state);
        await tester.pumpAndSettle();
        expect(builds, 0);
        expect(find.text('PRIVATE DATA'), findsNothing);
      }
      access.add(AdminAccessRoyalClean.allowed);
      await tester.pumpAndSettle();
      expect(find.text('PRIVATE DATA'), findsOneWidget);
      access.add(AdminAccessRoyalClean.denied);
      await tester.pumpAndSettle();
      expect(find.text('PRIVATE DATA'), findsNothing);
      access.add(AdminAccessRoyalClean.allowed);
      await tester.pumpAndSettle();
      access.addError(StateError('Permission lookup failed'));
      await tester.pumpAndSettle();
      expect(find.text('PRIVATE DATA'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Home keeps access control and logout without rules button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeFormRoyalClean(
            onAccessControlPressed: () {},
            onLogoutPressed: () {},
          ),
        ),
      ),
    );
    expect(find.text('Controle de regras'), findsNothing);
    expect(find.text('Controle de acesso'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
  });
}
