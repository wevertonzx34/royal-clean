import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../shared/layout_button_royal_clean.dart';
import 'activity_market_viewport_royal_clean.dart';

/// Public, server-calculated aggregates. This view never accesses account records.
class PublicActivityIndexRoyalClean extends StatefulWidget {
  final Stream<Map<String, dynamic>?> Function(String)? watch;
  final Future<List<Map<String, dynamic>>> Function(String, num?)? loadEarlier;
  const PublicActivityIndexRoyalClean({
    super.key,
    this.watch,
    this.loadEarlier,
  });
  @override
  State<PublicActivityIndexRoyalClean> createState() =>
      _PublicActivityIndexState();
}

class _PublicActivityIndexState extends State<PublicActivityIndexRoyalClean> {
  static const periods = {
    'm1': '1 minuto',
    'm5': '5 minutos',
    'm15': '15 minutos',
    'm30': '30 minutos',
    'h1': '1 hora',
    'h4': '4 horas',
    'daily': 'Diário',
    'weekly': 'Semanal',
    'monthly': 'Mensal',
    'quarterly': 'Trimestral',
    'halfYear': 'Semestral',
    'yearly': 'Anual',
  };
  String period = 'daily';
  num? selectedStart;
  final records = <num, Map<String, dynamic>>{};
  bool loadingHistory = false, hasMore = true, initialStarted = false;
  String? historyError;
  int generation = 0;
  static const targetHistory = {
    'm1': 1440,
    'm5': 288,
    'm15': 96,
    'm30': 48,
    'h1': 168,
    'h4': 42,
    'daily': 31,
    'weekly': 14,
    'monthly': 12,
    'quarterly': 8,
    'halfYear': 4,
    'yearly': 5,
  };
  late Stream<Map<String, dynamic>?> stream;
  Timer? clock;
  @override
  void initState() {
    super.initState();
    stream = subscribe();
    clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  Stream<Map<String, dynamic>?> subscribe() {
    if (widget.watch != null) return widget.watch!(period);
    if (Firebase.apps.isEmpty) return Stream.value(null);
    return FirebaseFirestore.instance
        .doc('public_activity_index/$period')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final data = snapshot.data();
          return data == null
              ? null
              : {...data, 'cached': snapshot.metadata.isFromCache};
        });
  }

  Future<void> earlier() async {
    if (loadingHistory || !hasMore) return;
    final requestGeneration = generation, requestPeriod = period;
    final oldest = records.isEmpty
        ? null
        : records.keys.reduce((a, b) => a < b ? a : b);
    setState(() {
      loadingHistory = true;
      historyError = null;
    });
    try {
      List<Map<String, dynamic>> page;
      if (widget.loadEarlier != null) {
        page = await widget.loadEarlier!(requestPeriod, oldest);
      } else if (Firebase.apps.isEmpty) {
        page = [];
      } else {
        var query = FirebaseFirestore.instance
            .collection('public_activity_candles/$requestPeriod/candles')
            .orderBy('start', descending: true)
            .limit(256);
        if (oldest != null) query = query.startAfter([oldest]);
        final result = await query.get(const GetOptions(source: Source.server));
        page = result.docs.map((d) => d.data()).toList();
      }
      if (!mounted || requestGeneration != generation) return;
      setState(() {
        for (final b in page) {
          records[b['start'] as num] = b;
        }
        hasMore = page.length == 256;
      });
    } catch (_) {
      if (mounted && requestGeneration == generation) {
        setState(
          () => historyError =
              'Não foi possível carregar o histórico anterior. Tente novamente.',
        );
      }
    } finally {
      if (mounted && requestGeneration == generation) {
        setState(() => loadingHistory = false);
      }
    }
  }

  Future<void> initialHistory() async {
    final requestGeneration = generation;
    while (mounted &&
        requestGeneration == generation &&
        hasMore &&
        historyError == null &&
        records.length < targetHistory[period]!) {
      await earlier();
      if (loadingHistory) break;
    }
  }

  @override
  void dispose() {
    clock?.cancel();
    super.dispose();
  }

  Widget panel(Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF123F53),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF7568A1)),
    ),
    child: child,
  );
  String number(num value) => value.toStringAsFixed(6);
  Map<String, dynamic> finalized(Map<String, dynamic> b, num now) {
    final end = b['end'] as num, start = b['start'] as num;
    final cutoff = now < end ? now : end - 1;
    final expected = (((cutoff - start) / 60000).floor() + 1).clamp(
      1,
      ((end - start) / 60000).round(),
    );
    final observed = b['observed'] as num?;
    return {
      ...b,
      'closed': end <= now,
      if (observed != null) 'coverage': (observed / expected).clamp(0.0, 1.0),
      if (observed != null)
        'activityPartial': b['activityPartial'] == true || observed < expected,
    };
  }

  String date(num timestamp, {bool time = false}) {
    final d = DateTime.fromMillisecondsSinceEpoch(
      timestamp.toInt(),
      isUtc: true,
    ).subtract(const Duration(hours: 3));
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}'
        '${time ? ' ${two(d.hour)}:${two(d.minute)}' : ''}';
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>?>(
    stream: stream,
    builder: (context, snapshot) {
      final data = snapshot.data;
      final valid =
          data?['source'] == 'royal-clean' &&
          data?['method'] == 'royal-activity-v1' &&
          data?['period'] == period &&
          data?['unit'] == 'points';
      if (valid) {
        for (final raw in data!['bins'] as List) {
          final b = Map<String, dynamic>.from(raw as Map);
          records[b['start'] as num] = b;
        }
        if (!initialStarted) {
          initialStarted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(initialHistory());
          });
        }
      }
      final bins = valid
          ? records.values
                .map((b) => finalized(b, data!['generatedAt'] as num))
                .toList()
          : <Map<String, dynamic>>[];
      bins.sort((a, b) => (a['start'] as num).compareTo(b['start'] as num));
      final observed = bins.where((b) => b['activityClose'] != null).toList();
      final last = observed.isEmpty ? null : observed.last;
      final chosen = bins.where((b) => b['start'] == selectedStart).toList();
      final current = chosen.isEmpty ? last : chosen.first;
      final close =
          (last?['activityClose'] as num?) ??
          (valid ? data!['latest'] as num? : null) ??
          100;
      final change = last == null ? 0.0 : close - (last['activityOpen'] as num);
      final age = data?['generatedAt'] is num
          ? DateTime.now().millisecondsSinceEpoch -
                (data!['generatedAt'] as num).toInt()
          : 0;
      final stale = data?['cached'] == true || age > 180000;
      final color = change >= 0
          ? const Color(0xFF9DE5F7)
          : const Color(0xFFF5B0D1);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Índice de Atividade',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              LayoutButtonRoyalClean(
                id: 'performance.activity.index.period',
                child: PopupMenuButton<String>(
                  tooltip: 'Período do índice',
                  initialValue: period,
                  onSelected: (value) => setState(() {
                    period = value;
                    generation++;
                    selectedStart = null;
                    records.clear();
                    loadingHistory = false;
                    hasMore = true;
                    initialStarted = false;
                    historyError = null;
                    stream = subscribe();
                  }),
                  itemBuilder: (_) => periods.entries
                      .map(
                        (e) => CheckedPopupMenuItem(
                          value: e.key,
                          checked: e.key == period,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('${periods[period]} ▾'),
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 16),
            child: Text(
              'Presença na Royal Clean • Base 100 pontos\nÍndice informativo, sem valor monetário.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          if (snapshot.hasError)
            panel(
              const Text(
                'Não foi possível atualizar o índice. Tente novamente quando a conexão estiver disponível.',
              ),
            ),
          if (snapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator(),
          if (!valid &&
              snapshot.connectionState != ConnectionState.waiting &&
              !snapshot.hasError)
            panel(
              const Text(
                'Base inicial: 100 pontos. Aguardando as primeiras leituras válidas do servidor.',
              ),
            ),
          if (valid) ...[
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${number(close)} pts',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    '${change >= 0 ? '+' : ''}${number(change)} pts no período atual',
                    style: TextStyle(color: color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Última coleta: ${date(data!['generatedAt'] as num, time: true)} • Brasília',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (stale)
                    const Text(
                      'Leitura anterior. Aguardando atualização do servidor.',
                      style: TextStyle(color: Color(0xFFF5B0D1)),
                    ),
                ],
              ),
            ),
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Candles • presença normalizada',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (observed.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Ainda não há presença suficiente para formar candles.',
                      ),
                    )
                  else
                    ActivityMarketViewportRoyalClean(
                      key: ValueKey(period),
                      bins: bins,
                      minimumRange: bins.isEmpty
                          ? 1
                          : ((bins.last['end'] as num) -
                                    (bins.last['start'] as num)) /
                                86400000,
                      latestClose: close.toDouble(),
                      candleEnd: bins.isEmpty ? null : bins.last['end'] as num,
                      selectedStart: selectedStart,
                      onSelect: (start) =>
                          setState(() => selectedStart = start),
                      onNeedOlder: hasMore && !loadingHistory
                          ? () => unawaited(earlier())
                          : null,
                    ),
                  if (loadingHistory) const LinearProgressIndicator(),
                  if (historyError != null)
                    Text(
                      historyError!,
                      style: const TextStyle(color: Color(0xFFF5B0D1)),
                    ),
                  if (hasMore)
                    LayoutButtonRoyalClean(
                      id: 'performance.activity.index.history',
                      child: TextButton.icon(
                        onPressed: loadingHistory
                            ? null
                            : () => unawaited(earlier()),
                        icon: const Icon(Icons.history),
                        label: const Text('Carregar candles anteriores'),
                      ),
                    ),
                  Text(
                    '${bins.length} candles carregados${hasMore ? '' : ' • início do histórico disponível'}',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Azul: alta • Rosa: baixa\nLinha branca: fechamento atual • Médias: 3 e 7 períodos\nBarras inferiores: volume de presença observada. Traço na base: volume zero.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (current != null)
              panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${date(current['start'] as num, time: ['m1', 'm5', 'm15', 'm30', 'h1', 'h4'].contains(period))} • ${current['closed'] == true ? 'Encerrado' : 'Em andamento'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Fechamento do intervalo: ${date(current['end'] as num, time: true)} • Brasília',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (current['activityClose'] == null)
                      const Text('Período sem coleta válida.')
                    else ...[
                      Text(
                        'Abertura: ${number(current['activityOpen'] as num)} pts\nMáxima: ${number(current['activityHigh'] as num)} pts\nMínima: ${number(current['activityLow'] as num)} pts\nFechamento: ${number(current['activityClose'] as num)} pts',
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Volume: ${(current['volume'] as num).toStringAsFixed(4)} usuários-dia\nCobertura: ${((current['coverage'] as num) * 100).toStringAsFixed(1)}% dos minutos',
                      ),
                    ],
                    if (current['activityPartial'] == true)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Histórico parcial: minutos sem coleta não geram pontos.',
                          style: TextStyle(color: Color(0xFFF5B0D1)),
                        ),
                      ),
                  ],
                ),
              ),
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Como funciona',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A cada minuto, a presença é comparada à referência do horário. Acima dela, o índice sobe; abaixo, desce. A variação é limitada a ±1 ponto por dia completo, independentemente do tamanho da rede.\n\nUm perfil conta uma vez, mesmo usando vários dispositivos. Participam perfis ativos com presença nos últimos 30 dias. Sem participantes elegíveis ou sem coleta, o índice permanece no último valor.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    last?['referenceOrigin'] == 'historical'
                        ? 'Referência: histórico do mesmo dia da semana e horário, fixado no início de cada dia.'
                        : 'Referência inicial: 5% de presença. Será substituída por histórico quando houver pelo menos três dias comparáveis.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dias completos: 00h às 24h, horário de Brasília. Os pavios mostram os extremos realmente observados. Volume observado: 1.440 minutos de presença equivalem a 1 usuário-dia.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Os 100 pontos são a base, não o volume. A escala mínima respeita a duração do candle; um pequeno movimento não preenche a tela inteira. Dojis aparecem quando abertura e fechamento realmente se aproximam. No zoom distante, os candles se condensam numa linha de fechamentos.\n\nHistórico de minutos começa nesta atualização. Não reconstruímos minutos antigos a partir de candles diários.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}
