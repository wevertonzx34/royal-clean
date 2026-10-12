import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../shared/layout_button_royal_clean.dart';
import 'contacts_market_chart_royal_clean.dart';

/// Claim two-finger contact immediately, and regularize axis distances so
/// nearly aligned fingers cannot cause division by zero or explosive zoom.
class _ChartScaleGestureRecognizer extends ScaleGestureRecognizer {
  final positions = <int, Offset>{};
  double axisDistance(bool horizontal) {
    if (positions.length < 2) return 64;
    final pair = positions.values.take(2).toList();
    final delta = horizontal
        ? pair[0].dx - pair[1].dx
        : pair[0].dy - pair[1].dy;
    return math.sqrt(delta * delta + 64 * 64);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerDownEvent || event is PointerMoveEvent) {
      positions[event.pointer] = event.position;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      positions.remove(event.pointer);
    }
    super.handleEvent(event);
    if (event is PointerDownEvent && positions.length >= 2) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void dispose() {
    positions.clear();
    super.dispose();
  }

  @override
  void rejectGesture(int pointer) {
    positions.remove(pointer);
    super.rejectGesture(pointer);
  }
}

/// A viewport-sized canvas: zoom never creates an enormous scrollable bitmap.
class ActivityMarketViewportRoyalClean extends StatefulWidget {
  final List<Map<String, dynamic>> bins;
  final double minimumRange, latestClose;
  final num? selectedStart;
  final num? candleEnd;
  final ValueChanged<num> onSelect;
  final VoidCallback? onNeedOlder;
  const ActivityMarketViewportRoyalClean({
    super.key,
    required this.bins,
    required this.minimumRange,
    required this.latestClose,
    required this.onSelect,
    this.selectedStart,
    this.candleEnd,
    this.onNeedOlder,
  });
  @override
  State<ActivityMarketViewportRoyalClean> createState() =>
      _ActivityViewportState();
}

class _ActivityViewportState extends State<ActivityMarketViewportRoyalClean> {
  double count = 40, end = 0, gestureX = 64, gestureY = 64;
  int gesturePointers = 0;
  Offset gestureFocal = Offset.zero;
  bool followLatest = true;
  (double, double)? cameraRange;
  void resetCamera() => setState(() {
    count = 40;
    followLatest = true;
    cameraRange = null;
    end = widget.bins.length + futureSpace;
  });
  double get futureSpace => count * .18;
  @override
  void initState() {
    super.initState();
    end = widget.bins.length + futureSpace;
  }

  @override
  void didUpdateWidget(covariant ActivityMarketViewportRoyalClean old) {
    super.didUpdateWidget(old);
    if (followLatest) {
      end = widget.bins.length + futureSpace;
    } else if (old.bins.isNotEmpty) {
      final position = widget.bins.indexWhere(
        (b) => b['start'] == old.bins.first['start'],
      );
      if (position >= 0) end += position;
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(1.0, constraints.maxWidth - 84);
          final finish = end.ceil().clamp(0, widget.bins.length);
          final start = (end - count).floor().clamp(0, finish);
          final endOffset = end - finish;
          final visible = widget.bins.sublist(start, finish);
          return RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              _ChartScaleGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    _ChartScaleGestureRecognizer
                  >(
                    () => _ChartScaleGestureRecognizer(),
                    (recognizer) => recognizer
                      ..dragStartBehavior = DragStartBehavior.down
                      // Claim a drag on the chart before the page's vertical scroll.
                      ..gestureSettings = const DeviceGestureSettings(
                        touchSlop: 4,
                      )
                      ..onStart = (d) {
                        gestureX = recognizer.axisDistance(true);
                        gestureY = recognizer.axisDistance(false);
                        gesturePointers = d.pointerCount;
                        gestureFocal = d.localFocalPoint;
                      }
                      ..onUpdate = (d) {
                        setState(() {
                          followLatest = false;
                          // Rebase when a finger joins/leaves to avoid jumps.
                          if (gesturePointers != d.pointerCount) {
                            gesturePointers = d.pointerCount;
                            gestureX = recognizer.axisDistance(true);
                            gestureY = recognizer.axisDistance(false);
                            gestureFocal = d.localFocalPoint;
                          }
                          final distanceX = recognizer.axisDistance(true);
                          final distanceY = recognizer.axisDistance(false);
                          final scaleX = d.pointerCount >= 2
                              ? (distanceX / gestureX).clamp(.5, 2.0)
                              : 1.0;
                          final scaleY = d.pointerCount >= 2
                              ? (distanceY / gestureY).clamp(.5, 2.0)
                              : 1.0;
                          final range =
                              cameraRange ??
                              contactMarketRangeRoyalClean(
                                visible,
                                'Atividade',
                                widget.minimumRange,
                              );
                          final span = range.$2 - range.$1;
                          final nextCount = (count / scaleX).clamp(
                            8.0,
                            math.max(1440.0, widget.bins.length + 256.0),
                          );
                          final ratioX = (gestureFocal.dx - 12) / width;
                          final deltaX = d.localFocalPoint.dx - gestureFocal.dx;
                          end =
                              (end +
                                      (nextCount - count) * (1 - ratioX) -
                                      deltaX / width * nextCount)
                                  .clamp(
                                    math.min(
                                      nextCount * .2,
                                      widget.bins.length.toDouble(),
                                    ),
                                    widget.bins.length + nextCount * .85,
                                  );
                          count = nextCount.toDouble();
                          final anchorY =
                              range.$2 - (gestureFocal.dy - 22) / 215 * span;
                          final nextSpan = (span / scaleY).clamp(
                            math.max(.00000001, widget.minimumRange / 100),
                            100000000.0,
                          );
                          final high =
                              anchorY +
                              (d.localFocalPoint.dy - 22) / 215 * nextSpan;
                          cameraRange = (high - nextSpan, high);
                          gestureX = distanceX;
                          gestureY = distanceY;
                          gestureFocal = d.localFocalPoint;
                        });
                      }
                      ..onEnd = (_) {
                        if (end - count <= 16) widget.onNeedOlder?.call();
                      },
                  ),
              DoubleTapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    DoubleTapGestureRecognizer
                  >(
                    () => DoubleTapGestureRecognizer(),
                    (recognizer) => recognizer..onDoubleTap = resetCamera,
                  ),
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                    () => TapGestureRecognizer(),
                    (recognizer) => recognizer
                      ..onTapUp = (d) {
                        final step = width / count;
                        final index =
                            ((d.localPosition.dx - 12) / step -
                                    (count - visible.length - endOffset))
                                .floor();
                        if (d.localPosition.dx >= 12 &&
                            d.localPosition.dx <= constraints.maxWidth - 72 &&
                            d.localPosition.dy >= 22 &&
                            d.localPosition.dy <= 237 &&
                            index >= 0 &&
                            index < visible.length) {
                          widget.onSelect(visible[index]['start'] as num);
                        }
                      },
                  ),
            },
            child: Semantics(
              label:
                  'Gráfico de atividade em pontos. Zoom: ${count.round()} candles. Use dois dedos para ampliar ou reduzir.',
              child: RepaintBoundary(
                child: SizedBox(
                  height: 320,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: ContactsMarketPainterRoyalClean(
                              bins: visible,
                              category: 'Atividade',
                              capacity: count,
                              endOffset: endOffset,
                              cameraRange: cameraRange,
                              minimumRange: widget.minimumRange,
                              latestClose: widget.latestClose,
                              selected: visible.indexWhere(
                                (b) => b['start'] == widget.selectedStart,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.candleEnd != null)
                        Positioned(
                          right: 0,
                          top: 248,
                          width: 72,
                          child: _CandleCountdownRoyalClean(
                            end: widget.candleEnd!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Arraste livre • Dois dedos: zoom • 2 toques: restaurar',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
          LayoutButtonRoyalClean(
            id: 'performance.activity.index.zoom.reset',
            child: IconButton(
              tooltip: 'Últimos candles e zoom padrão',
              icon: const Icon(Icons.center_focus_strong),
              onPressed: resetCamera,
            ),
          ),
        ],
      ),
    ],
  );
}

String candleCountdownRoyalClean(num end, DateTime now) {
  final seconds = math.max(
    0,
    ((end - now.millisecondsSinceEpoch) / 1000).ceil(),
  );
  if (seconds == 0) return 'Encerrado';
  String two(int value) => value.toString().padLeft(2, '0');
  final days = seconds ~/ 86400;
  final time =
      '${two(seconds ~/ 3600 % 24)}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}';
  return days > 0 ? '${days}d\n$time' : time;
}

/// Only this small label ticks each second; the chart does not repaint for it.
class _CandleCountdownRoyalClean extends StatefulWidget {
  final num end;
  const _CandleCountdownRoyalClean({required this.end});
  @override
  State<_CandleCountdownRoyalClean> createState() => _CandleCountdownState();
}

class _CandleCountdownState extends State<_CandleCountdownRoyalClean> {
  late final Timer timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      label: 'Tempo para fechar o candle',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF0B3041),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF9DE5F7).withValues(alpha: .6),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'FECHA EM',
              style: TextStyle(fontSize: 8, color: Colors.white70),
            ),
            Text(
              candleCountdownRoyalClean(widget.end, DateTime.now()),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9DE5F7),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
