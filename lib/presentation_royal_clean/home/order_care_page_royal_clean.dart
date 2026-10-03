import 'dart:async';
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
    : 'Não foi possível consultar o pedido. Tente novamente.';
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
  bool _busy = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final result =
          await (widget.call ?? (input) => _invoke('orderCare', input))({
            'orderId': widget.orderId,
            'action': 'open',
          });
      if (mounted) {
        setState(() {
          _order = Map<String, dynamic>.from(result['order']);
          _failure = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _failure = _error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = (_order?['latestSource'] ?? _order?['source']) as Map?;
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: Text('Pedido ${source?['code'] ?? ''}'),
          leading: _control(
            'care.detail.back',
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
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
                    NfeDocumentRoyalClean(
                      isOrder: true,
                      invoice: {
                        'code': source!['code'],
                        'date': source['date'],
                        'recipientName': source['name'],
                        'recipientDocument': source['document'],
                        'recipientAddress': source['address'],
                        'statusLabel':
                            [
                                  (_order!['fiscal'] as Map)['number'],
                                  (_order!['fiscal'] as Map)['status'],
                                ]
                                .whereType<String>()
                                .where((value) => value.isNotEmpty)
                                .join(' • '),
                        'total': source['total'],
                      },
                      details: {
                        'items': source['items'],
                        'total': source['total'],
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
