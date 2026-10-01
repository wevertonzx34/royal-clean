import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/production_orders_page_royal_clean.dart';

// Synthetic data only, never sent to Firebase or Bling.
Map<String, dynamic> order() => {
  'invoice': {
    'id': '123',
    'code': 'TEST-123',
    'status': '5',
    'recipientName': 'Destinatário de teste',
    'date': '2026-09-29 12:00:00',
  },
  'status': 'open',
  'revision': 1,
  'total': 20,
  'createdAt': '2026-09-29T15:00:00Z',
  'updatedAt': '2026-09-29T15:00:00Z',
  'updatedByName': 'Admin teste',
  'items': [
    {
      'line': '0',
      'code': 'TEST',
      'description': 'Produto para teste',
      'unit': 'UN',
      'quantity': 2,
      'unitPrice': 10,
    },
  ],
  'checks': [
    {
      'line': '0',
      'quantity': 0,
      'checked': false,
      'unavailable': false,
      'observation': '',
    },
  ],
};

void main() {
  testWidgets(
    'Verification needs exact manual quantity, explicit check and final confirmation',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ProductionCheckPageRoyalClean(
            invoiceId: '123',
            showHeaderActions: false,
            call: (data) async {
              calls.add(data);
              return {
                'order': {
                  ...order(),
                  if (data['action'] == 'verify') ...{
                    'status': 'verified',
                    'checks': data['checks'],
                  },
                },
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(
        CheckboxListTile,
        'Produto e quantidade conferidos',
      );
      expect(tester.widget<CheckboxListTile>(confirm).onChanged, isNull);
      await tester.enterText(find.byType(TextField).first, '1');
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(confirm).onChanged, isNull);
      await tester.enterText(find.byType(TextField).first, '2');
      await tester.pump();
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pump();
      final finish = find.widgetWithText(FilledButton, 'Concluir • Verificada');
      await tester.ensureVisible(finish);
      await tester.pumpAndSettle();
      await tester.tap(finish);
      await tester.pumpAndSettle();
      expect(calls.length, 1);
      await tester.tap(find.text('Confirmar verificação'));
      await tester.pumpAndSettle();
      expect(calls.last['action'], 'verify');
      expect((calls.last['checks'] as List).single['quantity'], 2);
      await tester.drag(find.byType(ListView), const Offset(0, 1400));
      await tester.pumpAndSettle();
      expect(find.text('Verificada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Missing product remains unchecked and retry preserves entered fields',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProductionCheckPageRoyalClean(
            invoiceId: '123',
            showHeaderActions: false,
            call: (data) async {
              if (data['action'] != 'open') {
                throw Exception('Network unavailable');
              }
              return {'order': order()};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final missing = find.widgetWithText(
        CheckboxListTile,
        'Falta ou indisponibilidade',
      );
      await tester.ensureVisible(missing);
      await tester.tap(missing);
      await tester.pump();
      expect(find.text('Observação obrigatória'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).last,
        'Faltam duas unidades',
      );
      final save = find.text('Salvar conferência em aberto');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'Faltam duas unidades',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Concluir • Verificada'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Detail remains readable at narrow mobile width', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: ProductionCheckPageRoyalClean(
          invoiceId: '123',
          showHeaderActions: false,
          call: (_) async => {'order': order()},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
