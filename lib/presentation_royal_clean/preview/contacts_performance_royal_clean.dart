import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../home/dashboard_data_royal_clean.dart';
import '../shared/layout_button_royal_clean.dart';
import 'contacts_market_chart_royal_clean.dart';

const contactPositiveRoyalClean = Color(0xFF9DE5F7);
const contactNegativeRoyalClean = Color(0xFFF5B0D1);
const _categories = [
  'Atividade',
  'Players',
  'Registrados',
  'Processando',
  'Deletados',
];

class ContactsPerformanceRoyalClean extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? load;
  const ContactsPerformanceRoyalClean({super.key, this.load});
  @override
  State<ContactsPerformanceRoyalClean> createState() =>
      _ContactsPerformanceState();
}

class _ContactsPerformanceState extends State<ContactsPerformanceRoyalClean>
    with WidgetsBindingObserver {
  DashboardPeriodRoyalClean _period = DashboardPeriodRoyalClean.daily;
  String _category = 'Players', _style = 'Barras';
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false, _visible = true;
  int _selected = -1, _generation = 0;
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reload());
    if (widget.load == null) {
      _refresh = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_visible && !_busy) unawaited(_reload());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    if (_visible) unawaited(_reload());
  }

  @override
  void dispose() {
    _generation++;
    _refresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final query = <String, dynamic>{'period': _period.name};
      final result = widget.load != null
          ? await widget.load!(query)
          : Map<String, dynamic>.from(
              (await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
                          .httpsCallable(
                            'royalContactsOverview',
                            options: HttpsCallableOptions(
                              timeout: const Duration(seconds: 120),
                            ),
                          )
                          .call(query))
                      .data
                  as Map,
            );
      if (!mounted || generation != _generation) return;
      if (result['source'] != 'royal-clean') {
        throw const FormatException('Origem de contatos inválida.');
      }
      setState(() {
        _data = result;
        final count = (result['bins'] as List? ?? []).length;
        if (_selected >= count) _selected = -1;
      });
    } catch (error) {
      if (!kReleaseMode && error is FirebaseFunctionsException) {
        debugPrint('RoyalClean contacts check: ${error.code}');
      }
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'Não foi possível atualizar os contatos. Tente novamente.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Widget _control(String id, Widget child) =>
      LayoutButtonRoyalClean(id: 'performance.contacts.$id', child: child);
  @override
  Widget build(BuildContext context) {
    final bins = (_data?['bins'] as List? ?? [])
        .map((b) => Map<String, dynamic>.from(b as Map))
        .toList();
    final chosen = bins.isEmpty
        ? null
        : bins[_selected >= 0 ? _selected : bins.length - 1];
    final pair = _category == 'Players' || _category == 'Atividade';
    final values = chosen == null
        ? null
        : contactValuesRoyalClean(chosen, _category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Visão geral',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Contatos • dados oficiais do Royal Clean',
          style: TextStyle(color: Color(0xFFBAA2FF)),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _control(
              'period',
              PopupMenuButton<DashboardPeriodRoyalClean>(
                tooltip: 'Período do gráfico',
                initialValue: _period,
                onSelected: (value) {
                  if (value == _period) return;
                  setState(() {
                    _period = value;
                    _data = null;
                  });
                  unawaited(_reload());
                },
                itemBuilder: (_) => [
                  for (final value in DashboardPeriodRoyalClean.values)
                    CheckedPopupMenuItem(
                      value: value,
                      checked: _period == value,
                      child: Text(value.label),
                    ),
                ],
                child: Chip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(_period.label),
                ),
              ),
            ),
            _control(
              'style',
              PopupMenuButton<String>(
                tooltip: 'Estilo do gráfico',
                initialValue: _style,
                onSelected: (value) => setState(() => _style = value),
                itemBuilder: (_) => [
                  for (final value in ['Barras', 'Linha', 'Área'])
                    CheckedPopupMenuItem(
                      value: value,
                      checked: _style == value,
                      child: Text(value),
                    ),
                ],
                child: Chip(
                  avatar: const Icon(Icons.bar_chart, size: 18),
                  label: Text(_style),
                ),
              ),
            ),
            _control(
              'refresh',
              IconButton(
                tooltip: 'Atualizar contatos',
                onPressed: _busy ? null : () => unawaited(_reload()),
                icon: const Icon(Icons.refresh),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final category in _categories)
              _control(
                'category.${category.toLowerCase()}',
                ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  selectedColor: const Color(0xFF635091),
                  onSelected: (_) => setState(() {
                    _category = category;
                    _selected = -1;
                  }),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: contactNegativeRoyalClean),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF123F53),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF7568A1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _category,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _legend(_category),
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              if (chosen != null &&
                  (_category == 'Players' || _category == 'Atividade')) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_category == 'Players') ...[
                      _indicator(
                        'Base de cadastros',
                        '${chosen['playersOpen'] ?? 0}',
                        contactPositiveRoyalClean,
                      ),
                      _indicator(
                        'Índice Players',
                        '${chosen['playersClose'] ?? (values == null ? 0 : values.$1 - values.$2)}',
                        const Color(0xFFB7A0FF),
                      ),
                    ] else if (values != null) ...[
                      _indicator(
                        'Máxima observada',
                        '${chosen['activityHigh'] ?? chosen['online']}',
                        contactPositiveRoyalClean,
                      ),
                      _indicator(
                        'Mínima observada',
                        '${chosen['activityLow'] ?? chosen['online']}',
                        contactNegativeRoyalClean,
                      ),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: CircularProgressIndicator(
                                value: values.$1 + values.$2 == 0
                                    ? 0
                                    : values.$1 / (values.$1 + values.$2),
                                strokeWidth: 4,
                                color: contactPositiveRoyalClean,
                                backgroundColor: contactNegativeRoyalClean
                                    .withValues(alpha: .3),
                              ),
                            ),
                            Text(
                              '${values.$1 + values.$2 == 0 ? 0 : (100 * values.$1 / (values.$1 + values.$2)).round()}%',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'Presença',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (_style != 'Barras')
                const SizedBox(
                  height: 220,
                  child: Center(
                    child: Text(
                      'As regras de Linha e Área serão definidas na próxima etapa.\nUse Barras para consultar os dados atuais.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (bins.isEmpty)
                SizedBox(
                  height: 220,
                  child: Center(
                    child: Text(
                      _busy
                          ? 'Consultando registros…'
                          : 'Nenhum período disponível.',
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = math.max(
                      constraints.maxWidth,
                      bins.length * 58.0,
                    );
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: GestureDetector(
                        onTapUp: (event) => setState(
                          () => _selected =
                              ((event.localPosition.dx - 42) /
                                      ((width - 80) / bins.length))
                                  .floor()
                                  .clamp(0, bins.length - 1),
                        ),
                        child: CustomPaint(
                          key: const ValueKey('contacts-performance-plot'),
                          size: Size(width, 320),
                          painter: ContactsMarketPainterRoyalClean(
                            bins: bins,
                            category: _category,
                            selected: _selected,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (chosen != null && _style == 'Barras') ...[
                const Divider(color: Colors.white24),
                Text(
                  '${_date(chosen['start'])} – ${_date((chosen['end'] as num).toInt() - 1)} • ${chosen['closed'] == true ? 'Período encerrado' : 'Em andamento'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                if (values == null)
                  const Text('Sem histórico de presença neste período.')
                else ...[
                  Text(
                    '${_category == 'Atividade'
                        ? 'Online'
                        : pair
                        ? 'Positiva'
                        : _category}: ${values.$1}',
                    style: const TextStyle(color: contactPositiveRoyalClean),
                  ),
                  if (pair)
                    Text(
                      '${_category == 'Atividade' ? 'Ausentes' : 'Negativa'}: ${values.$2}',
                      style: const TextStyle(color: contactNegativeRoyalClean),
                    ),
                  if (_category == 'Players')
                    Text(
                      'Abertura: ${chosen['playersOpen'] ?? 0} → fechamento positivo: ${chosen['playersPositiveClose'] ?? values.$1}\nAbertura negativa: ${chosen['playersPositiveClose'] ?? values.$1} → fechamento do índice: ${chosen['playersClose'] ?? values.$1 - values.$2}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  if (_category == 'Players' &&
                      (chosen['playersBaseAdjustment'] as num? ?? 0) != 0)
                    Text(
                      'Ajuste de base: ${chosen['playersBaseAdjustment']} • abertura pelo total real de cadastros, sem descontar convites.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  if (_category == 'Atividade')
                    Text(
                      'Índice de presença • Abertura: ${chosen['activityOpen'] ?? chosen['online']} • Fechamento: ${chosen['activityClose'] ?? chosen['online']}\nMáxima observada: ${chosen['activityHigh'] ?? chosen['online']} • Mínima observada: ${chosen['activityLow'] ?? chosen['online']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  if (_category == 'Atividade' &&
                      chosen['activityPartial'] == true)
                    const Text(
                      'Período com cobertura parcial de presença.',
                      style: TextStyle(
                        fontSize: 12,
                        color: contactNegativeRoyalClean,
                      ),
                    ),
                ],
                if (_category == 'Players')
                  Text(
                    'Registrados: ${chosen['registered']} • Convites pendentes: ${chosen['pending']} • Exclusões registradas: ${chosen['deleted']}',
                    style: const TextStyle(fontSize: 12),
                  ),
                if ((_category == 'Players' || _category == 'Deletados') &&
                    chosen['deletionComplete'] != true)
                  const Text(
                    'Histórico anterior ao monitoramento pode não incluir todas as exclusões e mudanças de convites.',
                    style: TextStyle(
                      fontSize: 12,
                      color: contactNegativeRoyalClean,
                    ),
                  ),
                if (_category == 'Atividade' && chosen['activityAt'] != null)
                  Text(
                    'Última leitura: ${_date(chosen['activityAt'], time: true)}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_category == 'Players' || _category == 'Atividade')
          const Text(
            'Linhas neon: médias de fechamento de 3 e 7 períodos. Linha branca pontilhada: fechamento mais recente, acompanhando o período atual.\nMovimento: registros + negativos em Players; amplitude observada em Atividade.',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
        const Text(
          'São Paulo • Diário: 00h às 24h. Toque em um período para conferir os valores.\nPresença: aplicativo em primeiro plano com sinal recebido nos últimos 2 minutos; ausente significa sem sinal recente.',
          style: TextStyle(fontSize: 12, color: Colors.white60),
        ),
        if (_data != null)
          Text(
            'Atualizado em ${_date(_data!['generatedAt'], time: true)}${_error != null ? ' • dados da última consulta' : ''}',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
      ],
    );
  }
}

Widget _indicator(String label, String value, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  decoration: BoxDecoration(
    color: const Color(0xFF092F43),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: color.withValues(alpha: .35)),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      Text(
        value,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    ],
  ),
);

String _legend(String category) => switch (category) {
  'Players' =>
    'Índice Players • abertura pelo total anterior de cadastros. Azul-bebê: novos registros. Rosa-bebê: exclusões + convites pendentes do período. O índice não é o saldo real de contas.',
  'Atividade' =>
    'Índice de Atividade • quantidade online observada. Candle azul: fechamento igual ou acima da abertura; rosa: abaixo. Hastes mostram máxima e mínima reais observadas.',
  'Processando' =>
    'Convites criados no período e ainda válidos, sem cadastro até o fechamento.',
  'Deletados' =>
    'Contas excluídas pelo próprio usuário ou administrador. Bloqueios não são exclusões.',
  _ => 'Novos cadastros concluídos no aplicativo durante o período.',
};
String _date(dynamic millis, {bool time = false}) {
  if (millis is! num) return '—';
  final d = DateTime.fromMillisecondsSinceEpoch(
    millis.toInt(),
    isUtc: true,
  ).subtract(const Duration(hours: 3));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}${time ? ' ${two(d.hour)}:${two(d.minute)}' : ''}';
}

(int, int)? contactValuesRoyalClean(Map<String, dynamic> bin, String category) {
  int count(String key) => (bin[key] as num? ?? 0).toInt();
  return switch (category) {
    'Players' => (count('registered'), count('deleted') + count('pending')),
    'Atividade' =>
      bin['online'] == null ? null : (count('online'), count('absent')),
    'Processando' => (count('pending'), 0),
    'Deletados' => (count('deleted'), 0),
    _ => (count('registered'), 0),
  };
}
