import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/core_royal_clean/constants/app_routes_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/theme/app_theme_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/auth/login_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/preview/preview_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/splash/splash_page_royal_clean.dart';

Widget testApp({bool splash = false}) => MaterialApp(
  theme: AppThemeRoyalClean.theme,
  home: splash
      ? SplashPageRoyalClean(firebaseInitialization: Future<void>.value())
      : const PreviewPageRoyalClean(),
  routes: {
    AppRoutesRoyalClean.preview: (_) => const PreviewPageRoyalClean(),
    AppRoutesRoyalClean.login: (_) => const LoginPageRoyalClean(),
  },
);

void main() {
  testWidgets('Startup opens preview and login remains opt-in', (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(testApp(splash: true));
    expect(find.text('Inicializando ambiente...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(PreviewPageRoyalClean), findsOneWidget);
    expect(find.byType(LoginPageRoyalClean), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPageRoyalClean), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    Navigator.of(tester.element(find.byType(LoginPageRoyalClean))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(PreviewPageRoyalClean), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Categories filter and product and editorial details open', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Produtos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Kits'));
    await tester.pumpAndSettle();
    expect(find.text('Multiuso essencial'), findsNothing);
    expect(find.text('Seleção Royal Clean'), findsOneWidget);
    await tester.ensureVisible(find.text('Seleção Royal Clean'));
    await tester.tap(find.text('Seleção Royal Clean'));
    await tester.pumpAndSettle();
    expect(find.text('PRODUTO DEMONSTRATIVO'), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text('Um novo jeito de estar perto de você.'),
    );
    await tester.tap(find.text('Um novo jeito de estar perto de você.'));
    await tester.pumpAndSettle();
    expect(find.text('UNIVERSO ROYAL CLEAN · DEMONSTRAÇÃO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compact and wide layouts render without overflow', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [const Size(320, 640), const Size(1200, 900)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
