import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/active_contacts_page_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/dashboard_chart_royal_clean.dart';

void main() {
  testWidgets(
    'Active contacts paginate, long press opens live detail and back preserves list',
    (tester) async {
      final queries = <Map<String, dynamic>>[];
      Future<Map<String, dynamic>> load(Map<String, dynamic> q) async {
        queries.add(q);
        if (q['kind'] == 'contactDetails') {
          return {
            'name': 'Loja exemplo',
            'checkedAt': '2026-09-26T20:00:00Z',
            'sections': [
              {
                'title': 'Identificação',
                'fields': [
                  {'label': 'CPF / CNPJ', 'value': '123456'},
                ],
              },
            ],
          };
        }
        return {
          'items': [
            {
              'id': q['page'] == 1 ? '1' : '2',
              'name': q['page'] == 1 ? 'Loja exemplo' : 'Outra loja',
              'code': 'C1',
              'document': '123456',
            },
          ],
          'page': q['page'],
          'total': 2,
          'hasMore': q['page'] == 1,
          'catalogRun': 'r1',
          'checkedAt': '2026-09-26T20:00:00Z',
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveContactsPageRoyalClean(role: 'customer', load: load),
        ),
      );
      await tester.pumpAndSettle();
      expect(queries.single['contactRole'], 'customer');
      await tester.tap(find.text('Carregar mais contatos'));
      await tester.pumpAndSettle();
      expect(queries.last['catalogRun'], 'r1');
      expect(find.text('Outra loja'), findsOneWidget);
      await tester.longPress(find.byKey(const ValueKey('contact-1')));
      await tester.pumpAndSettle();
      expect(queries.last, {'kind': 'contactDetails', 'contactId': '1'});
      expect(find.text('Cadastro do contato'), findsOneWidget);
      expect(find.text('CPF / CNPJ'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Outra loja'), findsOneWidget);
      expect(queries.length, 3);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Tapping active bar opens filtered contacts and returns to same chart',
    (tester) async {
      final queries = <Map<String, dynamic>>[];
      Future<Map<String, dynamic>> load(Map<String, dynamic> q) async {
        queries.add(q);
        if (q['kind'] == 'activeContacts') {
          return {
            'items': [],
            'total': 0,
            'hasMore': false,
            'catalogRun': 'r1',
          };
        }
        return {
          'records': 3,
          'baseRecords': 3,
          'labels': ['Ativos', 'Inativos', 'Sem mov.', 'Excluídos', 'Outros'],
          'details': ['Ativos', 'Inativos', 'Sem mov.', 'Excluídos', 'Outros'],
          'metrics': [
            {
              'label': 'Cadastros',
              'unit': 'registros',
              'money': false,
              'values': [3, 0, 0, 0, 0],
            },
          ],
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardChartRoyalClean(load: load),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Contatos'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Clientes'));
      await tester.pumpAndSettle();
      final plot = find.byKey(const ValueKey('dashboard-plot'));
      await tester.ensureVisible(plot);
      final rect = tester.getRect(plot);
      await tester.tapAt(
        Offset(rect.left + 48 + (rect.width - 60) / 10, rect.center.dy),
      );
      await tester.pumpAndSettle();
      expect(find.text('Contatos ativos'), findsOneWidget);
      expect(queries.last['contactRole'], 'customer');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Clientes'))
            .selected,
        isTrue,
      );
      expect(find.text('Ativos: 3 registros'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
