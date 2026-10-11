import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/royal_catalog_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/catalog_audit_card_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/nfe_document_royal_clean.dart';

Map<String, dynamic> record() => {
  'id': 'sheet_test',
  'revision': 3,
  'audited': false,
  'status': 'recipe',
  'title': 'Bobina 20 × 30',
  'code': 'B1',
  'measure': '20 × 30 cm',
  'unit': 'bobina',
  'referenceCents': 1800,
  'factorMilli': 1600,
  'unitsPerBox': 12,
  'threshold': 5,
  'stock': {'boxes': 10, 'loose': 0, 'confirmed': false},
  'source': {
    'name': 'Bobina original',
    'code': 'B1',
    'price': 18,
    'unit': 'KG',
  },
  'presentations': [
    {
      'kind': 'unit',
      'costCents': 1000,
      'pfCents': 2000,
      'pjCents': 1800,
      'minCents': 1500,
    },
  ],
};

void main() {
  Future<void> mount(
    WidgetTester tester,
    List<Map<String, dynamic>> requests, {
    GlobalKey? boundary,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundary,
          child: RoyalCatalogEditorRoyalClean(
            id: 'sheet_test',
            readDraft: () async => null,
            saveDraft: (_) async {},
            clearDraft: () async {},
            call: (input) async {
              requests.add(input);
              return record();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Product sheet reuses invoice panels with default image and fixed save actions',
    (tester) async {
      final key = GlobalKey();
      await mount(tester, [], boundary: key);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NfePanelRoyalClean), findsWidgets);
      expect(find.byType(CatalogAuditPlaceholderRoyalClean), findsOneWidget);
      expect(find.text('FICHA DO PRODUTO'), findsOneWidget);
      expect(find.text('Salvar em Receitas').hitTestable(), findsOneWidget);
      expect(find.text('Publicar na vitrine').hitTestable(), findsOneWidget);
      final source = tester.widget<ExpansionTile>(
        find.byKey(const ValueKey('editor-section-source')),
      );
      expect(source.controller!.isExpanded, isFalse);
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final screenshot = await boundary.toImage();
        final bytes = await screenshot.toByteData(
          format: ui.ImageByteFormat.png,
        );
        await File(
          'build/catalog-editor-sheet.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        screenshot.dispose();
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Invalid field in collapsed section blocks save and opens correction',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      await mount(tester, requests);
      final code = find.byWidgetPredicate(
        (w) => w is TextFormField && w.controller?.text == 'B1',
      );
      await tester.enterText(code, '');
      FocusManager.instance.primaryFocus?.unfocus();
      final tile = tester.widget<ExpansionTile>(
        find.byKey(const ValueKey('editor-section-identity')),
      );
      tile.controller!.collapse();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar em Receitas'));
      await tester.pumpAndSettle();
      expect(tile.controller!.isExpanded, isTrue);
      expect(find.text('Preencha este campo'), findsOneWidget);
      expect(requests.map((r) => r['action']), ['get']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Collapsed fields retain exact conversion, shared stock and prices when saving',
    (tester) async {
      final requests = <Map<String, dynamic>>[];
      await mount(tester, requests);
      await tester.tap(find.text('Salvar em Receitas'));
      await tester.pumpAndSettle();
      final save = requests.singleWhere((r) => r['action'] == 'save');
      final product = save['product'] as Map;
      expect(save['revision'], 3);
      expect(product['factorMilli'], 1600);
      expect(product['unitsPerBox'], 12);
      expect(product['initialStock'], {
        'boxes': 10,
        'loose': 0,
        'confirmed': false,
      });
      expect((product['presentations'] as List).single['pjCents'], 1800);
      expect(requests.any((r) => r['action'] == 'publish'), isFalse);
      await tester.tap(find.text('Publicar na vitrine'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Publicar na Nossa Vitrine?'), findsOneWidget);
      expect(requests.any((r) => r['action'] == 'publish'), isFalse);
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
