import 'dart:math' as math;
import 'package:flutter/material.dart';

class ProductCategoryRoyalClean {
  final String id;
  final String title;
  final List<String> tags;
  const ProductCategoryRoyalClean(this.id, this.title, this.tags);
}

const productCategoriesRoyalClean = [
  ProductCategoryRoyalClean('papeis-higiene', 'Papéis e higiene', [
    'papel toalha',
    'papel higiênico',
    'guardanapos',
    'lençol hospitalar',
  ]),
  ProductCategoryRoyalClean('limpeza-profissional', 'Limpeza profissional', [
    'limpadores',
    'detergentes',
    'desinfecção',
    'álcool',
    'esponjas',
    'fibras',
    'panos',
    'flanelas',
    'sacos de lixo',
    'preto',
    'transparente',
    'infectante',
    'lonado',
    'leitoso',
  ]),
  ProductCategoryRoyalClean('cuidados-pessoais', 'Cuidados pessoais', [
    'sabonetes',
    'antissépticos',
    'aromatizadores',
    'odorizadores',
    'refis',
  ]),
  ProductCategoryRoyalClean(
    'descartaveis-alimentacao',
    'Descartáveis para alimentação',
    ['copos', 'canudos', 'pratos', 'palitos', 'marmitas', 'bandejas'],
  ),
  ProductCategoryRoyalClean(
    'embalagens-conservacao',
    'Embalagens e conservação',
    ['bobinas picotadas', 'filme', 'papel manteiga', 'alumínio', 'confeitaria'],
  ),
  ProductCategoryRoyalClean(
    'dispensers-acessorios',
    'Dispensers e acessórios',
    ['toalheiros', 'porta papel higiênico', 'saboneteiras', 'pulverizadores'],
  ),
  ProductCategoryRoyalClean(
    'protecao-profissional',
    'Proteção e uso profissional',
    [
      'luvas',
      'toucas',
      'aventais',
      'respiradores',
      'nitrílicas',
      'vinil',
      'látex',
    ],
  ),
];

class ProductCategoriesRoyalClean extends StatefulWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;
  const ProductCategoriesRoyalClean({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<ProductCategoriesRoyalClean> createState() =>
      _ProductCategoriesRoyalCleanState();
}

class _ProductCategoriesRoyalCleanState
    extends State<ProductCategoriesRoyalClean> {
  final _scroll = ScrollController();
  bool _canLeft = false;
  bool _canRight = false;
  bool _updateScheduled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateDirections);
    _scheduleUpdate();
  }

  void _scheduleUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      if (mounted) _updateDirections();
    });
  }

  void _updateDirections() {
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) return;
    final left = _scroll.position.extentBefore > 1;
    final right = _scroll.position.extentAfter > 1;
    if (left != _canLeft || right != _canRight) {
      setState(() {
        _canLeft = left;
        _canRight = right;
      });
    }
  }

  void _move(int direction) {
    if (!_scroll.hasClients) return;
    final target =
        (_scroll.offset + direction * _scroll.position.viewportDimension * .8)
            .clamp(0.0, _scroll.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _arrow({required bool left}) {
    final enabled = left ? _canLeft : _canRight;
    return IconButton(
      tooltip: left ? 'Categorias à esquerda' : 'Categorias à direita',
      onPressed: enabled ? () => _move(left ? -1 : 1) : null,
      color: const Color(0xFF007F9F),
      disabledColor: const Color(0xFFCBD6DC),
      icon: TweenAnimationBuilder<double>(
        key: ValueKey('${left}_$enabled'),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(
          milliseconds: !enabled || MediaQuery.disableAnimationsOf(context)
              ? 0
              : 1600,
        ),
        builder: (context, value, child) => Transform.translate(
          offset: Offset(
            math.sin(value * math.pi * 4) * 3 * (left ? -1 : 1),
            0,
          ),
          child: child,
        ),
        child: Icon(
          left
              ? Icons.keyboard_double_arrow_left_rounded
              : Icons.keyboard_double_arrow_right_rounded,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _arrow(left: true),
      Expanded(
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (_) {
            _scheduleUpdate();
            return false;
          },
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: productCategoriesRoyalClean.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = productCategoriesRoyalClean[index];
              final active = widget.selected == category.id;
              return Center(
                child: ChoiceChip(
                  label: Text(category.title),
                  selected: active,
                  tooltip: active
                      ? 'Remover filtro ${category.title}'
                      : category.title,
                  showCheckmark: false,
                  selectedColor: const Color(0xFF092F43),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: active
                        ? const Color(0xFF092F43)
                        : const Color(0xFFDCE5EA),
                  ),
                  labelStyle: TextStyle(
                    color: active ? Colors.white : const Color(0xFF607783),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) =>
                      widget.onSelected(active ? null : category.id),
                ),
              );
            },
          ),
        ),
      ),
      _arrow(left: false),
    ],
  );
}
