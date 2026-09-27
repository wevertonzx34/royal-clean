import 'package:royal_clean/core_royal_clean/services/touch_feedback_royal_clean.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/active_contacts_cache_royal_clean.dart';
import '../../core_royal_clean/services/product_list_cache_royal_clean.dart';
import '../../core_royal_clean/services/invoice_list_cache_royal_clean.dart';
import '../auth/admin_route_guard_royal_clean.dart';
import '../shared/header_actions_royal_clean.dart';

List<Map<String, dynamic>> productsInBarRoyalClean(
  List<Map<String, dynamic>> rows,
  String category,
) => rows.where((r) {
  if (category == 'Ativos') return r['status'] == 'A';
  if (category == 'Inativos') return r['status'] == 'I';
  return category == 'Outros' && !['A', 'I', 'E'].contains(r['status']);
}).toList();

Future<void> openProductBarRoyalClean(
  BuildContext context, {
  required String category,
  String? chartRun,
  ActiveContactsCacheRoyalClean? cache,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) {
      final page = ProductBarPageRoyalClean(
        category: category,
        chartRun: chartRun,
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

class ProductBarPageRoyalClean extends StatefulWidget {
  final String category;
  final String? chartRun;
  final ActiveContactsCacheRoyalClean? cache;
  const ProductBarPageRoyalClean({
    super.key,
    required this.category,
    this.chartRun,
    this.cache,
  });
  @override
  State<ProductBarPageRoyalClean> createState() => _ProductBarState();
}

class _ProductBarState extends State<ProductBarPageRoyalClean> {
  late final ActiveContactsCacheRoyalClean _cache;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _cache = widget.cache ?? ProductListSessionRoyalClean.instance.cache;
    if (widget.cache == null) ProductListSessionRoyalClean.instance.start();
    _cache.addListener(_changed);
    unawaited(
      _cache.refresh(
        force: widget.chartRun != null && widget.chartRun != _cache.catalogRun,
      ),
    );
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cache.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  String _money(dynamic value) => value is num
      ? 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}'
      : 'Não informado';
  @override
  Widget build(BuildContext context) {
    final rows = productsInBarRoyalClean(_cache.rows('all'), widget.category);
    final checked = DateTime.tryParse(_cache.checkedAt ?? '')?.toLocal();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos da barra'),
        actions: [
          IconButton(
            tooltip: 'Atualizar lista',
            onPressed: tactileTapRoyalClean(
              _cache.busy ? null : () => _cache.refresh(force: true),
            ),
            icon: const Icon(Icons.refresh),
          ),
          const HeaderActionsRoyalClean(),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.category,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _cache.hasData
                        ? '${rows.length} produtos nesta situação'
                        : 'Preparando o catálogo…',
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Posição atual do catálogo. Os períodos não representam histórico de cadastro ou estoque.',
                    style: TextStyle(fontSize: 12),
                  ),
                  if (checked != null)
                    Text(
                      'Base sincronizada • ${invoiceDateTimeRoyalClean(checked.toIso8601String())}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (_cache.hasData &&
                      widget.chartRun != null &&
                      _cache.catalogRun != widget.chartRun)
                    const Text(
                      'A lista recebeu uma sincronização mais recente. Atualize o gráfico ao voltar.',
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
                          : 'Não foi possível carregar o catálogo. Tente novamente.',
                    ),
                    TextButton(
                      onPressed: tactileTapRoyalClean(
                        _cache.busy ? null : () => _cache.refresh(force: true),
                      ),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _cache.hasData && rows.isEmpty
                  ? const Center(child: Text('Nenhum produto nesta situação.'))
                  : ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        String text(String key) =>
                            (row[key]?.toString() ?? '').trim();
                        return Card(
                          key: ValueKey('product-${row['id']}'),
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  text('name').isEmpty
                                      ? 'Produto sem nome informado'
                                      : text('name'),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const Divider(height: 24),
                                Text(
                                  'Código: ${text('code').isEmpty ? 'Não informado' : text('code')}',
                                ),
                                Text('ID Bling: ${row['id']}'),
                                const SizedBox(height: 8),
                                Text('Preço: ${_money(row['price'])}'),
                                Text(
                                  'Estoque informado: ${row['stock'] ?? 'Não informado'} ${text('unit')}',
                                ),
                              ],
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
