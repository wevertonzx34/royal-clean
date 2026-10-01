import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../auth/admin_route_guard_royal_clean.dart';
import '../shared/header_actions_royal_clean.dart';
import '../shared/layout_button_royal_clean.dart';
import 'nfe_document_royal_clean.dart';
import 'production_orders_page_royal_clean.dart';

typedef CareCall = Future<Map<String, dynamic>> Function(Map<String, dynamic>);
Future<Map<String, dynamic>> _invoke(
  String name,
  Map<String, dynamic> input,
) async => Map<String, dynamic>.from(
  (await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
              .httpsCallable(
                name,
                options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 55),
                ),
              )
              .call(input))
          .data
      as Map,
);
String _error(Object e) => e is FirebaseFunctionsException
    ? e.message ?? 'Consulta indisponível.'
    : 'Não foi possível concluir. Seus dados digitados foram preservados.';
String _date(String? value) {
  final d = DateTime.tryParse(value ?? '')?.toLocal();
  return d == null
      ? 'Não informado'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

const _labels = {
  'new': 'Para confirmar',
  'separating': 'Em separação',
  'pending': 'Com pendências',
  'verified': 'Conferido',
  'route': 'Em entrega',
  'delivered': 'Entregue',
  'closed': 'Concluído',
};
const _bg = Color(0xFF020B1D);
Widget _control(String id, Widget child, {String? instance}) =>
    LayoutButtonRoyalClean(id: id, instanceKey: instance, child: child);
Widget _status(Map<String, dynamic> row) {
  final overdue =
      DateTime.tryParse(row['dueAt'] ?? '')?.isBefore(DateTime.now()) == true &&
      row['status'] != 'closed';
  final color = overdue
      ? Colors.redAccent
      : row['status'] == 'closed'
      ? Colors.greenAccent
      : row['status'] == 'pending'
      ? Colors.amber
      : Colors.lightBlueAccent;
  return Text(
    '${_labels[row['status']] ?? 'Para confirmar'}${overdue ? ' • Prazo vencido' : ''}',
    style: TextStyle(color: color, fontWeight: FontWeight.bold),
  );
}

Future<void> openOrderCareRoyalClean(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminRouteGuardRoyalClean(
          firebaseInitialization: Future<void>.value(),
          builder: (_) => const OrderCarePageRoyalClean(),
        ),
      ),
    );

class OrderCarePageRoyalClean extends StatefulWidget {
  const OrderCarePageRoyalClean({super.key});
  @override
  State<OrderCarePageRoyalClean> createState() => _CareListState();
}

class _CareListState extends State<OrderCarePageRoyalClean>
    with WidgetsBindingObserver {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  Timer? _poll;
  final Map<String, Map<String, dynamic>> _cases = {};
  final Map<String, Map<String, dynamic>> _sales = {};
  String _filter = 'separating', _search = '';
  String? _failure;
  bool _busy = false, _more = true;
  int _page = 0;
  DateTime _start = DateTime.now().subtract(const Duration(days: 30)),
      _end = DateTime.now();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = FirebaseFirestore.instance
        .collection('order_care')
        .snapshots()
        .listen(
          (s) {
            if (!mounted) return;
            setState(() {
              _cases.clear();
              for (final d in s.docs) {
                _cases[d.id] = d.data();
              }
            });
          },
          onError: (Object e) {
            if (mounted) setState(() => _failure = _error(e));
          },
        );
    unawaited(_refresh());
    _poll = Timer.periodic(const Duration(minutes: 1), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _refresh({bool next = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final page = next ? _page + 1 : 1;
      final result = await _invoke('blingReadData', {
        'kind': 'sales',
        'page': page,
        'start': _start.toIso8601String().substring(0, 10),
        'end': _end.toIso8601String().substring(0, 10),
      });
      if (!mounted) return;
      setState(() {
        for (final r in result['items'] as List) {
          final row = Map<String, dynamic>.from(r);
          _sales[row['id'] as String] = row;
        }
        if (next || _page == 0) {
          _page = page;
          _more = result['hasMore'] == true;
        }
        _failure = null;
      });
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _period() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _start, end: _end),
    );
    if (range == null || !mounted) return;
    if (range.duration.inDays > 366) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione até um ano por consulta.')),
      );
      return;
    }
    setState(() {
      _start = range.start;
      _end = range.end;
      _page = 0;
      _sales.clear();
    });
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final ids = {..._sales.keys, ..._cases.keys};
    final rows =
        ids
            .map(
              (id) =>
                  _cases[id] ??
                  {'id': id, 'source': _sales[id], 'status': 'new'},
            )
            .where((row) {
              final s = row['source'] as Map;
              final state = row['status'];
              final matches = switch (_filter) {
                'separating' => [
                  'new',
                  'separating',
                  'verified',
                ].contains(state),
                'pending' =>
                  state != 'closed' &&
                      (state == 'pending' || row['dueAt'] != null),
                'route' => ['route', 'delivered'].contains(state),
                'closed' => state == 'closed',
                _ => true,
              };
              return matches &&
                  '${s['code']} ${s['name']} ${s['document']}'
                      .toLowerCase()
                      .contains(_search);
            })
            .toList()
          ..sort((a, b) {
            final ad = a['dueAt'] as String?, bd = b['dueAt'] as String?;
            if (ad != null || bd != null) {
              return (ad ?? '9999').compareTo(bd ?? '9999');
            }
            return '${(b['source'] as Map)['date']}'.compareTo(
              '${(a['source'] as Map)['date']}',
            );
          });
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text('Atendimento do pedido'),
          leading: _control(
            'care.list.back',
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          actions: const [HeaderActionsRoyalClean()],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Separação, pendências e entrega',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: Colors.lightBlueAccent,
                      ),
                    ),
                    const Text(
                      'Pedidos do Bling • controle interno, sem alterar estoque ou documentos fiscais.',
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Pedido, cliente ou CPF/CNPJ',
                      ),
                      onChanged: (v) =>
                          setState(() => _search = v.toLowerCase().trim()),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        _control(
                          'care.list.period',
                          TextButton.icon(
                            onPressed: _busy ? null : _period,
                            icon: const Icon(Icons.date_range),
                            label: const Text('Período do Bling'),
                          ),
                        ),
                        _control(
                          'care.list.refresh',
                          IconButton(
                            tooltip: 'Atualizar pedidos',
                            onPressed: _busy ? null : () => _refresh(),
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                        _control(
                          'care.list.legacy',
                          TextButton(
                            onPressed: () => openProductionRoyalClean(context),
                            child: const Text('Conferências por NF-e'),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_start.day}/${_start.month}/${_start.year} – ${_end.day}/${_end.month}/${_end.year} • Atendimentos iniciados continuam visíveis fora do período.',
                      style: const TextStyle(fontSize: 12),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final f in const {
                            'separating': 'Para separar',
                            'pending': 'Com pendências',
                            'route': 'Em entrega',
                            'closed': 'Concluídos',
                          }.entries)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _control(
                                'care.list.filter',
                                ChoiceChip(
                                  label: Text(f.value),
                                  selected: _filter == f.key,
                                  onSelected: (_) =>
                                      setState(() => _filter = f.key),
                                ),
                                instance: f.key,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_failure != null)
                      Text(
                        _failure!,
                        style: const TextStyle(color: Colors.amber),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(
                          _busy
                              ? 'Consultando pedidos…'
                              : 'Nenhum atendimento neste filtro.',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final row = rows[i], s = row['source'] as Map;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _control(
                              'care.list.order',
                              InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => AdminRouteGuardRoyalClean(
                                      firebaseInitialization:
                                          Future<void>.value(),
                                      builder: (_) => OrderCareDetailRoyalClean(
                                        orderId: row['id'] as String,
                                      ),
                                    ),
                                  ),
                                ),
                                child: NfePanelRoyalClean(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pedido ${s['code']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 19,
                                        ),
                                      ),
                                      Text(
                                        '${s['name'] ?? 'Cliente não informado'}',
                                      ),
                                      Text(
                                        '${s['document'] ?? ''} • ${s['date'] ?? ''}',
                                      ),
                                      _status(row),
                                      if (row['fiscal'] != null)
                                        Text(
                                          'NF-e ${(row['fiscal'] as Map)['number']} • ${(row['fiscal'] as Map)['status']}',
                                        ),
                                      if (row['pendingCount'] != null)
                                        Text(
                                          '${row['pendingCount']} produto(s) ainda não concluído(s)',
                                        ),
                                      if (row['sourceChanged'] == true)
                                        const Text(
                                          'Pedido alterado no Bling • revisar origem',
                                          style: TextStyle(color: Colors.amber),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              instance: row['id'] as String,
                            ),
                          );
                        },
                      ),
              ),
              if (_more)
                _control(
                  'care.list.more',
                  TextButton(
                    onPressed: _busy ? null : () => _refresh(next: true),
                    child: Text(
                      _busy
                          ? 'Atualizando…'
                          : 'Carregar mais pedidos do período',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderCareDetailRoyalClean extends StatefulWidget {
  final String orderId;
  final CareCall? call;
  final bool showHeader;
  const OrderCareDetailRoyalClean({
    super.key,
    required this.orderId,
    this.call,
    this.showHeader = true,
  });
  @override
  State<OrderCareDetailRoyalClean> createState() => _CareDetailState();
}

class _CareDetailState extends State<OrderCareDetailRoyalClean> {
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _lines = [];
  bool _busy = false, _dirty = false;
  String? _failure, _requestId;
  String? _lastCommand;
  final _receipt = TextEditingController();
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _receipt.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> data) =>
      (widget.call ?? (input) => _invoke('orderCare', input))(data);
  void _accept(Map<String, dynamic> result) {
    _order = Map<String, dynamic>.from(result['order']);
    _lines = (_order!['lines'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _dirty = false;
    _requestId = null;
    _failure = null;
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final r = await _call({'orderId': widget.orderId, 'action': 'open'});
      if (mounted) setState(() => _accept(r));
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _leave() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Alterações não salvas'),
            content: const Text(
              'Voltar descarta somente o que ainda não foi salvo. Deseja sair?',
            ),
            actions: [
              _control(
                'care.leave.cancel',
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Continuar'),
                ),
              ),
              _control(
                'care.leave.confirm',
                TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Sair'),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _save(String action) async {
    if (_busy) return;
    final message = switch (action) {
      'confirm' => 'Registre abaixo como o cliente confirmou o pedido.',
      'verify' =>
        'Confirma a conferência física de cada item e os acordos das faltas?',
      'dispatch' =>
        'Registrar saída das quantidades separadas? Se houver falta, você está autorizando uma saída parcial com os acordos registrados.',
      'deliver' =>
        'Confirma as quantidades entregues e o recebimento descrito?',
      'close' =>
        'Concluir este atendimento? Todos os itens precisam estar entregues ou ter resolução registrada.',
      'reconcile' =>
        'Aceitar a nova origem do Bling? Os saldos compatíveis serão preservados e os itens precisarão de nova conferência. O histórico anterior será mantido.',
      _ => 'Salvar as quantidades e observações internas?',
    };
    final accepted = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirmar operação'),
        content: Text(message),
        actions: [
          _control(
            'care.action.cancel',
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
          ),
          _control(
            'care.action.confirm',
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirmar'),
            ),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final command = '$action|$_lines|${_receipt.text}';
    if (command != _lastCommand) {
      _requestId =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
      _lastCommand = command;
    }
    setState(() => _busy = true);
    try {
      final r = await _call({
        'orderId': widget.orderId,
        'action': action,
        'revision': _order!['revision'],
        'requestId': _requestId,
        'lines': _lines,
        'confirmation': _receipt.text,
        'receipt': _receipt.text,
        'partialApproved': action == 'dispatch',
      });
      if (mounted) setState(() => _accept(r));
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deadline(int index) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (time == null || !mounted) return;
    setState(() {
      _lines[index]['due'] = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).toUtc().toIso8601String();
      _dirty = true;
    });
  }

  Future<void> _history() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(c).height * .75,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('order_care')
                .doc(widget.orderId)
                .collection('audit')
                .orderBy('at', descending: true)
                .limit(100)
                .snapshots(),
            builder: (c, s) {
              if (s.hasError) {
                return const Center(child: Text('Histórico indisponível.'));
              }
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                children: [
                  const ListTile(
                    title: Text('Histórico • últimos 100 registros'),
                  ),
                  for (final d in s.data!.docs)
                    _control(
                      'care.audit.entry',
                      ExpansionTile(
                        title: Text(
                          '${d.data()['action']} • ${d.data()['actorName']}',
                        ),
                        subtitle: Text(
                          '${_date((d.data()['at'] as Timestamp).toDate().toIso8601String())}\nRevisão ${d.data()['revision']} • ${d.data()['status']}\n${d.data()['receipt'] ?? ''}',
                        ),
                        children: [
                          for (final line in (d.data()['lines'] as List? ?? []))
                            ListTile(
                              title: Text(
                                'Item ${int.tryParse('${line['line']}') != null ? int.parse('${line['line']}') + 1 : line['line']} • Separado ${line['separated']} • Enviado ${line['dispatched']} • Entregue ${line['delivered']}',
                              ),
                              subtitle: Text(
                                'Resolvido sem entrega: ${line['resolved']}\n${line['reason']} • ${line['note']}\nResponsável: ${line['owner']}\nPrazo: ${_date(line['due'])}\nAcordo: ${line['agreement']}\nResolução: ${line['resolution']}',
                              ),
                            ),
                        ],
                      ),
                      instance: d.id,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _field(int i, String key, String label, {bool number = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextFormField(
          key: ValueKey('${_order?['revision']}-$i-$key'),
          initialValue: '${_lines[i][key] ?? ''}',
          enabled:
              !_busy &&
              _order!['status'] != 'new' &&
              _order!['status'] != 'closed' &&
              !(_order!['sourceChanged'] == true),
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.multiline,
          maxLines: number ? 1 : null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) {
            _lines[i][key] = number
                ? double.tryParse(v.replaceAll(',', '.')) ?? -1
                : v;
            setState(() => _dirty = true);
          },
        ),
      );
  @override
  Widget build(BuildContext context) {
    final source = _order?['source'] as Map?;
    final closed = _order?['status'] == 'closed';
    return PopScope(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && !_busy && await _leave() && context.mounted) {
          setState(() => _dirty = false);
          Navigator.pop(context);
        }
      },
      child: Theme(
        data: ThemeData.dark(useMaterial3: true),
        child: Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            title: Text('Pedido ${source?['code'] ?? ''}'),
            leading: _control(
              'care.detail.back',
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _busy
                    ? null
                    : () async {
                        if (await _leave() && context.mounted) {
                          setState(() => _dirty = false);
                          Navigator.pop(context);
                        }
                      },
              ),
            ),
            actions: [if (widget.showHeader) const HeaderActionsRoyalClean()],
          ),
          body: SafeArea(
            child: _order == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_failure ?? 'Consultando pedido…'),
                        if (!_busy)
                          _control(
                            'care.detail.retry',
                            TextButton(
                              onPressed: _load,
                              child: const Text('Tentar novamente'),
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      NfePanelRoyalClean(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${source!['name']}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('${source['document']} • ${source['date']}'),
                            _status(_order!),
                            Text(
                              'NF-e ${(_order!['fiscal'] as Map)['number']} • ${(_order!['fiscal'] as Map)['status']}',
                            ),
                            const Text(
                              'Controle interno. Não substitui XML/DANFE nem altera o Bling.',
                            ),
                            if ('${source['notes'] ?? ''}'.isNotEmpty)
                              Text('Observação do pedido: ${source['notes']}'),
                            if ('${source['internalNotes'] ?? ''}'.isNotEmpty)
                              Text(
                                'Interno do Bling: ${source['internalNotes']}',
                              ),
                            Text(
                              'Atualizado: ${_date(_order!['updatedAt'])} • ${_order!['updatedByName']}',
                            ),
                            if (widget.call == null)
                              _control(
                                'care.detail.history',
                                TextButton.icon(
                                  onPressed: _history,
                                  icon: const Icon(Icons.history),
                                  label: const Text('Histórico'),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_order!['sourceChanged'] == true) ...[
                        const Text(
                          'O pedido mudou no Bling. Os saldos anteriores foram preservados; revise a nova origem antes de continuar.',
                          style: TextStyle(color: Colors.amber),
                        ),
                        for (final item
                            in ((_order!['latestSource'] as Map?)?['items']
                                    as List? ??
                                []))
                          Text(
                            'Nova origem • ${item['code'] ?? ''} ${item['description'] ?? ''}: ${item['quantity']} ${item['unit'] ?? ''}',
                          ),
                        _control(
                          'care.detail.reconcile',
                          FilledButton(
                            onPressed: _busy ? null : () => _save('reconcile'),
                            child: const Text('Aceitar nova origem'),
                          ),
                        ),
                      ],
                      if (_failure != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _failure!,
                            style: const TextStyle(color: Colors.amber),
                          ),
                        ),
                      if (_order!['status'] == 'new') ...[
                        const Text(
                          'Confirme o atendimento para liberar a separação dos produtos.',
                        ),
                        TextField(
                          controller: _receipt,
                          enabled: !_busy,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText:
                                'Confirmação do cliente: quem, quando e canal',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() => _dirty = true),
                        ),
                        _control(
                          'care.detail.confirm',
                          FilledButton(
                            onPressed: _busy || _order!['sourceChanged'] == true
                                ? null
                                : () => _save('confirm'),
                            child: const Text('Confirmar pedido'),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      for (var i = 0; i < _lines.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: NfePanelRoyalClean(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${(source['items'] as List)[i]['description']}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Código ${(source['items'] as List)[i]['code']} • Solicitado: ${(source['items'] as List)[i]['quantity']} ${(source['items'] as List)[i]['unit']}',
                                ),
                                Text(
                                  'Enviado acumulado: ${_lines[i]['dispatched']} • Pendente de entrega/resolução: ${((source['items'] as List)[i]['quantity'] as num? ?? 0) - (_lines[i]['delivered'] as num) - (_lines[i]['resolved'] as num)}',
                                ),
                                _field(
                                  i,
                                  'separated',
                                  'Separado acumulado (inclui o que já saiu)',
                                  number: true,
                                ),
                                _field(
                                  i,
                                  'delivered',
                                  'Entregue acumulado',
                                  number: true,
                                ),
                                _control(
                                  'care.item.checked',
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Conferi este item e registrei as faltas',
                                    ),
                                    value: _lines[i]['checked'] == true,
                                    onChanged:
                                        closed ||
                                            _order!['status'] == 'new' ||
                                            _busy ||
                                            _order!['sourceChanged'] == true
                                        ? null
                                        : (v) => setState(() {
                                            _lines[i]['checked'] = v;
                                            _dirty = true;
                                          }),
                                  ),
                                  instance: '${widget.orderId}-$i',
                                ),
                                _field(
                                  i,
                                  'reason',
                                  'Motivo da pendência (ex.: falta / compra externa)',
                                ),
                                _field(i, 'note', 'Observação interna'),
                                _field(
                                  i,
                                  'owner',
                                  'Responsável pela resolução',
                                ),
                                _control(
                                  'care.item.due',
                                  TextButton.icon(
                                    onPressed:
                                        closed ||
                                            _busy ||
                                            _order!['status'] == 'new' ||
                                            _order!['sourceChanged'] == true
                                        ? null
                                        : () => _deadline(i),
                                    icon: const Icon(Icons.schedule),
                                    label: Text(
                                      'Prazo: ${_date(_lines[i]['due'])}',
                                    ),
                                  ),
                                  instance: '${widget.orderId}-$i',
                                ),
                                _field(
                                  i,
                                  'agreement',
                                  'Acordo com cliente: quem, quando e canal',
                                ),
                                _control(
                                  'care.item.resolution',
                                  ExpansionTile(
                                    title: const Text('Resolver sem entrega'),
                                    children: [
                                      const Text(
                                        'Uso excepcional. Registre o acordo e trate a regularização fiscal separadamente.',
                                      ),
                                      _field(
                                        i,
                                        'resolved',
                                        'Quantidade resolvida sem entrega',
                                        number: true,
                                      ),
                                      _field(
                                        i,
                                        'resolution',
                                        'Motivo da resolução / referência do acordo',
                                      ),
                                    ],
                                  ),
                                  instance: '${widget.orderId}-$i',
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (!closed && _order!['status'] != 'new') ...[
                        TextField(
                          controller: _receipt,
                          enabled: !_busy,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: _order!['status'] == 'new'
                                ? 'Confirmação do cliente: quem, quando e canal'
                                : 'Recebimento: quem recebeu, quando e evidência',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() => _dirty = true),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final action
                                in (_order!['status'] == 'new'
                                        ? const {'confirm': 'Confirmar pedido'}
                                        : const {
                                            'save': 'Salvar alterações',
                                            'verify': 'Concluir conferência',
                                            'dispatch': 'Registrar saída',
                                            'deliver': 'Registrar entrega',
                                            'close': 'Concluir atendimento',
                                          })
                                    .entries)
                              _control(
                                'care.detail.${action.key}',
                                FilledButton(
                                  onPressed:
                                      _busy || _order!['sourceChanged'] == true
                                      ? null
                                      : () => _save(action.key),
                                  child: Text(action.value),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: LinearProgressIndicator(),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
