import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/order_care_page_royal_clean.dart';

Map<String, dynamic> sample() => {
  'id': '123',
  'revision': 1,
  'status': 'separating',
  'updatedAt': '2026-09-30T12:00:00Z',
  'updatedByName': 'Admin teste',
  'sourceChanged': false,
  'fiscal': {'number': '', 'status': 'Sem NF-e vinculada'},
  'source': {
    'code': 'TEST-123',
    'name': 'Cliente de teste',
    'document': '',
    'date': '2026-09-30',
    'items': [
      {
        'line': '0',
        'description': 'Produto de teste',
        'code': 'SKU',
        'quantity': 10,
        'unit': 'UN',
      },
    ],
  },
  'lines': [
    {
      'line': '0',
      'separated': 0,
      'dispatched': 0,
      'delivered': 0,
      'resolved': 0,
      'checked': false,
      'reason': '',
      'note': '',
      'owner': '',
      'due': '',
      'agreement': '',
      'resolution': '',
    },
  ],
};
void main() {
  testWidgets(
    'Small screen shows original quantities and keeps drafts after failed save',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final requests = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: OrderCareDetailRoyalClean(
            orderId: '123',
            showHeader: false,
            call: (input) async {
              requests.add(input);
              if (input['action'] == 'open') return {'order': sample()};
              throw Exception('offline');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cliente de teste'), findsOneWidget);
      final separated = find.widgetWithText(
        TextFormField,
        'Separado acumulado (inclui o que já saiu)',
      );
      await tester.ensureVisible(separated);
      await tester.enterText(separated, '6');
      await tester.pump();
      final save = find.widgetWithText(FilledButton, 'Salvar alterações');
      await tester.scrollUntilVisible(
        save,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();
      expect(requests.last['lines'][0]['separated'], 6);
      await tester.scrollUntilVisible(
        separated,
        -350,
        scrollable: find.byType(Scrollable).first,
      );
      expect((tester.widget<TextFormField>(separated)).initialValue, '6.0');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Source conflict preserves balances and disables ordinary mutations',
    (tester) async {
      final data = sample()
        ..['sourceChanged'] = true
        ..['latestSource'] = {
          'items': [
            {'quantity': 12},
          ],
        };
      await tester.pumpWidget(
        MaterialApp(
          home: OrderCareDetailRoyalClean(
            orderId: '123',
            showHeader: false,
            call: (_) async => {'order': data},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('saldos anteriores foram preservados'),
        findsOneWidget,
      );
      final save = find.widgetWithText(FilledButton, 'Salvar alterações');
      await tester.scrollUntilVisible(
        save,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
