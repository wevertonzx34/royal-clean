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
  int _invoiceStatus = 0;
  static const _invoiceStatuses = <int, String>{
    0: 'Não canceladas',
    1: 'Pendente',
    2: 'Cancelada',
    3: 'Aguardando recibo',
    4: 'Rejeitada',
    5: 'Autorizada',
    6: 'Emitida DANFE',
    7: 'Registrada',
    8: 'Aguardando protocolo',
    9: 'Denegada',
    10: 'Consulta situação',
    11: 'Bloqueada',
  };
  int _page = 1;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _result;
  Map? _selectedInvoice;
  Map<String, dynamic>? _invoiceDetails;
  String? _detailError;
  bool _loadingDetails = false;
  int _detailRequest = 0;
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
        if (_kind != 'products') ...{
          'start': _date(_range.start),
          'end': _date(_range.end),
        },
        if (_kind == 'invoices' && _invoiceStatus != 0)
          'invoiceStatus': _invoiceStatus,
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

  Future<void> _invoiceMenu(Map invoice) async {
    final selected = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: ListTile(
          leading: const Icon(Icons.inventory_2_outlined),
          title: const Text('Produtos'),
          subtitle: Text('Ver itens da NF-e ${invoice['code']}'),
          onTap: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (selected == true && mounted) _loadInvoice(invoice);
  }

  Future<void> _loadInvoice(Map invoice) async {
    final request = ++_detailRequest;
    setState(() {
      _selectedInvoice = invoice;
      _invoiceDetails = null;
      _detailError = null;
      _loadingDetails = true;
    });
    try {
      final input = <String, dynamic>{
        'kind': 'invoiceItems',
        'invoiceId': invoice['id'],
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
      if (mounted && request == _detailRequest) {
        setState(() => _invoiceDetails = result);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted && request == _detailRequest) {
        setState(
          () => _detailError =
              e.message ?? 'Não foi possível consultar os itens.',
        );
      }
    } catch (_) {
      if (mounted && request == _detailRequest) {
        setState(
          () => _detailError =
              'Não foi possível consultar os itens. Tente novamente.',
        );
      }
    } finally {
      if (mounted && request == _detailRequest) {
        setState(() => _loadingDetails = false);
      }
    }
  }

  void _closeInvoice() {
    _detailRequest++;
    setState(() => _selectedInvoice = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedInvoice != null) {
      final lines = (_invoiceDetails?['items'] as List? ?? []).cast<Map>();
      final note = _invoiceDetails?['invoice'] as Map?;
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _closeInvoice();
        },
        child: AccountLayoutRoyalClean(
          title: 'Produtos da NF-e',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: _closeInvoice,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar às notas'),
              ),
              Text(
                'NF-e ${_selectedInvoice!['code']}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text(
                'Itens registrados nesta nota fiscal, consultados diretamente no Bling.',
              ),
              if (_loadingDetails)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                ),
              if (_detailError != null)
                Text(
                  _detailError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (note != null) Text('Situação: ${note['statusLabel']}'),
              TextButton.icon(
                onPressed: _loadingDetails
                    ? null
                    : () => _loadInvoice(_selectedInvoice!),
                icon: const Icon(Icons.refresh),
                label: const Text('Atualizar itens'),
              ),
              if (_invoiceDetails != null) ...[
                Text(
                  '${lines.length} itens • Total da NF-e: ${_money(_invoiceDetails!['total'])}',
                ),
                Text('Frete informado: ${_money(_invoiceDetails!['freight'])}'),
                const Text(
                  'Valores da NF-e podem incluir frete, tributos e ajustes. Não representam confirmação de pagamento.',
                ),
                if (lines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('O Bling não retornou itens nesta nota.'),
                  ),
                ...lines.map(
                  (line) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line['description'] as String? ?? '',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text('Código: ${line['code']}'),
                          Text(
                            'Quantidade: ${line['quantity'] ?? 'Não informada'} ${line['unit']}',
                          ),
                          Text('Valor unitário: ${_money(line['unitPrice'])}'),
                          Text('Total do item: ${_money(line['total'])}'),
                          if (line['type'] == 'S')
                            const Text('Item de serviço'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
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
              ChoiceChip(
                label: const Text('Notas de saída'),
                selected: _kind == 'invoices',
                onSelected: _busy
                    ? null
                    : (_) => _refresh(page: 1, kind: 'invoices'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _kind == 'products'
                ? 'Catálogo real • preços cadastrados no Bling. Consulta administrativa; ainda não publicados na loja.'
                : _kind == 'invoices'
                ? 'NF-e de saída • período por data de emissão. Selecione Cancelada para consultar cancelamentos. A listagem do Bling não informa valores totais das notas.'
                : 'Pedidos reais do período. Valores incluem as situações retornadas pelo Bling; não representam faturamento fiscal nem recebimentos.',
          ),
          if (_kind != 'products')
            TextButton.icon(
              onPressed: _busy ? null : _period,
              icon: const Icon(Icons.date_range),
              label: Text('${_date(_range.start)} até ${_date(_range.end)}'),
            ),
          if (_kind == 'invoices')
            DropdownButtonFormField<int>(
              initialValue: _invoiceStatus,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Situação da nota'),
              items: _invoiceStatuses.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      _invoiceStatus = value;
                      _refresh(page: 1);
                    },
            ),
          TextButton.icon(
            onPressed: _busy ? null : () => _refresh(),
            icon: const Icon(Icons.sync),
            label: const Text('Atualizar do Bling'),
          ),
          if (_kind == 'invoices')
            const Text(
              'Pressione e segure uma nota para ver Produtos. Você também pode usar o botão de opções da nota.',
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
              child: InkWell(
                onLongPress: _kind == 'invoices'
                    ? () => _invoiceMenu(item)
                    : null,
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
                        : _kind == 'invoices'
                        ? [
                            Text(
                              'NF-e ${item['code']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                tooltip: 'Opções da NF-e ${item['code']}',
                                icon: const Icon(Icons.more_horiz),
                                onPressed: () => _invoiceMenu(item),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Emissão: ${item['date']}'),
                            Text('Saída/operação: ${item['operationDate']}'),
                            Text('Situação: ${item['statusLabel']}'),
                            if ((item['accessKey'] as String? ?? '')
                                .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Chave de acesso'),
                              SelectableText(item['accessKey'] as String),
                            ],
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
