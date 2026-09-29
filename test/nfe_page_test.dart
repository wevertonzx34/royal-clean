import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/core_royal_clean/services/active_contacts_cache_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/theme/app_theme_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/nfe_document_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/nfe_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/office_shortcut_royal_clean.dart';

// Fictional test fixtures only; never shipped as application data.
const first = <String, dynamic>{
  'id': '1',
  'code': '101',
  'recipientName': 'Destinatário de teste',
  'recipientDocument': '00000000000000',
  'date': '2026-09-01 09:30:00',
  'status': '5',
  'total': 25,
};
const second = <String, dynamic>{
  'id': '2',
  'code': '102',
  'recipientName': 'Outro destinatário de teste',
  'date': '2026-09-02',
  'total': 40,
};
Map<String, dynamic> detail(String id) => {
  'invoice': {'id': id, 'code': id == '1' ? '101' : '102'},
  'items': [
    {
      'description': 'Produto de teste $id',
      'code': 'TEST-$id',
      'unit': 'UN',
      'quantity': 2,
      'unitPrice': 10,
      'total': 20,
    },
  ],
  'total': id == '1' ? 25 : 40,
};

void main() {
  test('Unknown monetary values stay unknown; zero is an actual value', () {
    expect(nfeMoney(null), 'Não informado');
    expect(nfeMoney(double.nan), 'Não informado');
    expect(nfeMoney(0), 'R\$ 0,00');
    expect(nfeMoney(1234.56), 'R\$ 1.234,56');
    expect(nfeQuantity(null), 'Não informado');
  });

  testWidgets('Reference layout is readable on phones and with larger text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [320.0, 432.0, 720.0]) {
      tester.view.physicalSize = Size(width, 960);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemeRoyalClean.theme,
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(width == 320 ? 1.6 : 1),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: NfeDocumentRoyalClean(
                    invoice: first,
                    details: detail('1'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nfe-empty-logo')), findsOneWidget);
      expect(find.text('NF-e'), findsOneWidget);
      expect(find.text('Produto de teste 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -1800),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Empty document has no invented items or totals', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: NfeDocumentRoyalClean()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('R\$ 0,00'), findsNothing);
    expect(
      find.text('Selecione uma NF-e para consultar seus produtos.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Selection ignores a late response from the previous invoice', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    final cache = ActiveContactsCacheRoyalClean(
      kind: 'invoiceCatalog',
      load: (_) async => {
        'items': [first, second],
        'total': 2,
        'hasMore': false,
        'catalogRun': 'test',
      },
    )..setOwner('admin-test');
    await cache.refresh();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeRoyalClean.theme,
        home: NfePageRoyalClean(
          cache: cache,
          showHeaderActions: false,
          loadDetails: (query) => query['invoiceId'] == '1'
              ? pending.future
              : Future.value(detail('2')),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Trocar NF-e • 101'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('NF-e 102'));
    await tester.pumpAndSettle();
    pending.complete(detail('1'));
    await tester.pumpAndSettle();
    final document = tester.widget<NfeDocumentRoyalClean>(
      find.byType(NfeDocumentRoyalClean),
    );
    expect(document.invoice?['id'], '2');
    expect((document.details?['invoice'] as Map)['id'], '2');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    cache.dispose();
  });

  testWidgets('Office activates its destination after the existing feedback', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 191,
            height: 415,
            child: OfficeShortcutRoyalClean(
              onOpen: () async {
                opened++;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('royal-office-shortcut')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Render document preview for visual review', (tester) async {
    // Use a local font for the optional visual artifact, never as app data.
    final previewFont = File('C:/Windows/Fonts/arial.ttf');
    await tester.runAsync(() async {
      if (await previewFont.exists()) {
        final loader = FontLoader('NfePreview')
          ..addFont(previewFont.readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(432, 2400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeRoyalClean.theme.copyWith(
          textTheme: AppThemeRoyalClean.theme.textTheme.apply(
            fontFamily: 'NfePreview',
          ),
        ),
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
            backgroundColor: const Color(0xFF020C20),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: NfeDocumentRoyalClean(
                  invoice: first,
                  details: detail('1'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build').create(recursive: true);
      await File(
        'build/nfe-layout-preview.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
