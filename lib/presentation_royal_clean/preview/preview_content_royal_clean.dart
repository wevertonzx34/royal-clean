// Local editorial samples. Replace with approved admin publications when the
// publishing backend is implemented; no prices or availability are implied.
class PreviewProductRoyalClean {
  final String name;
  final String category;
  final String image;
  final String description;

  const PreviewProductRoyalClean(
    this.name,
    this.category,
    this.image,
    this.description,
  );
}

const previewProductsRoyalClean = [
  PreviewProductRoyalClean(
    'Multiuso essencial',
    'Dia a dia',
    'assets/preview/multiuso.png',
    'Uma proposta de apresentação para a linha de cuidados do dia a dia. Aqui você poderá conhecer cada produto, sua embalagem e as informações publicadas pela Royal Clean.\n\nEste item e sua embalagem são ilustrativos. Composição, indicação de uso, volume e disponibilidade serão informados no catálogo oficial.',
  ),
  PreviewProductRoyalClean(
    'Detergente fresh',
    'Dia a dia',
    'assets/preview/detergente.png',
    'Uma proposta de vitrine para os essenciais da cozinha, com uma apresentação simples e fácil de consultar.\n\nEste item e sua embalagem são ilustrativos. As características e instruções do produto real serão publicadas pela administração.',
  ),
  PreviewProductRoyalClean(
    'Seleção Royal Clean',
    'Kits',
    'assets/preview/collection.png',
    'Um conceito de seleção que reúne diferentes cuidados em um só lugar. Um espaço pensado para apresentar combinações e novidades da Royal Clean.\n\nKit demonstrativo, sem oferta comercial, preço ou disponibilidade confirmada.',
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
