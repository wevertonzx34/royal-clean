import 'dart:async';
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/active_contacts_cache_royal_clean.dart';
import '../../core_royal_clean/services/invoice_list_cache_royal_clean.dart';
import '../auth/admin_route_guard_royal_clean.dart';
import '../shared/header_actions_royal_clean.dart';
import 'bling_data_page_royal_clean.dart';

Future<void> openInvoiceBarRoyalClean(
  BuildContext context, {
  required String start,
  String? endExclusive,
  required String metric,
  required String periodLabel,
  ActiveContactsCacheRoyalClean? cache,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) {
      final page = InvoiceBarPageRoyalClean(
        start: start,
        endExclusive: endExclusive,
        metric: metric,
        periodLabel: periodLabel,
        cache: cache,
      );
      return cache != null
          ? page
          : AdminRouteGuardRoyalClean(
              firebaseInitialization: Future<void>.value(),
              builder: (_) => page,
            );
    },
  ),
);

class InvoiceBarPageRoyalClean extends StatefulWidget {
  final String start, metric, periodLabel;
  final String? endExclusive;
  final ActiveContactsCacheRoyalClean? cache;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? loadItems;
  const InvoiceBarPageRoyalClean({
    super.key,
    required this.start,
    this.endExclusive,
    required this.metric,
    required this.periodLabel,
    this.cache,
    this.loadItems,
  });
  @override
  State<InvoiceBarPageRoyalClean> createState() => _InvoiceBarState();
}

class _InvoiceBarState extends State<InvoiceBarPageRoyalClean> {
  late final ActiveContactsCacheRoyalClean _cache;
  final _scroll = ScrollController();
  int _visible = 50;
  @override
  void initState() {
    super.initState();
    _cache = widget.cache ?? InvoiceListSessionRoyalClean.instance.cache;
    if (widget.cache == null) InvoiceListSessionRoyalClean.instance.start();
    _cache.addListener(_changed);
    unawaited(_cache.refresh());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _products(Map<String, dynamic> invoice) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) {
          final page = BlingDataPageRoyalClean(
            initialInvoice: invoice,
            load: widget.loadItems,
          );
          return widget.cache != null
              ? page
              : AdminRouteGuardRoyalClean(
                  firebaseInitialization: Future<void>.value(),
                  builder: (_) => page,
                );
        },
      ),
    );
  }

  @override
  void dispose() {
    _cache.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = invoicesInBarRoyalClean(
      _cache.rows('all'),
      start: widget.start,
      endExclusive: widget.endExclusive,
      metric: widget.metric,
    );
    final shown = rows.take(_visible).toList();
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('Notas do período'),
        actions: [
          IconButton(
            tooltip: 'Atualizar lista',
            onPressed: _cache.busy ? null : () => _cache.refresh(force: true),
            icon: const Icon(Icons.refresh),
          ),
          const HeaderActionsRoyalClean(),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.metric,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.periodLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _cache.hasData
                        ? '${rows.length} notas neste intervalo'
                        : 'Preparando a lista de notas…',
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Período pela data de emissão • horários conforme o Bling',
                    style: TextStyle(fontSize: 12),
                  ),
                  const Text(
                    'Pressione e segure uma nota para consultar seus produtos.',
                    style: TextStyle(fontSize: 12),
                  ),
                  if (_cache.checkedAt != null)
                    Text(
                      'Base sincronizada • ${invoiceDateTimeRoyalClean(DateTime.parse(_cache.checkedAt!).toLocal().toIso8601String())}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (widget.metric == 'Entregues')
                    const Text(
                      'Situação fiscal transmitida; não confirma entrega física.',
                      style: TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
            if (_cache.busy) const LinearProgressIndicator(),
            if (_cache.error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _cache.hasData
                          ? 'Não foi possível atualizar. A última lista completa foi preservada.'
                          : 'A lista ainda não está disponível. Aguarde a sincronização e tente novamente.',
                    ),
                    TextButton(
                      onPressed: _cache.busy
                          ? null
                          : () => _cache.refresh(force: true),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _cache.hasData && rows.isEmpty
                  ? const Center(
                      child: Text('Nenhuma nota nesta categoria e período.'),
                    )
                  : ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount:
                          shown.length + (rows.length > _visible ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == shown.length) {
                          return OutlinedButton(
                            onPressed: () => setState(() => _visible += 50),
                            child: const Text('Mostrar mais notas'),
                          );
                        }
                        final row = shown[index];
                        String text(String key) =>
                            (row[key] as String? ?? '').trim();
                        final name = text('recipientName'),
                            document = text('recipientDocument');
                        return Card(
                          key: ValueKey('invoice-${row['id']}'),
                          margin: EdgeInsets.zero,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onLongPress: () => _products(row),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.receipt_long_rounded),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'NF-e ${text('code').isEmpty ? 'Sem número' : text('code')}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip:
                                            'Produtos da NF-e ${text('code')}',
                                        onPressed: () => _products(row),
                                        icon: const Icon(
                                          Icons.inventory_2_outlined,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  const Text(
                                    'Razão social / destinatário',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    name.isEmpty
                                        ? 'Não informado no Bling'
                                        : name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    document
                                                .replaceAll(RegExp(r'\D'), '')
                                                .length ==
                                            14
                                        ? 'CNPJ'
                                        : 'CPF / CNPJ',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    document.isEmpty
                                        ? 'Não informado no Bling'
                                        : document,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Data e hora de emissão',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(invoiceDateTimeRoyalClean(text('date'))),
                                ],
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
    );
  }
}
