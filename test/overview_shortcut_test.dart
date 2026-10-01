import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/presentation_royal_clean/home/overview_shortcut_royal_clean.dart';

void main() {
  testWidgets(
    'Home tap only flashes; hold opens property and closes overview without resetting state',
    (tester) async {
      final open = ValueNotifier(false);
      final light = ValueNotifier(0);
      var visits = 0;
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: OverviewShortcutRoyalClean(
                height: 800,
                openState: open,
                lightFaultSignal: light,
                onHomeActivate: () async {
                  visits++;
                },
                overlayTopInset: 100,
                foreground: const Positioned(
                  bottom: 0,
                  left: 0,
                  child: Text('Porta'),
                ),
                child: _Counter(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(200, 50));
      await tester.pumpAndSettle();
      expect(open.value, false);
      expect(find.text('Consulta 0'), findsNothing);
      expect(visits, 0);
      expect(light.value, 1);
      open.value = true;
      await tester.pumpAndSettle();
      expect(find.text('Porta'), findsNothing);
      await tester.tap(find.text('Consulta 0'));
      await tester.pump();
      expect(find.text('Consulta 1'), findsOneWidget);
      await tester.longPressAt(const Offset(200, 50));
      await tester.pumpAndSettle();
      expect(open.value, false);
      expect(find.text('Porta'), findsOneWidget);
      expect(visits, 1);
      open.value = true;
      await tester.pumpAndSettle();
      expect(find.text('Consulta 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      open.dispose();
      light.dispose();
      expect(tester.takeException(), isNull);
    },
  );
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
