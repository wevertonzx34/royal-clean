import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dashboard_data_royal_clean.dart';

enum DashboardChartStyleRoyalClean { bars, line, area }

class DashboardChartRoyalClean extends StatefulWidget {
  final double availableHeight;
  const DashboardChartRoyalClean({super.key, this.availableHeight = 720});
  @override
  State<DashboardChartRoyalClean> createState() => _DashboardChartState();
}

class _DashboardChartState extends State<DashboardChartRoyalClean> {
  String _group = 'Produtos';
  int _metric = 0, _month = 5;
  DashboardPeriodRoyalClean _period = DashboardPeriodRoyalClean.monthly;
  DashboardChartStyleRoyalClean _style = DashboardChartStyleRoyalClean.area;
  static const _text = Color(0xFFF5F7FA);
  static const _muted = Color(0xFFA9C3D3);
  static const _accent = Color(0xFF4D8DFF);

  @override
  Widget build(BuildContext context) {
    final metrics = dashboardMetricsRoyalClean[_group]!;
    final metric = metrics[_metric];
    final series = dashboardSeriesRoyalClean(metric, _period);
    return Container(
      key: const ValueKey('admin-dashboard-chart'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF102B3D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF25485F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'Visão geral',
                style: TextStyle(
                  color: _text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Chip(
                avatar: Icon(Icons.science_outlined, size: 16, color: _muted),
                label: Text(
                  'Demonstrativo',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                backgroundColor: Color(0xFF18394D),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dados simulados • ${series.range}',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (final group in dashboardMetricsRoyalClean.keys)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: TextButton(
                      onPressed: () => setState(() {
                        _group = group;
                        _metric = 0;
                        _month =
                            dashboardSeriesRoyalClean(
                              dashboardMetricsRoyalClean[_group]![_metric],
                              _period,
                            ).values.length -
                            1;
                      }),
                      style: TextButton.styleFrom(
                        foregroundColor: _text,
                        backgroundColor: group == _group
                            ? const Color(0xFF17628B)
                            : const Color(0xFF19394D),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          group,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey(_group),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var index = 0; index < metrics.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(metrics[index].label),
                            selected: index == _metric,
                            selectedColor: const Color(0xFF244E73),
                            backgroundColor: const Color(0xFF102B3D),
                            labelStyle: const TextStyle(color: _text),
                            onSelected: (_) => setState(() {
                              _metric = index;
                              _month =
                                  dashboardSeriesRoyalClean(
                                    dashboardMetricsRoyalClean[_group]![_metric],
                                    _period,
                                  ).values.length -
                                  1;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Tooltip(
                message: 'Deslize os indicadores para ver mais',
                child: Icon(Icons.swipe_rounded, size: 20, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '$_group • ${metric.label}',
            style: const TextStyle(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            metric.format(series.summary(metric.cumulative)),
            key: const ValueKey('dashboard-total'),
            style: const TextStyle(
              color: _text,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            metric.cumulative
                ? 'Total no período exibido'
                : 'Posição no último intervalo',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Toque no gráfico para consultar',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry
                      in <DashboardChartStyleRoyalClean, (IconData, String)>{
                        DashboardChartStyleRoyalClean.bars: (
                          Icons.bar_chart_rounded,
                          'Barras',
                        ),
                        DashboardChartStyleRoyalClean.line: (
                          Icons.show_chart_rounded,
                          'Linha',
                        ),
                        DashboardChartStyleRoyalClean.area: (
                          Icons.area_chart_outlined,
                          'Área',
                        ),
                      }.entries)
                    IconButton(
                      tooltip: entry.value.$2,
                      isSelected: _style == entry.key,
                      style: IconButton.styleFrom(
                        foregroundColor: _muted,
                        highlightColor: _accent,
                      ),
                      selectedIcon: Icon(entry.value.$1, color: _accent),
                      icon: Icon(entry.value.$1),
                      onPressed: () => setState(() => _style = entry.key),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<DashboardPeriodRoyalClean>(
            key: const ValueKey('dashboard-period'),
            initialValue: _period,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Período do gráfico',
              prefixIcon: Icon(Icons.calendar_month_outlined),
            ),
            items: [
              for (final period in DashboardPeriodRoyalClean.values)
                DropdownMenuItem(value: period, child: Text(period.label)),
            ],
            onChanged: (period) {
              if (period == null) return;
              setState(() {
                _period = period;
                _month =
                    dashboardSeriesRoyalClean(metric, period).values.length - 1;
              });
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: (widget.availableHeight - 420).clamp(220.0, 520.0),
            child: LayoutBuilder(
              builder: (context, constraints) => Semantics(
                label:
                    '${metric.label}, ${series.details[_month]}: ${metric.format(series.values[_month])}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final fraction =
                        ((details.localPosition.dx - 48) /
                                (constraints.maxWidth - 60))
                            .clamp(0.0, 1.0);
                    setState(
                      () => _month = math.min(
                        series.values.length - 1,
                        (fraction * series.values.length).floor(),
                      ),
                    );
                  },
                  child: CustomPaint(
                    painter: _DashboardPainter(
                      series.values,
                      series.labels,
                      _month,
                      _style,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                series.details[_month],
                style: const TextStyle(color: _muted),
              ),
              Text(
                metric.format(series.values[_month]),
                key: const ValueKey('dashboard-month-value'),
                style: const TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: _period == DashboardPeriodRoyalClean.monthly
                    ? 'Mês anterior'
                    : 'Intervalo anterior',
                onPressed: _month > 0 ? () => setState(() => _month--) : null,
                icon: const Icon(Icons.chevron_left, color: _muted),
              ),
              IconButton(
                tooltip: _period == DashboardPeriodRoyalClean.monthly
                    ? 'Próximo mês'
                    : 'Próximo intervalo',
                onPressed: _month < series.values.length - 1
                    ? () => setState(() => _month++)
                    : null,
                icon: const Icon(Icons.chevron_right, color: _muted),
              ),
            ],
          ),
          Text(
            _group == 'Produtos' && metric.label == 'Fluxos'
                ? 'Fluxos: entradas menos saídas em cada intervalo. Exemplo sem vínculo com o estoque real.'
                : 'Prévia de estrutura. Os valores serão sincronizados com os módulos correspondentes.',
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _DashboardPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final int selected;
  final DashboardChartStyleRoyalClean style;
  _DashboardPainter(this.values, this.labels, this.selected, this.style);
  static const _blue = Color(0xFF4D8DFF);
  void _label(
    Canvas canvas,
    String value,
    Offset offset,
    double width, {
    bool right = false,
  }) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: const TextStyle(color: Color(0xFFA9C3D3), fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
      textAlign: right ? TextAlign.right : TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    )..layout(minWidth: width, maxWidth: width);
    text.paint(canvas, offset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(48, 14, size.width - 12, size.height - 30);
    final maximum = math.max(1.0, values.reduce(math.max) * 1.2);
    final step = plot.width / values.length;
    final grid = Paint()
      ..color = const Color(0xFF365061)
      ..strokeWidth = 1;
    for (var tick = 0; tick <= 4; tick++) {
      final y = plot.bottom - plot.height * tick / 4;
      for (double x = plot.left; x < plot.right; x += 10) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 4, plot.right), y),
          grid,
        );
      }
      final value = maximum * tick / 4;
      _label(
        canvas,
        value >= 1000
            ? '${(value / 1000).toStringAsFixed(1).replaceAll('.', ',')} mil'
            : value.toStringAsFixed(0),
        Offset(0, y - 7),
        40,
        right: true,
      );
    }
    final points = List.generate(
      values.length,
      (index) => Offset(
        plot.left + step * (index + .5),
        plot.bottom - plot.height * values[index] / maximum,
      ),
    );
    if (style == DashboardChartStyleRoyalClean.bars) {
      for (var i = 0; i < points.length; i++) {
        final rect = Rect.fromLTRB(
          points[i].dx - step * .23,
          points[i].dy,
          points[i].dx + step * .23,
          plot.bottom,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                i == selected ? const Color(0xFF8AB7FF) : _blue,
                const Color(0xFF2358B9),
              ],
            ).createShader(rect),
        );
      }
    } else {
      final line = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        line.lineTo(point.dx, point.dy);
      }
      if (style == DashboardChartStyleRoyalClean.area) {
        final area = Path.from(line)
          ..lineTo(points.last.dx, plot.bottom)
          ..lineTo(points.first.dx, plot.bottom)
          ..close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xAA3478EF), Color(0x053478EF)],
            ).createShader(plot),
        );
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = _blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawCircle(
        points[selected],
        5,
        Paint()..color = const Color(0xFFB8D5FF),
      );
    }
    for (var i = 0; i < points.length; i++) {
      _label(
        canvas,
        labels[i],
        Offset(plot.left + step * i, plot.bottom + 10),
        step,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashboardPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.labels != labels ||
      oldDelegate.selected != selected ||
      oldDelegate.style != style;
}
