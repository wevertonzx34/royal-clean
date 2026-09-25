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

class ProductCategoriesRoyalClean extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;
  const ProductCategoriesRoyalClean({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => ListView.separated(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    itemCount: productCategoriesRoyalClean.length,
    separatorBuilder: (_, _) => const SizedBox(width: 8),
    itemBuilder: (context, index) {
      final category = productCategoriesRoyalClean[index];
      final active = selected == category.id;
      return Center(
        child: ChoiceChip(
          label: Text(category.title),
          selected: active,
          tooltip: active ? 'Remover filtro ${category.title}' : category.title,
          showCheckmark: false,
          selectedColor: const Color(0xFF092F43),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: active ? const Color(0xFF092F43) : const Color(0xFFDCE5EA),
          ),
          labelStyle: TextStyle(
            color: active ? Colors.white : const Color(0xFF607783),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (_) => onSelected(active ? null : category.id),
        ),
      );
    },
  );
}
