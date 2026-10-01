import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/active_contacts_cache_royal_clean.dart';
import '../../core_royal_clean/services/invoice_list_cache_royal_clean.dart';
import '../../core_royal_clean/services/touch_feedback_royal_clean.dart';
import '../auth/admin_route_guard_royal_clean.dart';
import '../shared/header_actions_royal_clean.dart';
import '../shared/layout_button_royal_clean.dart';
import 'nfe_document_royal_clean.dart';
import 'order_care_page_royal_clean.dart';

typedef ProductionCall =
    Future<Map<String, dynamic>> Function(Map<String, dynamic>);
Future<Map<String, dynamic>> _call(Map<String, dynamic> data) async =>
    Map<String, dynamic>.from(
      (await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
                  .httpsCallable(
                    'productionOrder',
                    options: HttpsCallableOptions(
                      timeout: const Duration(seconds: 55),
                    ),
                  )
                  .call(data))
              .data
          as Map,
    );

Future<void> openProductionRoyalClean(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AdminRouteGuardRoyalClean(
          firebaseInitialization: Future<void>.value(),
          builder: (_) => const ProductionOrdersPageRoyalClean(),
        ),
      ),
    );

const _background = Color(0xFF020B1D), _cyan = Color(0xFF69DCFF);
String _operationalDate(String value) => invoiceDateTimeRoyalClean(
  DateTime.tryParse(value)?.toLocal().toIso8601String() ?? value,
);
const _states = {
  'open': 'Aberta',
  'verified': 'Verificada',
  'route': 'Em rota',
  'delivered': 'Entregue',
};
const _colors = {
  'open': Color(0xFFFFCA70),
  'verified': Color(0xFF69E2B1),
  'route': Color(0xFF77B6FF),
  'delivered': Color(0xFFBDA0FF),
};
Widget _badge(String status) => Chip(
  backgroundColor: _colors[status]!.withValues(alpha: .15),
  side: BorderSide(color: _colors[status]!),
  label: Text(_states[status]!, style: TextStyle(color: _colors[status])),
);

class ProductionOrdersPageRoyalClean extends StatefulWidget {
  final ActiveContactsCacheRoyalClean? cache;
  final ProductionCall? call;
  final bool showHeaderActions;
  const ProductionOrdersPageRoyalClean({
    super.key,
    this.cache,
    this.call,
    this.showHeaderActions = true,
  });
  @override
  State<ProductionOrdersPageRoyalClean> createState() => _OrdersState();
}

class _OrdersState extends State<ProductionOrdersPageRoyalClean> {
  late final ActiveContactsCacheRoyalClean _cache;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _feed;
  final Map<String, String> _statuses = {};
  String _search = '', _filter = 'all';
  String? _error;
  @override
  void initState() {
    super.initState();
    _cache = widget.cache ?? InvoiceListSessionRoyalClean.instance.cache;
    if (widget.cache == null) InvoiceListSessionRoyalClean.instance.start();
    _cache.addListener(_changed);
    unawaited(_cache.refresh());
    if (widget.call == null) {
      _feed = FirebaseFirestore.instance
          .collection('production_orders')
          .snapshots(includeMetadataChanges: true)
          .listen(
            (snapshot) {
              if (!mounted) return;
              setState(() {
                _statuses.clear();
                for (final doc in snapshot.docs) {
                  _statuses[doc.id] = doc.data()['status'] as String? ?? 'open';
                }
                _error = null;
              });
            },
            onError: (Object _) {
              if (mounted) {
                setState(
                  () => _error =
                      'Não foi possível confirmar os estados. Abra a ordem para consultar o servidor.',
                );
              }
            },
          );
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cache.removeListener(_changed);
    unawaited(_feed?.cancel());
    super.dispose();
  }

  Future<void> _open(Map<String, dynamic> row) async {
    if (widget.call == null) {
      try {
        final links = await FirebaseFirestore.instance
            .collection('order_care_invoice_links/${row['id']}/orders')
            .get();
        if (!mounted) return;
        if (links.docs.length == 1) {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => AdminRouteGuardRoyalClean(
                firebaseInitialization: Future<void>.value(),
                builder: (_) =>
                    OrderCareDetailRoyalClean(orderId: links.docs.single.id),
              ),
            ),
          );
          return;
        }
        if (links.docs.length > 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Esta NF-e reúne pedidos. Acesse os pedidos pela Central de atendimento.',
              ),
            ),
          );
          return;
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível verificar o vínculo com pedidos. Tente novamente.',
              ),
            ),
          );
        }
        return;
      }
    }
    final status = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => widget.call != null
            ? ProductionCheckPageRoyalClean(
                invoiceId: row['id'] as String,
                call: widget.call,
                showHeaderActions: widget.showHeaderActions,
              )
            : AdminRouteGuardRoyalClean(
                firebaseInitialization: Future<void>.value(),
                builder: (_) => ProductionCheckPageRoyalClean(
                  invoiceId: row['id'] as String,
                ),
              ),
      ),
    );
    if (mounted && status != null) {
      setState(() => _statuses[row['id'] as String] = status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _cache.rows('all').where((row) {
      final status = _statuses[row['id']] ?? 'open';
      return (_filter == 'all' || status == _filter) &&
          '${row['code']} ${row['recipientName']} ${row['recipientDocument']}'
              .toLowerCase()
              .contains(_search);
    }).toList();
    return Theme(
      data: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(scaffoldBackgroundColor: _background),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Produção • OS / NF-e'),
          backgroundColor: _background,
          leading: LayoutButtonRoyalClean(
            id: 'production.list.back',
            child: IconButton(
              tooltip: 'Voltar ao estoque',
              icon: const Icon(Icons.arrow_back),
              onPressed: tactileTapRoyalClean(() => Navigator.pop(context)),
            ),
          ),
          actions: [
            if (widget.showHeaderActions) const HeaderActionsRoyalClean(),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ordens de conferência',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: _cyan,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Origem: notas de saída do Bling. Selecione uma nota para conferir os produtos. Não substitui XML ou DANFE.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) =>
                          setState(() => _search = value.toLowerCase().trim()),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'NF-e, razão social ou CPF/CNPJ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final key in ['all', 'open', 'verified'])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: LayoutButtonRoyalClean(
                                id: 'production.list.filter',
                                instanceKey: key,
                                child: ChoiceChip(
                                  label: Text(
                                    key == 'all' ? 'Todas' : _states[key]!,
                                  ),
                                  selected: _filter == key,
                                  onSelected: (_) =>
                                      setState(() => _filter = key),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Text(
                      'Próximas etapas: Em rota • Entregue (ainda não habilitadas)',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.amber),
                      ),
                    if (_cache.error != null)
                      LayoutButtonRoyalClean(
                        id: 'production.list.retry',
                        child: TextButton.icon(
                          onPressed: _cache.busy
                              ? null
                              : () => _cache.refresh(force: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text(
                            'Falha ao atualizar • Tentar novamente',
                          ),
                        ),
                      ),
                    if (_cache.error is FirebaseFunctionsException)
                      Text(
                        (_cache.error as FirebaseFunctionsException).message ??
                            'Consulta indisponível.',
                        style: const TextStyle(color: Colors.amber),
                      ),
                  ],
                ),
              ),
              if (!_cache.hasData && _cache.busy)
                const LinearProgressIndicator(),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(
                          _cache.busy && !_cache.hasData
                              ? 'Consultando notas sincronizadas…'
                              : 'Nenhuma nota disponível neste filtro.',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index],
                              status = _statuses[row['id']] ?? 'open';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: LayoutButtonRoyalClean(
                              id: 'production.list.order',
                              instanceKey: row['id'] as String,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: tactileTapRoyalClean(() => _open(row)),
                                child: NfePanelRoyalClean(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'OS • NF-e ${nfeText(row['code'])}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 19,
                                                color: _cyan,
                                              ),
                                            ),
                                          ),
                                          _badge(status),
                                        ],
                                      ),
                                      Text(
                                        nfeText(row['recipientName']),
                                        style: const TextStyle(fontSize: 17),
                                      ),
                                      Text(
                                        'CPF/CNPJ: ${nfeText(row['recipientDocument'])}',
                                      ),
                                      Text(
                                        'Emissão: ${invoiceDateTimeRoyalClean(row['date'] as String? ?? '')}',
                                      ),
                                      if (!['5', '6'].contains(row['status']))
                                        const Text(
                                          'Conferência bloqueada: NF-e não autorizada ou cancelada.',
                                          style: TextStyle(color: Colors.amber),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductionCheckPageRoyalClean extends StatefulWidget {
  final String invoiceId;
  final ProductionCall? call;
  final bool showHeaderActions;
  const ProductionCheckPageRoyalClean({
    super.key,
    required this.invoiceId,
    this.call,
    this.showHeaderActions = true,
  });
  @override
  State<ProductionCheckPageRoyalClean> createState() => _CheckState();
}

class _CheckState extends State<ProductionCheckPageRoyalClean> {
  Map<String, dynamic>? _order;
  final List<TextEditingController> _quantities = [], _notes = [];
  final List<bool> _checked = [], _unavailable = [];
  bool _busy = false, _dirty = false;
  String? _error, _requestId, _requestAction;
  List<Map> get _items => (_order?['items'] as List? ?? []).cast<Map>();
  bool get _locked =>
      _order?['status'] != 'open' ||
      !['5', '6'].contains((_order?['invoice'] as Map?)?['status']);
  num? _quantity(int i) =>
      num.tryParse(_quantities[i].text.trim().replaceAll(',', '.'));
  bool _matches(int i) {
    final q = _quantity(i), expected = _items[i]['quantity'];
    return q != null &&
        q.isFinite &&
        expected is num &&
        expected > 0 &&
        (q - expected).abs() < .000001;
  }

  bool get _ready =>
      _items.isNotEmpty &&
      List.generate(
        _items.length,
        (i) => i,
      ).every((i) => _checked[i] && !_unavailable[i] && _matches(i));
  @override
  void initState() {
    super.initState();
    unawaited(_send('open'));
  }

  void _clear() {
    for (final c in [..._quantities, ..._notes]) {
      c.dispose();
    }
    _quantities.clear();
    _notes.clear();
    _checked.clear();
    _unavailable.clear();
  }

  void _apply(Map<String, dynamic> order) {
    _clear();
    _order = order;
    for (final check in order['checks'] as List) {
      _quantities.add(
        TextEditingController(text: nfeQuantity(check['quantity'])),
      );
      _notes.add(
        TextEditingController(text: check['observation'] as String? ?? ''),
      );
      _checked.add(check['checked'] == true);
      _unavailable.add(check['unavailable'] == true);
    }
    _dirty = false;
    _requestId = null;
    _requestAction = null;
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  void _edit() {
    setState(() {
      _dirty = true;
      _requestId = null;
      _error = null;
    });
  }

  Future<void> _send(String action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    if (_requestId == null || _requestAction != action) {
      _requestId =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
      _requestAction = action;
    }
    try {
      final data = await (widget.call ?? _call)({
        'action': action,
        'invoiceId': widget.invoiceId,
        if (action != 'open') ...{
          'revision': _order!['revision'],
          'requestId': _requestId,
          'checks': [
            for (var i = 0; i < _items.length; i++)
              {
                'line': _items[i]['line'],
                'quantity': _quantity(i) ?? -1,
                'checked': _checked[i],
                'observation': _notes[i].text,
                'unavailable': _unavailable[i],
              },
          ],
        },
      });
      if (!mounted) return;
      setState(() {
        _apply(Map<String, dynamic>.from(data['order'] as Map));
        if (data['sourceChanged'] == true) {
          _error =
              'A NF-e mudou no Bling. A conferência foi reaberta; confira os produtos novamente.';
        }
      });
      if (action != 'open' && data['sourceChanged'] != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _order!['status'] == 'verified'
                  ? 'OS verificada e registrada no servidor.'
                  : 'Conferência salva em aberto.',
            ),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(
          () => _error =
              e.message ??
              'Não foi possível confirmar a gravação. Tente novamente.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível confirmar a operação. Seus campos foram preservados; tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Concluir conferência?'),
        content: const Text(
          'Confirme que todos os produtos foram conferidos fisicamente e que as quantidades correspondem à NF-e. O responsável e o horário ficarão registrados.',
        ),
        actions: [
          LayoutButtonRoyalClean(
            id: 'production.verify.cancel',
            child: TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Revisar'),
            ),
          ),
          LayoutButtonRoyalClean(
            id: 'production.verify.confirm',
            child: FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Confirmar verificação'),
            ),
          ),
        ],
      ),
    );
    if (approved == true && mounted) await _send('verify');
  }

  Future<void> _history() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _background,
    builder: (_) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('production_orders')
              .doc(widget.invoiceId)
              .collection('audit')
              .orderBy('at', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Não foi possível consultar o histórico.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Histórico da conferência',
                  style: TextStyle(fontSize: 22, color: _cyan),
                ),
                const Text(
                  'Últimos 50 registros • arraste para baixo para fechar',
                  style: TextStyle(color: Colors.white70),
                ),
                for (final doc in snapshot.data!.docs) ...[
                  const Divider(),
                  Builder(
                    builder: (_) {
                      final row = doc.data();
                      const labels = {
                        'opened': 'Ordem aberta',
                        'saved': 'Conferência salva',
                        'verified': 'Verificada',
                        'source_changed':
                            'NF-e alterada • conferência reaberta',
                      };
                      final at = row['at'] as Timestamp?;
                      final checks = (row['checks'] as List? ?? []).cast<Map>();
                      final items = (row['items'] as List? ?? []).cast<Map>();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${labels[row['type']] ?? 'Registro'} • revisão ${row['revision']}',
                            style: const TextStyle(
                              color: _cyan,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${nfeText(row['actorName'])}\n${at == null ? 'Horário não informado' : _operationalDate(at.toDate().toIso8601String())}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          for (final check in checks)
                            Text(
                              '${items.where((i) => i['line'] == check['line']).map((i) => nfeText(i['description'])).firstOrNull ?? 'Produto'}: ${nfeQuantity(check['quantity'])} • ${check['checked'] == true ? 'conferido' : 'pendente'}${(check['observation'] as String? ?? '').isEmpty ? '' : '\nObservação: ${check['observation']}'}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );

  Future<void> _leave() async {
    if (_busy) return;
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Alterações não salvas'),
          content: const Text('Voltar sem salvar esta conferência?'),
          actions: [
            LayoutButtonRoyalClean(
              id: 'production.leave.stay',
              child: TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Continuar conferindo'),
              ),
            ),
            LayoutButtonRoyalClean(
              id: 'production.leave.discard',
              child: TextButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Descartar alterações'),
              ),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (!mounted) return;
    setState(() => _dirty = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, _order?['status']);
    });
  }

  @override
  Widget build(BuildContext context) {
    final invoice = (_order?['invoice'] as Map?) ?? {};
    return Theme(
      data: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(scaffoldBackgroundColor: _background),
      child: PopScope<String>(
        canPop: !_dirty && !_busy,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_leave());
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Conferência • OS / NF-e'),
            backgroundColor: _background,
            leading: LayoutButtonRoyalClean(
              id: 'production.check.back',
              child: IconButton(
                tooltip: 'Voltar às ordens',
                icon: const Icon(Icons.arrow_back),
                onPressed: tactileTapRoyalClean(_leave),
              ),
            ),
            actions: [
              if (widget.showHeaderActions) const HeaderActionsRoyalClean(),
            ],
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.amber),
                    ),
                  ),
                if (_order == null && !_busy)
                  LayoutButtonRoyalClean(
                    id: 'production.check.retry',
                    child: FilledButton(
                      onPressed: () => _send('open'),
                      child: const Text('Tentar novamente'),
                    ),
                  ),
                if (_order != null) ...[
                  NfePanelRoyalClean(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'OS • NF-e ${nfeText(invoice['code'])}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _cyan,
                                ),
                              ),
                            ),
                            _badge(_order!['status'] as String),
                          ],
                        ),
                        Text(
                          nfeText(invoice['recipientName']),
                          style: const TextStyle(fontSize: 19),
                        ),
                        Text(
                          'CPF/CNPJ: ${nfeText(invoice['recipientDocument'])}',
                        ),
                        Text(
                          'Emissão NF-e: ${invoiceDateTimeRoyalClean(invoice['date'] as String? ?? '')}',
                        ),
                        Text(
                          'Abertura da OS: ${_operationalDate(_order!['createdAt'] as String)}',
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ordem interna de conferência baseada na NF-e. Não substitui o documento fiscal nem cria uma Ordem de Serviço no Bling.',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_checked.where((v) => v).length} de ${_items.length} produtos confirmados',
                    style: const TextStyle(fontSize: 18, color: _cyan),
                  ),
                  if (_locked)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Somente leitura: ordem já verificada ou NF-e não autorizada.',
                        style: TextStyle(color: Colors.amber),
                      ),
                    ),
                  for (var i = 0; i < _items.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: NfePanelRoyalClean(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}. ${nfeText(_items[i]['description'])}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Código: ${nfeText(_items[i]['code'])} • ${nfeText(_items[i]['unit'])}',
                            ),
                            Text(
                              'Solicitado: ${nfeQuantity(_items[i]['quantity'])} • Unitário: ${nfeMoney(_items[i]['unitPrice'])}',
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _quantities[i],
                              enabled: !_locked && !_busy,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Quantidade encontrada / separada',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                _checked[i] = false;
                                _edit();
                              },
                            ),
                            LayoutButtonRoyalClean(
                              id: 'production.check.missing',
                              instanceKey: '${widget.invoiceId}:$i',
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Falta ou indisponibilidade'),
                                value: _unavailable[i],
                                onChanged: _locked || _busy
                                    ? null
                                    : (value) {
                                        _unavailable[i] = value ?? false;
                                        if (_unavailable[i]) {
                                          _checked[i] = false;
                                        }
                                        _edit();
                                      },
                              ),
                            ),
                            TextField(
                              controller: _notes[i],
                              enabled: !_locked && !_busy,
                              maxLength: 1000,
                              minLines: 1,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: _unavailable[i]
                                    ? 'Observação obrigatória'
                                    : 'Observação da conferência',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) => _edit(),
                            ),
                            LayoutButtonRoyalClean(
                              id: 'production.check.confirm-line',
                              instanceKey: '${widget.invoiceId}:$i',
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Produto e quantidade conferidos',
                                ),
                                subtitle: Text(
                                  _matches(i)
                                      ? 'Quantidade de acordo com a NF-e.'
                                      : 'Informe a quantidade exata para confirmar.',
                                ),
                                value: _checked[i],
                                onChanged:
                                    _locked ||
                                        _busy ||
                                        _unavailable[i] ||
                                        !_matches(i)
                                    ? null
                                    : (value) {
                                        _checked[i] = value ?? false;
                                        _edit();
                                      },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  NfePanelRoyalClean(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Total da NF-e: ${nfeMoney(_order!['total'])}',
                          style: const TextStyle(fontSize: 20, color: _cyan),
                        ),
                        Text(
                          'Último registro: ${_operationalDate(_order!['updatedAt'] as String)}',
                        ),
                        Text(
                          'Responsável: ${nfeText(_order!['updatedByName'])} • Revisão ${_order!['revision']}',
                        ),
                        if (_order!['verifiedAt'] != null)
                          Text(
                            'Verificada em: ${_operationalDate(_order!['verifiedAt'] as String)}',
                          ),
                        const SizedBox(height: 12),
                        LayoutButtonRoyalClean(
                          id: 'production.check.save',
                          child: OutlinedButton.icon(
                            onPressed: tactileTapRoyalClean(
                              _locked || _busy || !_dirty
                                  ? null
                                  : () => _send('save'),
                            ),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Salvar conferência em aberto'),
                          ),
                        ),
                        if (widget.call == null)
                          LayoutButtonRoyalClean(
                            id: 'production.check.history',
                            child: TextButton.icon(
                              onPressed: _history,
                              icon: const Icon(Icons.history),
                              label: const Text('Histórico da conferência'),
                            ),
                          ),
                        LayoutButtonRoyalClean(
                          id: 'production.check.verify',
                          child: FilledButton.icon(
                            onPressed: tactileTapRoyalClean(
                              _locked || _busy || !_ready ? null : _verify,
                            ),
                            icon: const Icon(Icons.verified_outlined),
                            label: const Text('Concluir • Verificada'),
                          ),
                        ),
                        const Text(
                          'Faltas e divergências impedem a verificação. Em rota e Entregue serão habilitados em outra etapa.',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
