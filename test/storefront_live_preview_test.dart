import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/preview/preview_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/royal_catalog_page_royal_clean.dart';

Map<String, dynamic> published(String title) => {
  'id': 'unit1',
  'published': true,
  'royalCatalog': true,
  'title': title,
  'presentation': 'unit',
  'imageUrl': 'assets/preview/royal-store/produtos-royal.webp',
  'description': 'Limpeza para o dia a dia',
  'categories': ['limpeza-profissional'],
  'category': 'limpeza-profissional',
  'niches': ['Dia a dia'],
  'code': 'RC1',
  'measure': '1 litro',
  'unit': 'unidade',
  'pfCents': 2500,
  'pjCents': 2000,
};

void main() {
  testWidgets(
    'Live storefront reuses Preview cards and immediately removes unpublished items',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final feed = StreamController<List<Map<String, dynamic>>>();
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: RepaintBoundary(
              key: capture,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: PreviewStorefrontRoyalClean(products: feed.stream),
                ),
              ),
            ),
          ),
        ),
      );
      feed.add([published('Produto atual')]);
      await tester.pumpAndSettle();
      expect(find.text('NOSSA VITRINE'), findsOneWidget);
      expect(find.text('Produto atual · Unidade'), findsOneWidget);
      expect(find.text('Preço para CNPJ'), findsOneWidget);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      await tester.runAsync(() async {
        final image =
            await (capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'build/vitrine-live-preview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      feed.add([published('Produto atualizado')]);
      await tester.pumpAndSettle();
      expect(find.text('Produto atual · Unidade'), findsNothing);
      expect(find.text('Produto atualizado · Unidade'), findsOneWidget);
      feed.add([
        {...published('Produto atualizado'), 'published': false},
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Produto atualizado · Unidade'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => feed.close());
    },
  );
  testWidgets(
    'Products Vitrine displays preview first and a two-column management grid below',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: RoyalCatalogPageRoyalClean(
            storefront: Stream.value([]),
            load: (_) async => {
              'items': [
                for (var i = 0; i < 2; i++)
                  {
                    'id': 'n_$i',
                    'title': 'Cadastro $i',
                    'audited': true,
                    'description': 'Produto pronto para publicar',
                    'status': 'recipe',
                    'stock': {'boxes': 2, 'loose': 1},
                  },
              ],
              'cursor': null,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PreviewStorefrontRoyalClean), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('audit-product-n_0')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      final first = tester.getRect(
        find.byKey(const ValueKey('audit-product-n_0')),
      );
      final second = tester.getRect(
        find.byKey(const ValueKey('audit-product-n_1')),
      );
      expect(first.top, second.top);
      expect(first.right, lessThan(second.left));
      expect(find.textContaining('2 caixas'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
