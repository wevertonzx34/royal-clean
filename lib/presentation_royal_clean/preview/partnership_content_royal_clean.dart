import 'package:cloud_firestore/cloud_firestore.dart';

/// A public projection only: never load users/personal_data into the showcase.
class PublicPartnerRoyalClean {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final bool isDemo;
  final String? localImage;

  const PublicPartnerRoyalClean({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    this.isDemo = false,
    this.localImage,
  });

  static PublicPartnerRoyalClean? fromData(
    String id,
    Map<String, dynamic> data,
  ) {
    final title = data['title'];
    final description = data['description'];
    final image = data['imageUrl'];
    if (data['published'] != true ||
        title is! String ||
        description is! String ||
        image is! String ||
        title.trim().isEmpty ||
        title.length > 120 ||
        description.trim().isEmpty ||
        description.length > 2000 ||
        Uri.tryParse(image)?.scheme != 'https' ||
        Uri.tryParse(image)?.host.isNotEmpty != true) {
      return null;
    }
    return PublicPartnerRoyalClean(
      id: id,
      title: title,
      description: description,
      imageUrl: image,
    );
  }
}

final partnerDemoProfilesRoyalClean = List<PublicPartnerRoyalClean>.unmodifiable(
  List.generate(
    1,
    (index) => PublicPartnerRoyalClean(
      id: 'partner-demo-${index + 1}',
      title: 'Parceiro demo ${index + 1}',
      description:
          'Perfil demonstrativo da vitrine Royal Clean. Após o cadastro e a publicação, este espaço apresentará as informações públicas aprovadas pelo parceiro.',
      imageUrl: '',
      isDemo: true,
      localImage: 'assets/preview/logo-parceiro/coroa-royal.webp',
    ),
  ),
);

const partnerDemoAdsRoyalClean = [
  PublicPartnerRoyalClean(
    id: 'demo-1',
    title: 'Cuidado que aproxima.',
    description:
        'Royal Clean: um espaço para apresentar marcas, compartilhar novidades e criar boas conexões.',
    imageUrl: '',
    isDemo: true,
  ),
  PublicPartnerRoyalClean(
    id: 'demo-2',
    title: 'Sua marca em boa companhia.',
    description:
        'Uma prévia de como os parceiros poderão apresentar sua identidade e contar sua história na nossa vitrine.',
    imageUrl: '',
    isDemo: true,
  ),
  PublicPartnerRoyalClean(
    id: 'demo-3',
    title: 'Novas ideias para o dia a dia.',
    description:
        'Inspiração para ambientes bem cuidados. Conheça o formato das futuras publicações da nossa rede.',
    imageUrl: '',
    isDemo: true,
  ),
  PublicPartnerRoyalClean(
    id: 'demo-4',
    title: 'Juntos em cada detalhe.',
    description:
        'Conexões que valorizam o cuidado. Este anúncio é uma demonstração visual, sem oferta comercial.',
    imageUrl: '',
    isDemo: true,
  ),
];

class PartnershipContentRoyalClean {
  static Stream<List<PublicPartnerRoyalClean>> watch({required bool ads}) {
    return FirebaseFirestore.instance
        .collection(ads ? 'partner_ads' : 'public_partners')
        .where('published', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final records = snapshot.docs
              .where(
                (doc) => !ads || const ['1', '2', '3', '4'].contains(doc.id),
              )
              .map(
                (doc) => PublicPartnerRoyalClean.fromData(doc.id, doc.data()),
              )
              .whereType<PublicPartnerRoyalClean>()
              .toList();
          records.sort(
            (a, b) => ads
                ? a.id.compareTo(b.id)
                : a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
          return records;
        });
  }
}
