import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/main.dart';
import 'package:royal_clean/presentation_royal_clean/auth/account_ui_royal_clean.dart';

void main() {
  testWidgets(
    'Light preview cannot leave a white status bar on dark account or login routes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.reset);
      final updates = <Map<dynamic, dynamic>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemChrome.setSystemUIOverlayStyle') {
            updates.add(call.arguments as Map<dynamic, dynamic>);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        RoyalCleanApp(firebaseInitialization: Completer<void>().future),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      void expectBar(Color color, Brightness icons, Brightness iosBackground) {
        expect(updates, isNotEmpty);
        expect(updates.last['statusBarColor'], color.toARGB32());
        expect(updates.last['statusBarIconBrightness'], icons.toString());
        expect(updates.last['statusBarBrightness'], iosBackground.toString());
      }

      expectBar(Colors.white, Brightness.dark, Brightness.light);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      // All role/account pages use the same shared theme and account layout.
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const AccountLayoutRoyalClean(
            title: 'Perfil',
            child: Text('Área autenticada'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectBar(const Color(0xFF031923), Brightness.light, Brightness.dark);
      navigator.pop();
      await tester.pumpAndSettle();
      expectBar(Colors.white, Brightness.dark, Brightness.light);

      // Login has no AppBar, so it must receive the complete root overlay style.
      navigator.pushNamed('/login');
      await tester.pumpAndSettle();
      expectBar(const Color(0xFF031923), Brightness.light, Brightness.dark);
      navigator.pop();
      await tester.pumpAndSettle();
      expectBar(Colors.white, Brightness.dark, Brightness.light);
      expect(tester.takeException(), isNull);
    },
  );
}
