import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/core_royal_clean/services/active_contacts_cache_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/active_contacts_page_royal_clean.dart';

Map<String, dynamic> page(int p, {String run = 'r1'}) => {
  'items': [
    {
      'id': '$p',
      'name': 'Contato $p',
      'roles': p == 1 ? ['customer'] : ['supplier'],
      'status': 'A',
    },
  ],
  'total': 2,
  'hasMore': p == 1,
  'catalogRun': run,
  'checkedAt': '2026-09-26T20:00:00Z',
};
void main() {
  test(
    'Prefetch all pages once, filter locally and refresh only at hourly TTL',
    () async {
      var now = DateTime(2026, 9, 26);
      var calls = 0;
      final c = ActiveContactsCacheRoyalClean(
        now: () => now,
        load: (q) async {
          calls++;
          return page(q['page'] as int);
        },
      );
      c.setOwner('admin');
      await Future.wait([c.refresh(), c.refresh()]);
      expect(calls, 2);
      expect(c.rows('all').length, 2);
      expect(c.rows('customer').length, 1);
      await c.refresh();
      expect(calls, 2);
      now = now.add(const Duration(hours: 1));
      await c.refresh();
      expect(calls, 4);
      await c.refresh(force: true);
      expect(calls, 6);
      c.dispose();
    },
  );
  test(
    'Failed or mixed generation preserves complete data; logout discards late response',
    () async {
      var fail = false;
      Completer<Map<String, dynamic>>? delayed;
      final c = ActiveContactsCacheRoyalClean(
        load: (q) async {
          if (delayed != null) return delayed.future;
          if (fail && q['page'] == 2) throw StateError('offline');
          return page(q['page'] as int);
        },
      );
      c.setOwner('a');
      await c.refresh();
      fail = true;
      await c.refresh(force: true);
      expect(c.rows('all').length, 2);
      expect(c.error, isNotNull);
      delayed = Completer();
      final pending = c.refresh(force: true);
      c.setOwner('b');
      delayed.complete(page(1));
      await pending;
      expect(c.hasData, false);
      expect(c.busy, false);
      c.dispose();
    },
  );
  testWidgets(
    'Warm list appears on first frame and remains during background refresh',
    (tester) async {
      var calls = 0;
      Completer<Map<String, dynamic>>? pending;
      final c = ActiveContactsCacheRoyalClean(
        load: (q) async {
          calls++;
          return pending != null ? pending.future : page(q['page'] as int);
        },
      );
      c.setOwner('a');
      await c.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: ActiveContactsPageRoyalClean(role: 'all', cache: c),
        ),
      );
      expect(find.text('Contato 1'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(calls, 2);
      pending = Completer();
      unawaited(c.refresh(force: true));
      await tester.pump();
      expect(find.text('Contato 1'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Contato 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );
}
