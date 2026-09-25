// Local editorial samples. Replace with approved admin publications when the
// publishing backend is implemented; no prices or availability are implied.
class PreviewProductRoyalClean {
  final String name;
  final String category;
  final String image;
  final String description;
  final String code;
  final List<String> tags;
  final List<String> niches;
  final String generalCategory;

  const PreviewProductRoyalClean(
    this.name,
    this.category,
    this.image,
    this.description, {
    this.code = '',
    this.tags = const [],
    this.niches = const [],
    this.generalCategory = 'limpeza-profissional',
  });
}

const previewProductsRoyalClean = [
  PreviewProductRoyalClean(
    'Multiuso essencial',
    'Dia a dia',
    'assets/preview/multiuso.png',
    'Uma proposta de apresentação para a linha de cuidados do dia a dia. Aqui você poderá conhecer cada produto, sua embalagem e as informações publicadas pela Royal Clean.\n\nEste item e sua embalagem são ilustrativos. Composição, indicação de uso, volume e disponibilidade serão informados no catálogo oficial.',
    code: 'DEMO-001',
    tags: ['limpeza', 'multiuso', 'casa'],
    niches: ['Básicos'],
  ),
  PreviewProductRoyalClean(
    'Detergente fresh',
    'Dia a dia',
    'assets/preview/detergente.png',
    'Uma proposta de vitrine para os essenciais da cozinha, com uma apresentação simples e fácil de consultar.\n\nEste item e sua embalagem são ilustrativos. As características e instruções do produto real serão publicadas pela administração.',
    code: 'DEMO-002',
    tags: ['cozinha', 'louças', 'detergente'],
    niches: ['Básicos'],
  ),
  PreviewProductRoyalClean(
    'Seleção Royal Clean',
    'Kits',
    'assets/preview/collection.png',
    'Um conceito de seleção que reúne diferentes cuidados em um só lugar. Um espaço pensado para apresentar combinações e novidades da Royal Clean.\n\nKit demonstrativo, sem oferta comercial, preço ou disponibilidade confirmada.',
    code: 'DEMO-003',
    tags: ['seleção', 'kit', 'cuidados'],
    niches: ['Lançamentos'],
  ),
  PreviewProductRoyalClean(
    'Papel toalha interfolhado',
    'Dia a dia',
    'assets/preview/logo-parceiro/coroa-royal.webp',
    'Produto simulado de Papéis e higiene. Imagem institucional ilustrativa; especificações, preço e estoque serão definidos no catálogo real.',
    code: 'DEMO-PAP-001',
    generalCategory: 'papeis-higiene',
    tags: ['papel toalha', 'interfolhado', 'higiene'],
    niches: ['Básicos'],
  ),
  PreviewProductRoyalClean(
    'Saco de lixo preto 100 L',
    'Dia a dia',
    'assets/preview/logo-parceiro/coroa-royal.webp',
    'Produto simulado de Limpeza profissional, grupo Sacos de lixo. Imagem institucional ilustrativa, sem estoque ou oferta comercial confirmados.',
    code: 'DEMO-SAC-100',
    generalCategory: 'limpeza-profissional',
    tags: ['sacos de lixo', 'saco preto', '100 litros', 'resíduos'],
    niches: ['Básicos'],
  ),
  PreviewProductRoyalClean(
    'Sabonete líquido algodão',
    'Dia a dia',
    'assets/preview/logo-parceiro/coroa-royal.webp',
    'Produto simulado de Cuidados pessoais. Imagem institucional ilustrativa; composição e disponibilidade serão informadas no catálogo real.',
    code: 'DEMO-CUI-001',
    generalCategory: 'cuidados-pessoais',
    tags: ['sabonete', 'algodão', 'refil', 'cuidados pessoais'],
    niches: ['Básicos'],
  ),
  PreviewProductRoyalClean(
    'Copo descartável 200 ml',
    'Dia a dia',
    'assets/preview/logo-parceiro/coroa-royal.webp',
    'Produto simulado de Descartáveis para alimentação. Imagem institucional ilustrativa; material e quantidade por embalagem serão definidos depois.',
    code: 'DEMO-DES-001',
    generalCategory: 'descartaveis-alimentacao',
    tags: ['copos', 'descartáveis', 'alimentação', '200 ml'],
  ),
  PreviewProductRoyalClean(
    'Bobina picotada',
    'Dia a dia',
    'assets/preview/logo-parceiro/coroa-royal.webp',
    'Produto simulado de Embalagens e conservação. Imagem institucional ilustrativa; dimensões e especificações serão atualizadas com os dados reais.',
    code: 'DEMO-EMB-001',
    generalCategory: 'embalagens-conservacao',
    tags: ['bobinas', 'embalagens', 'conservação', 'picotada'],
  ),
  PreviewProductRoyalClean(
    'Dispenser de sabonete',
    'Dia a dia',
    'assets/preview/logo-parceiro/coroa-royal.webp',
    'Produto simulado de Dispensers e acessórios. Imagem institucional ilustrativa; capacidade e compatibilidade serão informadas no catálogo real.',
    code: 'DEMO-DIS-001',
    generalCategory: 'dispensers-acessorios',
    tags: ['dispenser', 'saboneteira', 'acessórios'],
  ),
  PreviewProductRoyalClean(
    'Luva nitrílica',
    'Dia a dia',
    'assets/preview/logo-parceiro/coroa-royal.webp',
    'Produto simulado de Proteção e uso profissional. Imagem institucional ilustrativa; tamanhos, finalidade e certificações serão informados antes da comercialização.',
    code: 'DEMO-PRO-001',
    generalCategory: 'protecao-profissional',
    tags: ['luvas', 'nitrílicas', 'proteção', 'uso profissional'],
  ),
];

class PreviewNewsRoyalClean {
  final String category;
  final String title;
  final String summary;
  final String body;
  final String image;

  const PreviewNewsRoyalClean(
    this.category,
    this.title,
    this.summary,
    this.body,
    this.image,
  );
}

const previewNewsRoyalClean = [
  PreviewNewsRoyalClean(
    'UNIVERSO ROYAL CLEAN',
    'Um novo jeito de estar perto de você.',
    'Conheça o conceito do nosso novo espaço de produtos e novidades.',
    'A Royal Clean está ganhando um espaço de descoberta no aplicativo. A proposta é reunir uma vitrine de produtos e conteúdos da marca em uma experiência acessível, antes mesmo do login.\n\nNesta apresentação, você pode explorar imagens conceituais, navegar pelas categorias e conhecer o formato das publicações.\n\nOs conteúdos desta prévia são demonstrativos. O catálogo e as notícias oficiais serão definidos pela administração.',
    'assets/preview/collection.png',
  ),
  PreviewNewsRoyalClean(
    'POR DENTRO DA VITRINE',
    'Cada detalhe tem seu lugar.',
    'Uma seleção organizada para facilitar suas próximas descobertas.',
    'Encontrar o que você procura começa com uma boa apresentação. Nossa proposta de vitrine separa os essenciais do dia a dia das seleções em kits, com imagens e detalhes em um único lugar.\n\nOs filtros ajudam a explorar as categorias. Ao tocar em um produto, você abre sua apresentação; ao tocar em Login, acessa a área já existente do aplicativo.\n\nEste é um conteúdo editorial de demonstração, criado para apresentar a experiência Royal Clean.',
    'assets/preview/multiuso.png',
  ),
];
