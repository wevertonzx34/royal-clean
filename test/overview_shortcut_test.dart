import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/overview_shortcut_royal_clean.dart';

void main() {
  testWidgets('Image opens and closes dashboard without resetting its state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SingleChildScrollView(
              child: OverviewShortcutRoyalClean(child: _Counter()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Consulta 0'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('overview-image-shortcut')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Consulta 0'));
    await tester.pump();
    expect(find.text('Consulta 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('overview-image-shortcut')));
    await tester.pumpAndSettle();
    expect(find.text('Consulta 1'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('overview-image-shortcut')));
    await tester.pumpAndSettle();
    expect(find.text('Consulta 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Counter extends StatefulWidget {
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int value = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => value++),
    child: Text('Consulta $value'),
  );
}
