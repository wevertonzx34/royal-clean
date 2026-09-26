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

class DashboardMetricRoyalClean {
  final String label, unit;
  final bool money;
  final String? unavailable;
  final List<double> values;
  DashboardMetricRoyalClean(Map data)
    : unavailable = data['unavailable'] as String?,
      label = data['label'] as String,
      unit = data['unit'] as String,
      money = data['money'] == true,
      values = (data['values'] as List)
          .map((v) => (v as num).toDouble())
          .toList();
  double get summary => values.fold(0, (sum, value) => sum + value);
  String format(double value) {
    final parts = value.toStringAsFixed(money ? 2 : 0).split('.');
    final integer = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return money ? 'R\$ $integer,${parts.last}' : '$integer $unit';
  }
}
