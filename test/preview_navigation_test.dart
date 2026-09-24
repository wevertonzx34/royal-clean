import 'dart:async';
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
  testWidgets(
    'Notifications open and partnerships shortcut scrolls to section',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();
      final about = find.widgetWithText(TextButton, 'Sobre nós');
      final account = find.widgetWithText(FilledButton, 'Login');
      expect(
        tester.getCenter(about).dx,
        closeTo(tester.getCenter(account).dx, .1),
      );
      final menuTop = tester.getTopLeft(find.text('Novidades')).dy;
      for (final label in [
        'Produtos',
        'Novidades',
        'Desempenho',
        'Sobre nós',
      ]) {
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Notificações'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma notificação por aqui.'), findsOneWidget);
      await tester.tap(find.byTooltip('Fechar notificações'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Novidades'));
      await tester.pumpAndSettle();
      expect(find.text('NOSSA PARCERIA').hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(find.text('Novidades')).dy, menuTop);
      for (final label in [
        'Produtos',
        'Novidades',
        'Desempenho',
        'Sobre nós',
      ]) {
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      await tester.tap(find.text('Sobre nós'));
      await tester.pumpAndSettle();
      expect(find.text('FIQUE POR DENTRO').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Desempenho'));
      await tester.pumpAndSettle();
      expect(find.text('NOSSA PARCERIA').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Preview follows session changes and profile routes through account guard',
    (tester) async {
      final session = StreamController<bool>();
      addTearDown(session.close);
      await tester.pumpWidget(
        MaterialApp(
          home: PreviewPageRoyalClean(authenticated: session.stream),
          routes: {
            '/account': (_) => const Scaffold(body: Text('Conta protegida')),
          },
        ),
      );
      session.add(false);
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
      session.add(true);
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsNothing);
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Conta protegida'), findsOneWidget);
      Navigator.of(tester.element(find.text('Conta protegida'))).pop();
      await tester.pumpAndSettle();
      session.add(false);
      await tester.pumpAndSettle();
      expect(find.text('Perfil'), findsNothing);
      expect(find.text('Login'), findsOneWidget);
    },
  );
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
    await tester.tap(find.text('Nichos'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Kits'));
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

  testWidgets(
    'Product search matches names codes and accent-insensitive tags',
    (tester) async {
      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Produtos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nichos'));
      await tester.pumpAndSettle();
      final lensPosition = tester.getCenter(
        find.byTooltip('Pesquisar produtos'),
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Ofertas'));
      expect(
        tester.getCenter(find.byTooltip('Pesquisar produtos')).dx,
        lensPosition.dx,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Ofertas'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nenhum produto encontrado. Tente outro termo ou nicho.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Pesquisar produtos'));
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Nichos'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      // Repeat the niches/lens cycle without losing the search behavior.
      await tester.tap(find.text('Nichos'));
      await tester.pumpAndSettle();
      expect(find.text('Nichos'), findsNothing);
      expect(find.byTooltip('Rolar a lista de nichos'), findsOneWidget);
      await tester.tap(find.byTooltip('Rolar a lista de nichos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pesquisar produtos'));
      await tester.pumpAndSettle();
      expect(find.text('Nichos'), findsOneWidget);
      await tester.tap(find.byTooltip('Pesquisar produtos'));
      await tester.pumpAndSettle();
      for (final term in ['Detergente', 'demo-002', 'loucas']) {
        await tester.enterText(find.byType(TextField), term);
        if (term == 'demo-002') {
          await tester.tap(find.byTooltip('Pesquisar produtos'));
        } else {
          await tester.testTextInput.receiveAction(TextInputAction.search);
        }
        await tester.pumpAndSettle();
        expect(find.text('Nichos'), findsNothing);
        expect(find.text('Detergente fresh'), findsOneWidget);
        expect(find.text('Multiuso essencial'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byTooltip('Fechar pesquisa'));
      await tester.pumpAndSettle();
      expect(find.text('Nichos'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byTooltip('Pesquisar produtos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pesquisar produtos'));
      await tester.pumpAndSettle();
      expect(find.text('Nichos'), findsOneWidget);
    },
  );
}
