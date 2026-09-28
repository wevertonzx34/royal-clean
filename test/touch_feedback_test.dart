import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:royal_clean/core_royal_clean/services/touch_feedback_royal_clean.dart';
import 'package:royal_clean/presentation_royal_clean/home/image_action_royal_clean.dart';

void main() {
  testWidgets('Returning shortcut replays its flash without activating again', (
    tester,
  ) async {
    var version = 0;
    var visible = true;
    var activations = 0;
    var flash = 0.0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Visibility(
              visible: visible,
              maintainState: true,
              child: ImageActionRoyalClean(
                replayVersion: version,
                pulses: 2,
                duration: const Duration(milliseconds: 600),
                onActivate: () => activations++,
                builder: (_, value) {
                  flash = value;
                  return const SizedBox(width: 100, height: 100);
                },
              ),
            );
          },
        ),
      ),
    );
    update(() => visible = false);
    await tester.pump();
    update(() {
      visible = true;
      version++;
    });
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(flash, closeTo(1, .001));
    expect(activations, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(flash, closeTo(0, .001));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Native feedback keeps disabled actions disabled and deduplicates nested callbacks',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var actions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: tactileTapRoyalClean(null),
                  child: const Text('Disabled'),
                ),
                TextButton(
                  onPressed: tactileTapRoyalClean(
                    tactileActionRoyalClean(() => actions++),
                  ),
                  child: const Text('Action'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Disabled'));
      await tester.pump();
      expect(calls.where((c) => c.method == 'HapticFeedback.vibrate'), isEmpty);
      await tester.tap(find.text('Action'));
      await tester.pump();
      expect(actions, 1);
      final haptics = calls.where((c) => c.method == 'HapticFeedback.vibrate');
      expect(haptics.length, 1);
      expect(haptics.single.arguments, 'HapticFeedbackType.lightImpact');
    },
  );

  testWidgets(
    'Three flashes complete once; repeated taps and drag do not activate twice',
    (tester) async {
      var actions = 0;
      var flash = 0.0;
      final destination = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageActionRoyalClean(
              pulses: 3,
              duration: const Duration(milliseconds: 900),
              onActivate: () {
                actions++;
                return destination.future;
              },
              builder: (_, value) {
                flash = value;
                return const SizedBox(width: 200, height: 200);
              },
            ),
          ),
        ),
      );
      final action = find.byType(ImageActionRoyalClean);
      await tester.drag(action, const Offset(100, 0));
      await tester.pump();
      expect(actions, 0);
      await tester.tap(action);
      await tester.pump();
      for (var cycle = 0; cycle < 3; cycle++) {
        await tester.pump(const Duration(milliseconds: 150));
        expect(flash, closeTo(1, .001));
        await tester.tap(action);
        await tester.pump(const Duration(milliseconds: 150));
        expect(flash, closeTo(0, .001));
      }
      await tester.pump(const Duration(milliseconds: 1));
      expect(actions, 1);
      await tester.tap(action);
      expect(actions, 1);
      destination.complete();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Door replays three flashes after returning without reopening route',
    (tester) async {
      var flash = 0.0;
      final returnFrames = <double>[];
      var visits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ImageActionRoyalClean(
                pulses: 3,
                duration: const Duration(milliseconds: 900),
                replayAfterActivation: true,
                onActivate: () async {
                  visits++;
                  final route = MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Stock')),
                  );
                  await Navigator.of(context).push(route);
                  await route.completed;
                },
                builder: (_, value) {
                  flash = value;
                  returnFrames.add(value);
                  return const SizedBox(width: 200, height: 200);
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(ImageActionRoyalClean));
      await tester.pumpAndSettle();
      expect(find.text('Stock'), findsOneWidget);
      returnFrames.clear();
      Navigator.of(tester.element(find.text('Stock'))).pop();
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      var peaks = 0;
      var bright = false;
      for (final frame in returnFrames) {
        if (frame > .8 && !bright) peaks++;
        bright = frame > .8;
      }
      expect(peaks, 3);
      expect(flash, closeTo(0, .001));
      expect(visits, 1);
      expect(find.text('Stock'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reduced motion activates immediately and disposed animation never navigates',
    (tester) async {
      var actions = 0;
      Widget host(bool reduced) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: ImageActionRoyalClean(
            onActivate: () => actions++,
            builder: (_, flash) => const SizedBox(width: 100, height: 100),
          ),
        ),
      );
      await tester.pumpWidget(host(true));
      await tester.tap(find.byType(ImageActionRoyalClean));
      await tester.pump();
      expect(actions, 1);
      await tester.pumpWidget(host(false));
      await tester.tap(find.byType(ImageActionRoyalClean));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(actions, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
