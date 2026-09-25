import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../auth/account_ui_royal_clean.dart';

class BlingDataPageRoyalClean extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)? load;
  const BlingDataPageRoyalClean({super.key, this.load});
  @override
  State<BlingDataPageRoyalClean> createState() => _BlingDataState();
}

class _BlingDataState extends State<BlingDataPageRoyalClean> {
  String _kind = 'products';
  int _page = 1;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _result;
  late DateTimeRange _range;
  String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _money(dynamic value) => value is num
      ? 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}'
      : 'Não informado';
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month),
      end: DateTime(now.year, now.month, now.day),
    );
    _refresh();
  }

  Future<void> _refresh({int? page, String? kind}) async {
    if (_busy) return;
    setState(() {
      _page = page ?? _page;
      _kind = kind ?? _kind;
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final input = <String, dynamic>{
        'kind': _kind,
        'page': _page,
        if (_kind == 'sales') ...{
          'start': _date(_range.start),
          'end': _date(_range.end),
        },
      };
      final Map<String, dynamic> result;
      if (widget.load != null) {
        result = await widget.load!(input);
      } else {
        final response =
            await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
                .httpsCallable(
                  'blingReadData',
                  options: HttpsCallableOptions(
                    timeout: const Duration(seconds: 55),
                  ),
                )
                .call(input);
        result = Map<String, dynamic>.from(response.data as Map);
      }
      if (mounted) setState(() => _result = result);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.message ?? 'Não foi possível consultar o Bling.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível consultar o Bling. Verifique a conexão e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _period() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (range == null || !mounted) return;
    if (range.duration.inDays > 366) {
      showAccountMessageRoyalClean(
        context,
        'Escolha um período de até um ano.',
      );
      return;
    }
    _range = range;
    await _refresh(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final items = (_result?['items'] as List? ?? []).cast<Map>();
    final queried = DateTime.tryParse(
      _result?['checkedAt'] as String? ?? '',
    )?.toLocal();
    return AccountLayoutRoyalClean(
      title: 'Dados do Bling',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            children: [
              ChoiceChip(
                label: const Text('Produtos'),
                selected: _kind == 'products',
                onSelected: _busy
                    ? null
                    : (_) => _refresh(page: 1, kind: 'products'),
              ),
              ChoiceChip(
                label: const Text('Pedidos de venda'),
                selected: _kind == 'sales',
                onSelected: _busy
                    ? null
                    : (_) => _refresh(page: 1, kind: 'sales'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _kind == 'products'
                ? 'Catálogo real • preços cadastrados no Bling. Consulta administrativa; ainda não publicados na loja.'
                : 'Pedidos reais do período. Valores incluem as situações retornadas pelo Bling; não representam faturamento fiscal nem recebimentos.',
          ),
          if (_kind == 'sales')
            TextButton.icon(
              onPressed: _busy ? null : _period,
              icon: const Icon(Icons.date_range),
              label: Text('${_date(_range.start)} até ${_date(_range.end)}'),
            ),
          TextButton.icon(
            onPressed: _busy ? null : () => _refresh(),
            icon: const Icon(Icons.sync),
            label: const Text('Atualizar do Bling'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar à integração'),
            ),
          ],
          if (queried != null)
            Text(
              'Consultado em ${_date(queried)} às ${TimeOfDay.fromDateTime(queried).format(context)}',
            ),
          if (_result != null && items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Nenhum registro nesta página.'),
            ),
          if (_kind == 'sales' && items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Soma dos ${items.length} pedidos desta página: ${_money(items.fold<double>(0, (sum, p) => sum + ((p['total'] as num?)?.toDouble() ?? 0)))}',
              ),
            ),
          ...items.map(
            (item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _kind == 'products'
                      ? [
                          Text(
                            item['name'] as String? ?? '',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('Código: ${item['code']} • ${item['unit']}'),
                          Text('Preço cadastrado: ${_money(item['price'])}'),
                          Text(
                            'Situação: ${item['status'] == 'A'
                                ? 'Ativo'
                                : item['status'] == 'I'
                                ? 'Inativo'
                                : item['status']}',
                          ),
                          Text(
                            item['stock'] == null
                                ? 'Saldo não informado nesta consulta'
                                : 'Saldo virtual: ${item['stock']}',
                          ),
                        ]
                      : [
                          Text(
                            'Pedido ${item['code']}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text('Data: ${item['date']}'),
                          Text('Valor: ${_money(item['total'])}'),
                          Text(
                            'Código da situação no Bling: ${item['status']}',
                          ),
                        ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              TextButton(
                onPressed: !_busy && _page > 1
                    ? () => _refresh(page: _page - 1)
                    : null,
                child: const Text('Anterior'),
              ),
              Text('Página $_page'),
              TextButton(
                onPressed: !_busy && _result?['hasMore'] == true
                    ? () => _refresh(page: _page + 1)
                    : null,
                child: const Text('Próxima'),
              ),
            ],
          ),
          const Text(
            'Atualização sob demanda. Cada página consulta até 25 registros e atualiza a cópia privada no servidor.',
          ),
        ],
      ),
    );
  }
}
