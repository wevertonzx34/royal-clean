import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:royal_clean/core_royal_clean/services/session_preferences_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/auth/login_page_royal_clean.dart';

class MemoryPreferences extends Fake implements SharedPreferencesAsync {
  final values = <String, bool>{};
  final bool failRead;
  MemoryPreferences({this.failRead = false});
  @override
  Future<bool?> getBool(String key) async {
    if (failRead) throw StateError('Storage unavailable');
    return values[key];
  }

  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }
}

void main() {
  test(
    'Persistent session survives startup, temporary session is cleared before access',
    () async {
      final storage = MemoryPreferences();
      final events = <String>[];
      final preferences = SessionPreferencesRoyalClean(storage: storage);
      Future<void> restore() => preferences.restore(
        signOut: () async {
          events.add('signOut');
        },
        configureWebPersistence: (remember) async {
          events.add('persist:$remember');
        },
      );
      await restore();
      expect(events, ['persist:true']);
      events.clear();
      await preferences.save(false);
      // New service instance simulates reading the choice on the next launch.
      await SessionPreferencesRoyalClean(storage: storage).restore(
        signOut: () async {
          events.add('signOut');
        },
        configureWebPersistence: (remember) async {
          events.add('persist:$remember');
        },
      );
      expect(events, ['signOut', 'persist:false']);
      expect(storage.values, {SessionPreferencesRoyalClean.rememberKey: false});
      events.clear();
      await preferences.save(true);
      await restore();
      expect(events, ['persist:true']);
    },
  );

  test(
    'Unreadable preference prevents startup from exposing a restored session',
    () async {
      final storage = MemoryPreferences(failRead: true);
      await expectLater(
        SessionPreferencesRoyalClean(
          storage: storage,
        ).restore(signOut: () async {}),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'Choice is below social buttons, toggles autofill, and survives reopening login',
    (tester) async {
      final storage = MemoryPreferences();
      final preferences = SessionPreferencesRoyalClean(storage: storage);
      Widget page() => MaterialApp(
        home: LoginPageRoyalClean(sessionPreferences: preferences),
      );
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      expect(
        tester.getTopLeft(find.byType(CheckboxListTile)).dy,
        greaterThan(tester.getBottomLeft(find.text('Continuar com Apple')).dy),
      );
      var fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[0].autofillHints, isNotNull);
      expect(fields[1].autofillHints, isNotNull);
      await tester.ensureVisible(find.text('Manter conectado'));
      await tester.tap(find.text('Manter conectado'));
      await tester.pumpAndSettle();
      fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields[0].autofillHints, isNull);
      expect(fields[1].autofillHints, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
    },
  );

  testWidgets('Social labels stay complete on one line at compact widths', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 360.0, 600.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPageRoyalClean(
            sessionPreferences: SessionPreferencesRoyalClean(
              storage: MemoryPreferences(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['Continuar com Apple', 'Continuar com Google']) {
        final text = tester.widget<Text>(find.text(label));
        expect(text.maxLines, 1);
        expect(text.softWrap, false);
        final rect = tester.getRect(find.text(label));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
      }
      expect(tester.takeException(), isNull);
    }
  });
}
