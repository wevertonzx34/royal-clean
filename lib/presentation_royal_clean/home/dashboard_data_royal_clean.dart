/// Demonstration only: never used as inventory, billing or account records.
class DashboardMetricRoyalClean {
  final String label, unit;
  final List<double> values;
  final bool money, cumulative;
  const DashboardMetricRoyalClean(
    this.label,
    this.unit,
    this.values, {
    this.money = false,
    this.cumulative = false,
  });
  double get summary => cumulative
      ? values.fold<double>(0, (total, value) => total + value)
      : values.last;
  String get summaryLabel =>
      cumulative ? 'Total no período' : 'Posição em setembro';
  String format(double value) {
    final parts = value.toStringAsFixed(money ? 2 : 0).split('.');
    final integer = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return money ? 'R\$ $integer,${parts.last}' : '$integer $unit';
  }
}

const dashboardMonthsRoyalClean = ['Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set'];

enum DashboardPeriodRoyalClean {
  daily('Diário'),
  weekly('Semanal'),
  monthly('Mensal'),
  quarterly('Trimestral'),
  halfYear('Semestral'),
  yearly('Anual');

  final String label;
  const DashboardPeriodRoyalClean(this.label);
}

class DashboardSeriesRoyalClean {
  final List<String> labels, details;
  final List<double> values;
  final String range;
  const DashboardSeriesRoyalClean(
    this.labels,
    this.details,
    this.values,
    this.range,
  );
  double summary(bool cumulative) => cumulative
      ? values.fold<double>(0, (sum, value) => sum + value)
      : values.last;
}

/// Aggregates the same demo base. Movements are summed; status counts use the
/// closing position, never the sum of account/token snapshots.
DashboardSeriesRoyalClean dashboardSeriesRoyalClean(
  DashboardMetricRoyalClean metric,
  DashboardPeriodRoyalClean period,
) {
  double aggregate(int start, int end) => metric.cumulative
      ? metric.values
            .sublist(start, end)
            .fold<double>(0, (sum, value) => sum + value)
      : metric.values[end - 1];
  // Distribute September movements using integer units/cents, preserving totals.
  double dayValue(int day) {
    if (!metric.cumulative) {
      return (metric.values[4] +
              (metric.values[5] - metric.values[4]) * day / 30)
          .roundToDouble();
    }
    final scale = metric.money ? 100 : 1;
    if (metric.label == 'Fluxos') {
      double movement(double total) =>
          (total * day / 30).floorToDouble() -
          (total * (day - 1) / 30).floorToDouble();
      final products = dashboardMetricsRoyalClean['Produtos']!;
      return movement(products[0].values.last) -
          movement(products[1].values.last);
    }
    final total = (metric.values.last * scale).round();
    return ((total * day / 30).floor() - (total * (day - 1) / 30).floor()) /
        scale;
  }

  switch (period) {
    case DashboardPeriodRoyalClean.daily:
      return DashboardSeriesRoyalClean(
        [for (var day = 24; day <= 30; day++) '$day/09'],
        [for (var day = 24; day <= 30; day++) '$day/09/2026'],
        [for (var day = 24; day <= 30; day++) dayValue(day)],
        '24 a 30 de setembro de 2026',
      );
    case DashboardPeriodRoyalClean.weekly:
      // Calendar weeks (Monday–Sunday), clipped to the September sample.
      const bounds = [(1, 6), (7, 13), (14, 20), (21, 27), (28, 30)];
      return DashboardSeriesRoyalClean(
        [for (final bound in bounds) '${bound.$1}–${bound.$2}'],
        [for (final bound in bounds) '${bound.$1} a ${bound.$2}/09/2026'],
        [
          for (final bound in bounds)
            metric.cumulative
                ? [
                    for (var day = bound.$1; day <= bound.$2; day++)
                      dayValue(day),
                  ].fold<double>(0, (sum, value) => sum + value)
                : dayValue(bound.$2),
        ],
        'Setembro de 2026 • semanas parciais nas bordas',
      );
    case DashboardPeriodRoyalClean.monthly:
      return DashboardSeriesRoyalClean(
        dashboardMonthsRoyalClean,
        [for (final month in dashboardMonthsRoyalClean) '$month/2026'],
        metric.values,
        'Abril a setembro de 2026',
      );
    case DashboardPeriodRoyalClean.quarterly:
      return DashboardSeriesRoyalClean(
        ['2º tri', '3º tri'],
        ['Abr–Jun/2026', 'Jul–Set/2026'],
        [aggregate(0, 3), aggregate(3, 6)],
        '2º e 3º trimestres de 2026',
      );
    case DashboardPeriodRoyalClean.halfYear:
      return DashboardSeriesRoyalClean(
        ['1º sem', '2º sem'],
        [
          '1º semestre: Abr–Jun/2026 (parcial)',
          '2º semestre: Jul–Set/2026 (parcial)',
        ],
        [aggregate(0, 3), aggregate(3, 6)],
        '2026 • semestres parciais, amostra de abril a setembro',
      );
    case DashboardPeriodRoyalClean.yearly:
      return DashboardSeriesRoyalClean(['2026'], ['2026: Abr–Set (parcial)'], [
        aggregate(0, 6),
      ], '2026 • ano parcial, amostra de abril a setembro');
  }
}

const dashboardMetricsRoyalClean = <String, List<DashboardMetricRoyalClean>>{
  'Produtos': [
    DashboardMetricRoyalClean('Entrada', 'un.', [
      320,
      410,
      360,
      520,
      470,
      610,
    ], cumulative: true),
    DashboardMetricRoyalClean('Saída', 'un.', [
      260,
      340,
      310,
      450,
      420,
      540,
    ], cumulative: true),
    DashboardMetricRoyalClean(
      'Faturamento',
      '',
      [9200, 12400, 11100, 16800, 15400, 21300],
      money: true,
      cumulative: true,
    ),
    DashboardMetricRoyalClean('Fluxos', 'un.', [
      60,
      70,
      50,
      70,
      50,
      70,
    ], cumulative: true),
  ],
  'Usuários': [
    DashboardMetricRoyalClean('Cadastrados', 'usuários', [
      80,
      105,
      142,
      176,
      208,
      246,
    ]),
    DashboardMetricRoyalClean('Convidados', 'usuários', [
      12,
      20,
      28,
      35,
      48,
      62,
    ]),
    DashboardMetricRoyalClean('Ativos', 'usuários', [
      66,
      88,
      120,
      147,
      179,
      216,
    ]),
    DashboardMetricRoyalClean('Desativados', 'usuários', [
      10,
      12,
      16,
      21,
      20,
      21,
    ]),
    DashboardMetricRoyalClean('Observado', 'usuários', [4, 5, 6, 8, 9, 9]),
  ],
  'Tokens': [
    DashboardMetricRoyalClean('Protocolado', 'tokens', [
      15,
      20,
      24,
      30,
      37,
      45,
    ]),
    DashboardMetricRoyalClean('Processando', 'tokens', [6, 10, 8, 14, 11, 16]),
    DashboardMetricRoyalClean('Ativo', 'tokens', [32, 46, 65, 84, 108, 132]),
    DashboardMetricRoyalClean('Vencidos', 'tokens', [5, 8, 12, 18, 25, 31]),
    DashboardMetricRoyalClean('Bloqueado', 'tokens', [1, 3, 2, 5, 4, 6]),
  ],
};
