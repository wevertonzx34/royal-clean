import '../../core_royal_clean/services/invoice_list_cache_royal_clean.dart';
import 'invoice_bar_page_royal_clean.dart';
import 'product_bar_page_royal_clean.dart';
import '../../core_royal_clean/services/product_list_cache_royal_clean.dart';
import '../../core_royal_clean/services/active_contacts_cache_royal_clean.dart';
import 'active_contacts_page_royal_clean.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/bling_sync_events_royal_clean.dart';
import 'dashboard_data_royal_clean.dart';

enum DashboardChartStyleRoyalClean { bars, line, area }

class DashboardChartRoyalClean extends StatefulWidget {
  final double availableHeight;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? load;
  final ActiveContactsCacheRoyalClean? invoiceCache;
  final ActiveContactsCacheRoyalClean? productCache;
  const DashboardChartRoyalClean({
    super.key,
    this.availableHeight = 720,
    this.load,
    this.invoiceCache,
    this.productCache,
  });
  @override
  State<DashboardChartRoyalClean> createState() => _DashboardChartState();
}

class _DashboardChartState extends State<DashboardChartRoyalClean>
    with WidgetsBindingObserver {
  static const _groups = {
    'Produtos': 'products',
    'Notas': 'invoices',
    'Contatos': 'contacts',
  };
  String _group = 'Produtos';
  String _contactRole = 'all';
  int _metric = 0, _selected = 0, _request = 0;
  DashboardPeriodRoyalClean _period = DashboardPeriodRoyalClean.monthly;
  DashboardChartStyleRoyalClean _style = DashboardChartStyleRoyalClean.bars;
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;
  Timer? _debounce, _hourly, _pendingPoll;
  final _cache = <String, Map<String, dynamic>>{};
  bool _refreshingAll = false;
  DateTime _lastCycle = DateTime.now();
  bool _foreground = true;
  static const _text = Color(0xFFF5F7FA);
  static const _muted = Color(0xFFA9C3D3);
  static const _accent = Color(0xFF4D8DFF);
  bool get _position => _group == 'Produtos' || _group == 'Contatos';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    blingSyncRevisionRoyalClean.addListener(_synced);
    if (widget.load == null) ActiveContactsSessionRoyalClean.instance.start();
    if (widget.load == null) InvoiceListSessionRoyalClean.instance.start();
    if (widget.load == null) ProductListSessionRoyalClean.instance.start();
    _scheduleHourly();
    _reload();
  }

  void _scheduleHourly() {
    _hourly?.cancel();
    _hourly = Timer(const Duration(hours: 1), () {
      if (_foreground) _refreshAll(syncBling: false);
    });
  }

  void _synced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _cache.clear();
      _reload();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hourly?.cancel();
    _pendingPoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    blingSyncRevisionRoyalClean.removeListener(_synced);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _watchPending();
    if (_foreground &&
        DateTime.now().difference(_lastCycle) >= const Duration(hours: 1)) {
      _refreshAll(syncBling: false);
    }
  }

  Map<String, dynamic> _query(String group) => {
    'kind': 'dashboard',
    'group': _groups[group],
    'period': _period.name,
    if (group == 'Contatos') 'contactRole': _contactRole,
  };

  Future<Map<String, dynamic>> _fetch(Map<String, dynamic> input) async {
    if (widget.load != null) return widget.load!(input);
    final callable = FirebaseFunctions.instanceFor(region: 'southamerica-east1')
        .httpsCallable(
          'blingReadData',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 55)),
        );
    Map<String, dynamic>? result;
    var previousRemaining = 5001;
    for (var batch = 0; batch < 6; batch++) {
      if (!mounted) throw StateError('Painel fechado');
      final response = await callable.call({
        ...input,
        if (input['refreshSince'] != null) 'syncLatest': batch == 0,
      });
      result = Map<String, dynamic>.from(response.data as Map);
      final enrichment = result['enrichment'] as Map?;
      final remaining = (enrichment?['remaining'] as num? ?? 0).toInt();
      if (input['refreshDetails'] != true ||
          remaining <= 0 ||
          (remaining >= previousRemaining &&
              enrichment?['catalogPending'] != true)) {
        break;
      }
      previousRemaining = remaining;
    }
    if (input['group'] == 'contacts' && result?['catalogPending'] != true) {
      final contacts = ActiveContactsSessionRoyalClean.instance.cache;
      if (contacts.checkedAt != result?['checkedAt']) {
        unawaited(contacts.refresh(force: true));
      }
    }
    if (input['group'] == 'invoices' &&
        result?['catalogPending'] != true &&
        widget.load == null) {
      final invoices = InvoiceListSessionRoyalClean.instance.cache;
      if (invoices.catalogRun != result?['catalogRun']) {
        unawaited(invoices.refresh(force: true));
      }
    }
    if (input['group'] == 'products' && result?['catalogPending'] != true) {
      final products = ProductListSessionRoyalClean.instance.cache;
      if (products.catalogRun != result?['catalogRun']) {
        unawaited(products.refresh(force: true));
      }
    }
    return result!;
  }

  void _show(Map<String, dynamic> result) {
    _data = result;
    final metrics = result['metrics'] as List;
    final moneyIndex = metrics.indexWhere((m) => (m as Map)['money'] == true);
    _metric = moneyIndex < 0 ? 0 : moneyIndex;
    _selected = (result['labels'] as List).length - 1;
    _watchPending();
  }

  void _watchPending() {
    _pendingPoll?.cancel();
    if (!mounted || _data?['catalogPending'] != true || _refreshingAll) return;
    _pendingPoll = Timer(const Duration(seconds: 15), () async {
      if (!_foreground) {
        _watchPending();
        return;
      }
      final request = _request;
      final query = _query(_group);
      final key = jsonEncode(query);
      try {
        // Read the server snapshot only; never start another Bling import here.
        final result = await _fetch(query);
        if (!mounted ||
            request != _request ||
            key != jsonEncode(_query(_group))) {
          return;
        }
        _cache[key] = result;
        setState(() {
          _data = result;
          _metric = _metric.clamp(
            0,
            math.max(0, (result['metrics'] as List).length - 1),
          );
          _selected = _selected.clamp(
            0,
            math.max(0, (result['labels'] as List).length - 1),
          );
        });
      } catch (_) {
        // Keep the visible snapshot and retry while the server is still working.
      } finally {
        if (mounted && request == _request) _watchPending();
      }
    });
  }

  Future<void> _refreshAll({bool syncBling = true}) async {
    if (_refreshingAll || !mounted) return;
    setState(() {
      ++_request;
      _busy = false;
      _refreshingAll = true;
      _error = null;
    });
    _lastCycle = DateTime.now();
    _scheduleHourly();
    final since = _lastCycle.toUtc().toIso8601String();
    final failures = <String>[];
    // Sequential batches avoid bursts against Bling and preserve the visible chart.
    for (final group in _groups.keys) {
      if (!mounted) return;
      final query = _query(group);
      final key = jsonEncode(query);
      try {
        final result = await _fetch({
          ...query,
          if (syncBling) 'refreshDetails': true,
          if (syncBling) 'refreshSince': since,
        });
        if (!mounted) return;
        _cache.removeWhere(
          (key, _) => (jsonDecode(key) as Map)['group'] == query['group'],
        );
        _cache[key] = result;
        if (key == jsonEncode(_query(_group))) {
          ++_request;
          setState(() {
            _show(result);
            _busy = false;
          });
        }
      } catch (_) {
        failures.add(group);
      }
    }
    if (!mounted) return;
    setState(() {
      _refreshingAll = false;
      if (failures.isNotEmpty) {
        _error =
            'Não foi possível atualizar ${failures.join(', ')}. Os dados anteriores foram mantidos; tente o botão Atualizar.';
      }
    });
    _watchPending();
  }

  Future<void> _reload() async {
    final request = ++_request;
    final query = _query(_group);
    final key = jsonEncode(query);
    final cached = _cache[key];
    if (cached != null) {
      setState(() {
        _show(cached);
        _busy = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _data = null;
    });
    try {
      final result = await _fetch(query);
      if (!mounted || request != _request) return;
      _cache[key] = result;
      setState(() => _show(result));
    } on FirebaseFunctionsException catch (e) {
      if (mounted && request == _request) {
        setState(
          () => _error = e.message ?? 'Resumo indisponível. Tente atualizar.',
        );
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _error = 'Não foi possível carregar o resumo. Tente atualizar.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = (_data?['metrics'] as List? ?? [])
        .map((m) => DashboardMetricRoyalClean(m as Map))
        .toList();
    final metric = metrics.isEmpty ? null : metrics[_metric];
    String contactLabel(String label) =>
        _group == 'Contatos' && label == 'Outros' ? 'Integrados' : label;
    final labels = (_data?['labels'] as List? ?? [])
        .cast<String>()
        .map(contactLabel)
        .toList();
    final details = (_data?['details'] as List? ?? [])
        .cast<String>()
        .map(contactLabel)
        .toList();
    final hasRecords =
        (_data?['baseRecords'] as num? ?? _data?['records'] as num? ?? 0) > 0;
    final summary = _data?['summary'] as Map?;
    final moneyMetric = metrics.where((m) => m.money).firstOrNull;
    final enrichment = _data?['enrichment'] as Map?;
    final checked = DateTime.tryParse(
      _data?['checkedAt'] as String? ?? '',
    )?.toLocal();
    return Container(
      key: const ValueKey('admin-dashboard-chart'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF102B3D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF25485F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Visão geral',
                  style: TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PopupMenuButton<DashboardPeriodRoyalClean>(
                key: const ValueKey('dashboard-period'),
                tooltip: 'Período do gráfico',
                icon: const Icon(Icons.schedule_outlined, color: _accent),
                onSelected: (period) {
                  if (period == _period) return;
                  _period = period;
                  _reload();
                },
                itemBuilder: (_) => [
                  if (_position) ...[
                    const PopupMenuItem<DashboardPeriodRoyalClean>(
                      enabled: false,
                      child: Text(
                        'Sem histórico por data nesta categoria. O gráfico mantém a posição atual.',
                      ),
                    ),
                    const PopupMenuDivider(),
                  ],
                  for (final period in DashboardPeriodRoyalClean.values)
                    CheckedPopupMenuItem<DashboardPeriodRoyalClean>(
                      value: period,
                      checked: period == _period,
                      child: Text(period.label),
                    ),
                ],
              ),
              PopupMenuButton<DashboardChartStyleRoyalClean>(
                tooltip: 'Estilo do gráfico',
                initialValue: _style,
                icon: const Icon(Icons.bar_chart, color: _accent),
                onSelected: (style) => setState(() => _style = style),
                itemBuilder: (_) => [
                  for (final item in const {
                    DashboardChartStyleRoyalClean.bars: 'Barras',
                    DashboardChartStyleRoyalClean.line: 'Linha',
                    DashboardChartStyleRoyalClean.area: 'Área',
                  }.entries)
                    PopupMenuItem(value: item.key, child: Text(item.value)),
                ],
              ),
              IconButton(
                tooltip: 'Atualizar resumo',
                onPressed: _refreshingAll ? null : _refreshAll,
                icon: const Icon(Icons.refresh, color: _accent),
              ),
            ],
          ),
          Row(
            children: [
              for (final group in _groups.keys)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: TextButton(
                      onPressed: () {
                        _group = group;
                        _reload();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: _text,
                        backgroundColor: group == _group
                            ? const Color(0xFF17628B)
                            : const Color(0xFF19394D),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(group),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_group == 'Contatos')
            SingleChildScrollView(
              key: const ValueKey('filters-Contatos'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final category in const {
                    'all': 'Todos',
                    'customer': 'Clientes',
                    'supplier': 'Fornecedores',
                    'unclassified': 'Sem classificação',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(category.value),
                        selected: _contactRole == category.key,
                        onSelected: (_) {
                          if (_contactRole == category.key) return;
                          _contactRole = category.key;
                          _reload();
                        },
                      ),
                    ),
                ],
              ),
            ),
          if (_busy || _refreshingAll)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(_error!, style: const TextStyle(color: _text)),
            ),
          if (_data != null && !hasRecords)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Ainda não há registros consultados nesta categoria. Abra Ver produtos e movimentações para atualizar a base.',
                style: TextStyle(color: _muted),
              ),
            ),
          if (hasRecords && metric != null && labels.isNotEmpty) ...[
            if (metrics.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < metrics.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(metrics[i].label),
                          selected: i == _metric,
                          onSelected: (_) => setState(() => _metric = i),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            if (summary == null)
              Text(
                metric.format(metric.summary),
                key: const ValueKey('dashboard-total'),
                style: const TextStyle(
                  color: _text,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            Text(
              'Bling • ${_data!['records']} registros • ${_data!['partial'] == false ? (_group == 'Produtos' ? 'catálogo completo' : 'base completa') : 'base parcial'}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
            if ((_data?['excluded'] as num? ?? 0) > 0)
              Text(
                '${_data!['excluded']} excluídos no Bling, fora do catálogo atual.',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            if ((_data?['unclassified'] as num? ?? 0) > 0)
              Text(
                '${_data!['unclassified']} registros sem classificação confirmada.',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            if ((_data?['missingStatuses'] as num? ?? 0) > 0)
              const Text(
                'Classificação de pedidos pendente. Confira a permissão de Situações no Bling e atualize os detalhes.',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            if (summary != null &&
                (summary['futureMissing'] as num? ?? 0) > 0 &&
                _period == DashboardPeriodRoyalClean.yearly)
              Text(
                '${summary['futureMissing']} registros futuros sem valor. Total futuro incompleto.',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
          ],
          if (enrichment?['warning'] != null)
            Text(
              enrichment!['warning'] as String,
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          if ((enrichment?['remaining'] as num? ?? 0) > 0)
            Text(
              '${enrichment!['remaining']} detalhes pendentes. Toque em Atualizar resumo para continuar.',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _position
                          ? 'Posição atual • por situação'
                          : _period.label,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Toque no gráfico para consultar',
                      style: TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sobre os dados do gráfico',
                icon: const Icon(Icons.info_outline, color: _muted, size: 20),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Dados do Bling'),
                    content: Text(
                      'Produtos, notas e contatos são sincronizados automaticamente no servidor a cada hora. Use Atualizar para consultar antes. O último resultado completo é preservado durante a sincronização. Produtos excluídos ficam fora do total atual.\n\n${_group == 'Notas' ? 'Faturamento soma o valor nominal das notas Autorizadas e Emitida DANFE; exclui as demais situações. Não representa receita líquida ou recebimento. Quantidade considera as notas no período selecionado. Entregues é o novo título do indicador fiscal anterior; seus dados ainda representam transmissão à SEFAZ, não confirmação de entrega ao cliente. Pendentes corresponde à situação fiscal Pendente. Pagas exige conciliação das contas a receber vinculadas à NF. Valor futuro considera apenas registros futuros, sem estimativa.' : 'Cadastros por situação atual. Contatos são classificados conforme os tipos Cliente e Fornecedor do Bling; um contato pode pertencer aos dois grupos. Sem histórico por data.'}',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Entendi'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (hasRecords && metric != null && labels.isNotEmpty) ...[
            if (_group == 'Notas' && metric.label == 'Entregues')
              const Text(
                'Indicador fiscal da SEFAZ. Entrega ao cliente ainda não confirmada.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            if (metric.unavailable != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  metric.unavailable!,
                  style: const TextStyle(color: _muted),
                ),
              )
            else ...[
              SizedBox(
                height: (widget.availableHeight * .22).clamp(120.0, 170.0),
                child: LayoutBuilder(
                  builder: (context, viewport) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: math.max(
                        viewport.maxWidth,
                        labels.length * (metric.money ? 92.0 : 52.0) + 60,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) => Semantics(
                          label:
                              '${metric.label}, ${details[_selected]}: ${metric.format(metric.values[_selected])}',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            key: const ValueKey('dashboard-plot'),
                            onTapUp: (event) {
                              final fraction =
                                  ((event.localPosition.dx - 48) /
                                          (constraints.maxWidth - 60))
                                      .clamp(0.0, 1.0);
                              setState(
                                () => _selected = math.min(
                                  labels.length - 1,
                                  (fraction * labels.length).floor(),
                                ),
                              );
                              if (_group == 'Produtos') {
                                openProductBarRoyalClean(
                                  context,
                                  category: labels[_selected],
                                  chartRun: _data?['catalogRun'] as String?,
                                  cache: widget.productCache,
                                );
                              }
                              if (_group == 'Contatos' &&
                                  labels[_selected] == 'Ativos') {
                                openActiveContactsRoyalClean(
                                  context,
                                  _contactRole,
                                  load: widget.load,
                                );
                              }
                              if (_group == 'Notas' &&
                                  metric.unavailable == null) {
                                final ranges = _data?['ranges'] as List?;
                                if (ranges != null &&
                                    _selected < ranges.length) {
                                  final range = ranges[_selected] as Map;
                                  openInvoiceBarRoyalClean(
                                    context,
                                    start: range['start'] as String,
                                    endExclusive:
                                        range['endExclusive'] as String?,
                                    metric: metric.label,
                                    periodLabel: details[_selected],
                                    cache: widget.invoiceCache,
                                  );
                                }
                              }
                            },
                            child: CustomPaint(
                              painter: _DashboardPainter(
                                metric.values,
                                labels,
                                _selected,
                                _style,
                                metric.money,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                children: [
                  Text(
                    details[_selected],
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                  Text(
                    metric.format(metric.values[_selected]),
                    key: const ValueKey('dashboard-month-value'),
                    style: const TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            if (checked != null)
              Text(
                'Última consulta: ${checked.day.toString().padLeft(2, '0')}/${checked.month.toString().padLeft(2, '0')} ${TimeOfDay.fromDateTime(checked).format(context)}',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            if (summary != null && moneyMetric != null) ...[
              const SizedBox(height: 8),
              Text(
                '${summary['label']} • ${summary['start']} a ${summary['end']}',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              Text(
                ((summary['financialCount'] as num? ??
                                summary['count'] as num? ??
                                0) >
                            0 &&
                        summary['missingAmounts'] ==
                            (summary['financialCount'] ?? summary['count'])
                    ? 'Valor pendente'
                    : moneyMetric.format((summary['value'] as num).toDouble())),
                key: const ValueKey('dashboard-total'),
                style: const TextStyle(
                  color: _text,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${summary['count']} notas no período',
                style: const TextStyle(color: _text, fontSize: 13),
              ),
              if (_period == DashboardPeriodRoyalClean.yearly)
                Text(
                  'Valor futuro registrado: ${moneyMetric.format((summary['futureValue'] as num).toDouble())} • ${summary['futureCount']} registros',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              if (_group == 'Notas')
                const Text(
                  'Total nominal de NF autorizadas, incluindo DANFE emitida. Não comprova recebimento ou receita líquida.',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
            ],
            if ((_data!['invalidDates'] as num? ?? 0) > 0)
              Text(
                '${_data!['invalidDates']} registros sem data válida, fora do gráfico.',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            if ((_data!['missingAmounts'] as num? ?? 0) > 0)
              Text(
                '${_data!['missingAmounts']} registros sem valor informado; soma incompleta.',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            if (_data!['truncated'] == true)
              const Text(
                'Limite de 5.000 registros no resumo. Base incompleta.',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
          ],
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
  final bool money;
  _DashboardPainter(
    this.values,
    this.labels,
    this.selected,
    this.style,
    this.money,
  );
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
    final plot = Rect.fromLTRB(48, 26, size.width - 12, size.height - 30);
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
        final value = values[i];
        final compact = value.abs() >= 1000000
            ? '${(value / 1000000).toStringAsFixed(1)} mi'
            : value.abs() >= 1000
            ? '${(value / 1000).toStringAsFixed(1)} mil'
            : value.toStringAsFixed(money ? 2 : 0);
        _label(
          canvas,
          '${money ? 'R\$ ' : ''}${compact.replaceAll('.', ',')}',
          Offset(plot.left + step * i, points[i].dy - 20),
          step,
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
      oldDelegate.style != style ||
      oldDelegate.money != money;
}
