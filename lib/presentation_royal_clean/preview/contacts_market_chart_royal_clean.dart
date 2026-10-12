import 'dart:math' as math;
import 'package:flutter/material.dart';

const _blue = Color(0xFF9DE5F7), _pink = Color(0xFFF5B0D1);

/// Zero has no bar height; a baseline tick identifies that observed period.
double activityVolumeHeightRoyalClean(double volume, double maximum) =>
    volume <= 0 ? 0 : math.max(2.0, volume / math.max(.000001, maximum) * 24);

class ContactMarketCandleRoyalClean {
  final double open, high, low, close, positive, negative, movement;
  final bool paired;
  const ContactMarketCandleRoyalClean(
    this.open,
    this.high,
    this.low,
    this.close,
    this.positive,
    this.negative,
    this.movement,
    this.paired,
  );
}

ContactMarketCandleRoyalClean? contactMarketCandleRoyalClean(
  Map<String, dynamic> b,
  String category,
) {
  double n(String k) => (b[k] as num? ?? 0).toDouble();
  if (category == 'Players') {
    final open = n('playersOpen'),
        up = open + n('registered'),
        down = n('deleted') + n('pending');
    return ContactMarketCandleRoyalClean(
      open,
      up,
      math.min(open, up - down),
      up - down,
      n('registered'),
      down,
      n('registered') + down,
      true,
    );
  }
  if (category == 'Atividade') {
    if (b['activityClose'] == null && b['online'] == null) return null;
    final open = (b['activityOpen'] as num? ?? b['online'] as num).toDouble();
    final close = (b['activityClose'] as num? ?? b['online'] as num).toDouble();
    final high = (b['activityHigh'] as num? ?? math.max(open, close))
        .toDouble();
    final low = (b['activityLow'] as num? ?? math.min(open, close)).toDouble();
    return ContactMarketCandleRoyalClean(
      open,
      high,
      low,
      close,
      math.max(0, close - open),
      math.max(0, open - close),
      (b['volume'] as num?)?.toDouble() ?? high - low,
      false,
    );
  }
  final count = n(switch (category) {
    'Processando' => 'pending',
    'Deletados' => 'deleted',
    _ => 'registered',
  });
  return ContactMarketCandleRoyalClean(
    0,
    count,
    0,
    count,
    count,
    0,
    count,
    false,
  );
}

/// The manual camera and painter share the same scale.
(double, double) contactMarketRangeRoyalClean(
  List<Map<String, dynamic>> bins,
  String category,
  double minimumRange,
) {
  final valid = bins
      .map((b) => contactMarketCandleRoyalClean(b, category))
      .whereType<ContactMarketCandleRoyalClean>()
      .toList();
  if (valid.isEmpty) return (99.5, 100.5);
  var low = valid.map((v) => v.low).reduce(math.min);
  var high = valid.map((v) => v.high).reduce(math.max);
  if (category != 'Players' && category != 'Atividade') low = 0;
  if (high - low < minimumRange) {
    final middle = (high + low) / 2;
    low = middle - minimumRange / 2;
    high = middle + minimumRange / 2;
  }
  final points = bins.any((b) => b['indexPoints'] == true);
  final padding = math.max(points ? .00001 : 1.0, (high - low) * .16);
  return (low - padding, high + padding);
}

/// Small bounded canvas, no timers or synthetic market data.
class ContactsMarketPainterRoyalClean extends CustomPainter {
  final List<Map<String, dynamic>> bins;
  final String category;
  final int selected;
  final double minimumRange;
  final double? capacity, latestClose;
  final double endOffset;
  final (double, double)? cameraRange;
  ContactsMarketPainterRoyalClean({
    required this.bins,
    required this.category,
    this.selected = -1,
    this.minimumRange = 0,
    this.capacity,
    this.latestClose,
    this.endOffset = 0,
    this.cameraRange,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final data = bins
        .map((b) => contactMarketCandleRoyalClean(b, category))
        .toList();
    final valid = data.whereType<ContactMarketCandleRoyalClean>().toList();
    if (valid.isEmpty) return;
    final indexed = category == 'Players' || category == 'Atividade';
    final points = bins.any((b) => b['indexPoints'] == true);
    final range =
        cameraRange ??
        contactMarketRangeRoyalClean(bins, category, minimumRange);
    final low = range.$1, high = range.$2;
    final left = points ? 12.0 : 42.0, right = points ? 72.0 : 38.0;
    const top = 22.0;
    final bottom = size.height - 83,
        count = math.max(1.0, capacity ?? bins.length.toDouble()),
        step = (size.width - left - right) / count;
    double y(double value) =>
        top + (high - value) / (high - low) * (bottom - top);
    double x(int i) => left + step * (count - bins.length - endOffset + i + .5);
    final dense = points && step < 3;
    final halfBody = points ? math.min(5.0, step * .32) : 5.0;
    void text(
      String value,
      double cx,
      double cy,
      Color color, {
      double font = 9,
    }) {
      final p = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(color: color, fontSize: font),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, Offset(cx - p.width / 2, cy));
    }

    final grid = Paint()
      ..color = const Color(0xFF54DCFA).withValues(alpha: .15)
      ..strokeWidth = .6;
    final marker = data.lastIndexWhere((v) => v != null);
    final markerValue = latestClose ?? (marker >= 0 ? data[marker]!.close : 0);
    for (var j = 0; j <= 5; j++) {
      final value = low + (high - low) * j / 5, py = y(value);
      canvas.drawLine(Offset(left, py), Offset(size.width - right, py), grid);
      if (!points || marker < 0 || (py - y(markerValue)).abs() > 12) {
        text(
          value.toStringAsFixed(points ? 6 : (high - low < 5 ? 1 : 0)),
          points ? size.width - right / 2 : left / 2,
          py - 5,
          Colors.white54,
        );
      }
    }
    if (capacity != null) {
      for (var i = 0; i <= 10; i++) {
        final gx = left + (size.width - left - right) * i / 10;
        canvas.drawLine(Offset(gx, top), Offset(gx, bottom), grid);
      }
    } else {
      for (
        var i = 0;
        i < bins.length;
        i += math.max(1, (bins.length / 10).ceil())
      ) {
        canvas.drawLine(Offset(x(i), top), Offset(x(i), bottom), grid);
      }
    }
    canvas.drawRect(
      Rect.fromLTRB(left, top, size.width - right, bottom),
      Paint()
        ..color = const Color(0xFF69DFF7).withValues(alpha: .4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    final volumeMax = math.max(
      points ? .000001 : 1.0,
      valid.map((v) => v.movement).reduce(math.max),
    );
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(left, top, size.width - right, bottom + 38));
    final closePath = Path();
    var pathConnected = false;
    for (var i = 0; i < data.length; i++) {
      final c = data[i], cx = x(i);
      if (i > 0 && (bins[i]['start'] as num) > (bins[i - 1]['end'] as num)) {
        pathConnected = false;
      }
      if (selected == i) {
        canvas.drawRect(
          Rect.fromLTRB(cx - step / 2, top, cx + step / 2, bottom),
          Paint()..color = Colors.white.withValues(alpha: .07),
        );
      }
      if (c == null) {
        pathConnected = false;
        if (!dense) text('—', cx, (top + bottom) / 2, Colors.white38);
        continue;
      }
      if (dense) {
        if (pathConnected) {
          closePath.lineTo(cx, y(c.close));
        } else {
          closePath.moveTo(cx, y(c.close));
          pathConnected = true;
        }
      }
      void body(double bx, double open, double close, Color color) {
        final rect = Rect.fromLTRB(
          bx - halfBody,
          math.min(y(open), y(close)),
          bx + halfBody,
          math.max(
            math.min(y(open), y(close)) + 1.2,
            math.max(y(open), y(close)),
          ),
        );
        canvas.drawRect(
          rect.inflate(2),
          Paint()..color = color.withValues(alpha: .12),
        );
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              colors: [color, Color.lerp(color, Colors.white, .3)!],
            ).createShader(rect),
        );
        final p = Paint()
          ..color = color
          ..strokeWidth = 1.3;
        if (!points) {
          canvas.drawLine(Offset(bx - 7, y(open)), Offset(bx + 7, y(open)), p);
          canvas.drawLine(
            Offset(bx - 7, y(close)),
            Offset(bx + 7, y(close)),
            p,
          );
        }
      }

      canvas.save();
      canvas.clipRect(Rect.fromLTRB(left, top, size.width - right, bottom));
      if (c.paired) {
        body(cx - 8, c.open, c.open + c.positive, _blue);
        body(cx + 8, c.open + c.positive, c.close, _pink);
      } else if (!dense) {
        final color = category == 'Deletados' || c.close < c.open
            ? _pink
            : _blue;
        canvas.drawLine(
          Offset(cx, y(c.high)),
          Offset(cx, y(c.low)),
          Paint()
            ..color = color
            ..strokeWidth = 1.3,
        );
        body(cx, c.open, c.close, color);
      }
      canvas.restore();
      final color = c.close >= c.open ? _blue : _pink;
      final volumeHeight = points
          ? activityVolumeHeightRoyalClean(c.movement, volumeMax)
          : c.movement / volumeMax * 24;
      if (points && volumeHeight == 0) {
        canvas.drawLine(
          Offset(cx - math.max(1, halfBody), bottom + 37),
          Offset(cx + math.max(1, halfBody), bottom + 37),
          Paint()
            ..color = color
            ..strokeWidth = 1.5,
        );
      }
      canvas.drawRect(
        Rect.fromLTRB(
          cx - halfBody,
          bottom + 37 - volumeHeight,
          cx + halfBody,
          bottom + 37,
        ),
        Paint()..color = color.withValues(alpha: points ? .85 : .55),
      );
    }
    canvas.restore();
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(left, top, size.width - right, bottom));
    if (dense) {
      canvas.drawPath(
        closePath,
        Paint()
          ..color = _blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
    }
    // Moving averages use only complete sequences of observed closes.
    if (indexed) {
      for (final window in [3, 7]) {
        final path = Path();
        var connected = false;
        for (var i = 0; i < data.length; i++) {
          if (i + 1 < window ||
              data.sublist(i + 1 - window, i + 1).any((v) => v == null)) {
            connected = false;
            continue;
          }
          if ([
            for (var j = i + 2 - window; j <= i; j++)
              (bins[j]['start'] as num) > (bins[j - 1]['end'] as num),
          ].any((gap) => gap)) {
            connected = false;
            continue;
          }
          final avg =
              data
                  .sublist(i + 1 - window, i + 1)
                  .fold<double>(0, (sum, v) => sum + v!.close) /
              window;
          if (connected) {
            path.lineTo(x(i), y(avg));
          } else {
            path.moveTo(x(i), y(avg));
            connected = true;
          }
        }
        final color = window == 3
            ? const Color(0xFF42F5EA)
            : const Color(0xFFB7A0FF);
        canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: .15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3,
        );
      }
    }
    canvas.restore();
    if (indexed &&
        marker >= 0 &&
        y(markerValue) >= top &&
        y(markerValue) <= bottom) {
      final py = y(markerValue),
          p = Paint()
            ..color = Colors.white.withValues(alpha: .85)
            ..strokeWidth = 1;
      for (double dx = left; dx < size.width - right; dx += 6) {
        canvas.drawLine(
          Offset(dx, py),
          Offset(math.min(dx + 2, size.width - right), py),
          p,
        );
      }
      text(
        markerValue.toStringAsFixed(points ? 6 : 0),
        size.width - right / 2,
        py - 12,
        Colors.white,
      );
    }
    text(
      points ? 'VOLUME DE PRESENÇA' : 'MOVIMENTO DO PERÍODO',
      left + 75,
      bottom + 41,
      Colors.white38,
      font: 8,
    );
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(left, bottom + 38, size.width - right, size.height),
    );
    for (
      var i = bins.length - 1;
      i >= 0;
      i -= math.max(1, (50 / step).ceil())
    ) {
      final d = DateTime.fromMillisecondsSinceEpoch(
        (bins[i]['start'] as num).toInt(),
        isUtc: true,
      ).subtract(const Duration(hours: 3));
      final duration = (bins[i]['end'] as num) - (bins[i]['start'] as num);
      text(
        duration >= 360 * 86400000
            ? '${d.year}'
            : duration >= 28 * 86400000
            ? '${d.month}/${d.year.toString().substring(2)}'
            : duration < 86400000
            ? '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'
            : '${d.day}/${d.month}',
        x(i),
        size.height - 22,
        Colors.white70,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ContactsMarketPainterRoyalClean old) =>
      old.bins != bins ||
      old.category != category ||
      old.selected != selected ||
      old.minimumRange != minimumRange ||
      old.capacity != capacity ||
      old.latestClose != latestClose ||
      old.endOffset != endOffset ||
      old.cameraRange != cameraRange;
}
