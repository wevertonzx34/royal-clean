import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/invoice_list_cache_royal_clean.dart';

String nfeText(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : 'Não informado';
num? nfeNumber(dynamic value) => value is num && value.isFinite ? value : null;
String nfeMoney(dynamic value) {
  final number = nfeNumber(value);
  if (number == null) return 'Não informado';
  final parts = number.abs().toStringAsFixed(2).split('.');
  final integer = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]}.',
  );
  return '${number < 0 ? '-' : ''}R\$ $integer,${parts.last}';
}

String nfeQuantity(dynamic value) {
  final number = nfeNumber(value);
  return number == null
      ? 'Não informado'
      : number
            .toString()
            .replaceFirst(RegExp(r'\.0$'), '')
            .replaceAll('.', ',');
}

/// Presentation only. No guessed fiscal fields and no writes to the catalog.
class NfeDocumentRoyalClean extends StatelessWidget {
  final Map<String, dynamic>? invoice, details;
  final bool loading;
  const NfeDocumentRoyalClean({
    super.key,
    this.invoice,
    this.details,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final note = <String, dynamic>{
      ...?invoice,
      if (details?['invoice'] is Map)
        ...Map<String, dynamic>.from(details!['invoice'] as Map),
    };
    final items = (details?['items'] as List? ?? []).whereType<Map>().toList();
    num? sum(String key) =>
        details == null || items.any((item) => nfeNumber(item[key]) == null)
        ? null
        : items.fold<num>(0, (total, item) => total + (item[key] as num));
    final total = nfeNumber(details?['total']) ?? nfeNumber(invoice?['total']);
    final rows = <(String, String)>[
      ('Nº de itens', details == null ? 'Não informado' : '${items.length}'),
      ('Soma das qtdes.', nfeQuantity(sum('quantity'))),
      ('Total dos itens', nfeMoney(sum('total'))),
      ('Outros valores', 'Não informado'),
      ('Total da NF-e', nfeMoney(total)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: AspectRatio(
                aspectRatio: 1,
                child: NfePanelRoyalClean(
                  key: ValueKey('nfe-empty-logo'),
                  child: SizedBox.expand(),
                ),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: NfePanelRoyalClean(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'ROYAL CLEAN DISTRIBUIDORA LTDA',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('CNPJ 62.581.826/0001-49', textAlign: TextAlign.right),
                    SizedBox(height: 5),
                    Text(
                      'R. Ouro Preto\nSetor Candida de Morais, Goiânia-GO',
                      textAlign: TextAlign.right,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Identificação da empresa no aplicativo',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, color: Color(0xFFABD4ED)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const NfePanelRoyalClean(
          child: Center(
            child: Text(
              'NF-e',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                shadows: [Shadow(color: Color(0xFF25BFFF), blurRadius: 14)],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final recipient = NfePanelRoyalClean(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SectionTitle('Destinatário'),
                  _Field('Razão social / nome', nfeText(note['recipientName'])),
                  _Field('CPF / CNPJ', nfeText(note['recipientDocument'])),
                  _Field('Endereço', nfeText(note['recipientAddress'])),
                  _Field(
                    'Situação fiscal',
                    nfeText(note['statusLabel'] ?? _status(note['status'])),
                  ),
                ],
              ),
            );
            final metadata = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NfePanelRoyalClean(
                  child: _Field('Número da NF-e', nfeText(note['code'])),
                ),
                const SizedBox(height: 10),
                NfePanelRoyalClean(
                  child: _Field(
                    'Data e hora',
                    note['date'] is String
                        ? invoiceDateTimeRoyalClean(note['date'] as String)
                        : 'Não informadas',
                  ),
                ),
              ],
            );
            if (constraints.maxWidth < 330 ||
                MediaQuery.textScalerOf(context).scale(14) > 20) {
              return Column(
                children: [recipient, const SizedBox(height: 10), metadata],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: recipient),
                const SizedBox(width: 10),
                Expanded(flex: 4, child: metadata),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        NfePanelRoyalClean(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionTitle('Produtos / Serviços'),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('Consultando itens no Bling…')),
                )
              else if (details == null)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Selecione uma NF-e para consultar seus produtos.',
                  ),
                )
              else if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nenhum item informado nesta nota.'),
                )
              else
                _ItemsGrid(items: items),
            ],
          ),
        ),
        const SizedBox(height: 14),
        NfePanelRoyalClean(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryGrid(values: rows),
              const SizedBox(height: 8),
              const Text(
                'Soma das quantidades conforme as unidades de cada item. Outros valores não são deduzidos do total.',
                style: TextStyle(fontSize: 12, color: Color(0xFFABD4ED)),
              ),
              if (nfeNumber(details?['freight']) != null)
                Text('Frete informado: ${nfeMoney(details!['freight'])}'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        NfePanelRoyalClean(
          child: _SummaryGrid(
            values: [
              ('Data da aprovação', 'Não informada'),
              ('Assinatura do cliente', 'Não disponível'),
              ('Valor total da NF-e', nfeMoney(total)),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18, horizontal: 6),
          child: Text(
            'Visualização de consulta do aplicativo. Não substitui o XML nem o DANFE oficial.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFFBCD7EF)),
          ),
        ),
      ],
    );
  }
}

String? _status(dynamic value) => const {
  '1': 'Pendente',
  '2': 'Cancelada',
  '3': 'Aguardando recibo',
  '4': 'Rejeitada',
  '5': 'Autorizada',
  '6': 'Emitida DANFE',
  '7': 'Registrada',
  '8': 'Aguardando protocolo',
  '9': 'Denegada',
  '10': 'Consulta situação',
  '11': 'Bloqueada',
}[value?.toString()];

class _SummaryGrid extends StatelessWidget {
  final List<(String, String)> values;
  const _SummaryGrid({required this.values});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = math.max(
        1,
        math.min(values.length, (constraints.maxWidth / 145).floor()),
      );
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final value in values)
            SizedBox(width: width, child: _Field(value.$1, value.$2)),
        ],
      );
    },
  );
}

class _Field extends StatelessWidget {
  final String label, value;
  const _Field(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFFD9F2FF),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0x8A021123),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF39739C)),
          ),
          child: SelectableText(
            value,
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
  );
}

class _ItemsGrid extends StatelessWidget {
  final List<Map> items;
  const _ItemsGrid({required this.items});
  static const widths = [260.0, 115.0, 65.0, 80.0, 125.0, 135.0];
  Widget row(List<String> cells, {bool heading = false}) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cells.length; i++)
          Container(
            width: widths[i],
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: heading
                  ? const Color(0xFF123459)
                  : const Color(0xBB041A31),
              border: Border.all(color: const Color(0xFF397CA6), width: .5),
            ),
            child: Text(
              cells[i],
              style: TextStyle(
                fontSize: 14,
                height: 1.3,
                fontWeight: heading ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Deslize para os lados para ver todas as colunas; role a lista para ver mais itens.',
        style: TextStyle(fontSize: 12, color: Color(0xFFABD4ED)),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 780,
          child: Column(
            children: [
              row([
                'Descrição',
                'Código',
                'Un',
                'Qtd.',
                'Valor unit.',
                'Valor total',
              ], heading: true),
              SizedBox(
                height: 340,
                child: ListView.builder(
                  primary: false,
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final item = items[index];
                    return row([
                      nfeText(item['description']),
                      nfeText(item['code']),
                      nfeText(item['unit']),
                      nfeQuantity(item['quantity']),
                      nfeMoney(item['unitPrice']),
                      nfeMoney(item['total']),
                    ]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Beveled metal/glass panels drawn in Flutter; no baked-in labels or logo.
class NfePanelRoyalClean extends StatelessWidget {
  final Widget child;
  const NfePanelRoyalClean({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      boxShadow: [
        BoxShadow(color: Color(0x24008DFF), blurRadius: 12, spreadRadius: 1),
        BoxShadow(
          color: Color(0x99000000),
          blurRadius: 10,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: CustomPaint(
      foregroundPainter: _PanelEdge(),
      child: ClipPath(
        clipper: _PanelClip(),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF24486B),
                Color(0xFF071E38),
                Color(0xFF031326),
                Color(0xFF0B3153),
              ],
              stops: [0, .22, .7, 1],
            ),
          ),
          child: child,
        ),
      ),
    ),
  );
}

Path _panelPath(Size size, double inset) {
  final r = (Offset.zero & size).deflate(inset);
  const cut = 9.0;
  return Path()
    ..moveTo(r.left + cut, r.top)
    ..lineTo(r.right - cut, r.top)
    ..lineTo(r.right, r.top + cut)
    ..lineTo(r.right, r.bottom - cut)
    ..lineTo(r.right - cut, r.bottom)
    ..lineTo(r.left + cut, r.bottom)
    ..lineTo(r.left, r.bottom - cut)
    ..lineTo(r.left, r.top + cut)
    ..close();
}

class _PanelClip extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _panelPath(size, 0);
  @override
  bool shouldReclip(_PanelClip oldClipper) => false;
}

class _PanelEdge extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE6F8FF), Color(0xFF1688C6), Color(0xFF00CFFF)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(_panelPath(size, .6), paint);
    paint
      ..shader = null
      ..color = const Color(0x6646C9FF)
      ..strokeWidth = .6;
    canvas.drawPath(_panelPath(size, 4), paint);
  }

  @override
  bool shouldRepaint(_PanelEdge oldDelegate) => false;
}
