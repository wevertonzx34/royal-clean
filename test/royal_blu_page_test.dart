import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/royal_blu_page.dart';

void main() {
  testWidgets(
    'Tap opens the supplied HTTPS page and retains its text fragment',
    (tester) async {
      Uri? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: RoyalBluPage(
              openLink: (uri) async {
                opened = uri;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('royal-link-blu')));
      await tester.pumpAndSettle();
      expect(opened?.scheme, 'https');
      expect(opened?.host, 'bytes4273.vercel.app');
      expect(opened?.fragment, startsWith(':~:text='));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Zoom covers mobile sizes; centered link remains tappable and back works',
    (tester) async {
      for (final size in [
        const Size(360, 640),
        const Size(430, 932),
        const Size(800, 400),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const MediaQuery(
                        data: MediaQueryData(disableAnimations: true),
                        child: RoyalBluPage(),
                      ),
                    ),
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        final button = find.byKey(const ValueKey('royal-link-blu'));
        expect(
          tester.getCenter(button),
          Offset(size.width / 2, size.height / 2),
        );
        expect(
          tester.getSize(button).height,
          lessThanOrEqualTo(size.height * .5),
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(RoyalBluPage), findsOneWidget);
        await tester.tap(find.byTooltip('Voltar'));
        await tester.pumpAndSettle();
        expect(find.text('Abrir'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}
