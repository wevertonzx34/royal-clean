import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/active_contacts_cache_royal_clean.dart';
import '../../core_royal_clean/services/invoice_list_cache_royal_clean.dart';
import '../../core_royal_clean/services/touch_feedback_royal_clean.dart';
import '../auth/admin_route_guard_royal_clean.dart';
import '../shared/header_actions_royal_clean.dart';
import 'nfe_document_royal_clean.dart';

Future<void> openNfeRoyalClean(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AdminRouteGuardRoyalClean(
          firebaseInitialization: Future<void>.value(),
          builder: (_) => const NfePageRoyalClean(),
        ),
      ),
    );

class NfePageRoyalClean extends StatefulWidget {
  final ActiveContactsCacheRoyalClean? cache;
  final ActiveContactsLoader? loadDetails;
  final bool showHeaderActions;
  const NfePageRoyalClean({
    super.key,
    this.cache,
    this.loadDetails,
    this.showHeaderActions = true,
  });
  @override
  State<NfePageRoyalClean> createState() => _NfePageState();
}

class _NfePageState extends State<NfePageRoyalClean> {
  late final ActiveContactsCacheRoyalClean _cache;
  Map<String, dynamic>? _invoice, _details;
  String? _error;
  bool _busy = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _cache = widget.cache ?? InvoiceListSessionRoyalClean.instance.cache;
    if (widget.cache == null) InvoiceListSessionRoyalClean.instance.start();
    _cache.addListener(_catalogChanged);
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    await _cache.refresh();
    if (!mounted) return;
    final rows = _cache.rows('all');
    if (_invoice == null && rows.isNotEmpty) await _select(rows.first);
  }

  void _catalogChanged() {
    if (!mounted) return;
    setState(() {
      if (!_cache.hasData) {
        _request++;
        _invoice = _details = null;
        _error = null;
        _busy = false;
      }
    });
  }

  Future<void> _select(Map<String, dynamic> row) async {
    final request = ++_request;
    setState(() {
      _invoice = row;
      _details = null;
      _error = null;
      _busy = true;
    });
    try {
      final query = <String, dynamic>{
        'kind': 'invoiceItems',
        'invoiceId': row['id'],
      };
      final result = widget.loadDetails != null
          ? await widget.loadDetails!(query)
          : Map<String, dynamic>.from(
              (await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
                          .httpsCallable(
                            'blingReadData',
                            options: HttpsCallableOptions(
                              timeout: const Duration(seconds: 55),
                            ),
                          )
                          .call(query))
                      .data
                  as Map,
            );
      if (result['invoice'] is Map &&
          (result['invoice'] as Map)['id'] != row['id']) {
        throw const FormatException('Invoice identity mismatch');
      }
      if (result['items'] is! List) {
        throw const FormatException('Invalid items');
      }
      if (mounted && request == _request) setState(() => _details = result);
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _error =
              'Não foi possível consultar esta NF-e. Verifique sua conexão e autorização do Bling e tente novamente.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    final row = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _InvoicePicker(rows: _cache.rows('all')),
    );
    if (row != null && mounted) await _select(row);
  }

  Future<void> _refresh() async {
    await _cache.refresh(force: true);
    if (!mounted) return;
    final selectedId = _invoice?['id'];
    final rows = _cache.rows('all');
    final selected = rows.where((row) => row['id'] == selectedId);
    if (selected.isNotEmpty) {
      await _select(selected.first);
    } else if (_cache.error == null) {
      if (rows.isNotEmpty) {
        await _select(rows.first);
      } else {
        setState(() {
          _invoice = _details = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _request++;
    _cache.removeListener(_catalogChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF020C20),
    appBar: AppBar(
      title: const Text('Consulta de notas', style: TextStyle(fontSize: 17)),
      leading: BackButton(
        onPressed: tactileTapRoyalClean(() => Navigator.of(context).pop()),
      ),
      actions: [if (widget.showHeaderActions) const HeaderActionsRoyalClean()],
    ),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B2852), Color(0xFF020B1D), Color(0xFF061E3E)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: tactileTapRoyalClean(
                            _cache.rows('all').isEmpty ? null : _pick,
                          ),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: Text(
                            _invoice == null
                                ? 'Selecionar NF-e'
                                : 'Trocar NF-e • ${nfeText(_invoice!['code'])}',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Atualizar notas',
                        onPressed: tactileTapRoyalClean(
                          _cache.busy || _busy ? null : _refresh,
                        ),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  if (_cache.busy || _busy) const LinearProgressIndicator(),
                  if (_cache.checkedAt != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Base sincronizada: ${invoiceDateTimeRoyalClean(_cache.checkedAt!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFBCD7EF),
                        ),
                      ),
                    ),
                  if (_cache.error != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Não foi possível atualizar o catálogo. Use Atualizar notas para tentar novamente.',
                      ),
                    ),
                  if (_cache.hasData && _cache.rows('all').isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Nenhuma NF-e sincronizada disponível.'),
                    ),
                  if (_error != null)
                    NfePanelRoyalClean(
                      child: Column(
                        children: [
                          Text(_error!),
                          TextButton(
                            onPressed: tactileTapRoyalClean(
                              () => _select(_invoice!),
                            ),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  NfeDocumentRoyalClean(
                    invoice: _invoice,
                    details: _details,
                    loading: _busy,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _InvoicePicker extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  const _InvoicePicker({required this.rows});
  @override
  State<_InvoicePicker> createState() => _InvoicePickerState();
}

class _InvoicePickerState extends State<_InvoicePicker> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final rows = widget.rows
        .where(
          (row) =>
              '${row['code']} ${row['recipientName']} ${row['recipientDocument']}'
                  .toLowerCase()
                  .contains(_search),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Selecionar NF-e',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: tactileTapRoyalClean(() => Navigator.pop(context)),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Número, destinatário ou CPF/CNPJ',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('Nenhuma nota encontrada.'))
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, index) {
                        final row = rows[index];
                        return ListTile(
                          title: Text('NF-e ${nfeText(row['code'])}'),
                          subtitle: Text(
                            '${nfeText(row['recipientName'])}\n${invoiceDateTimeRoyalClean(row['date'] as String? ?? '')}',
                          ),
                          isThreeLine: true,
                          onTap: tactileTapRoyalClean(
                            () => Navigator.pop(context, row),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
