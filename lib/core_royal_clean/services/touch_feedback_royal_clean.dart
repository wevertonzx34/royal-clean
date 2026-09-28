import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Native, short tactile feedback. Never blocks or cancels a user action.
class TouchFeedbackRoyalClean {
  static final _clock = Stopwatch()..start();
  static int? _last;
  static bool _sequenceRunning = false;

  static void homePulse() {
    if (_sequenceRunning) return;
    _sequenceRunning = true;
    unawaited(() async {
      try {
        await HapticFeedback.vibrate();
        await Future<void>.delayed(const Duration(milliseconds: 220));
        await HapticFeedback.heavyImpact();
      } catch (_) {
        // Unsupported haptics must never interrupt navigation.
      } finally {
        _sequenceRunning = false;
      }
    }());
  }

  static void pulse() {
    final now = _clock.elapsedMilliseconds;
    if (_last != null && now - _last! < 100) return;
    _last = now;
    unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
  }
}

VoidCallback? tactileTapRoyalClean(VoidCallback? action) => action == null
    ? null
    : () {
        TouchFeedbackRoyalClean.pulse();
        action();
      };

ValueChanged<T>? tactileValueRoyalClean<T>(ValueChanged<T>? action) =>
    action == null
    ? null
    : (value) {
        TouchFeedbackRoyalClean.pulse();
        action(value);
      };

VoidCallback tactileActionRoyalClean(VoidCallback action) =>
    tactileTapRoyalClean(action)!;

ValueChanged<T> tactileSelectionRoyalClean<T>(ValueChanged<T> action) =>
    tactileValueRoyalClean(action)!;

/// Covers framework-generated back buttons and popup/menu opening actions.
class TouchNavigationObserverRoyalClean extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) TouchFeedbackRoyalClean.pulse();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    TouchFeedbackRoyalClean.pulse();
  }
}
