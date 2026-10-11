import 'package:flutter/material.dart';
import '../shared/layout_button_royal_clean.dart';
import '../../core_royal_clean/services/royal_catalog_royal_clean.dart';

class CatalogAuditCardRoyalClean extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onOpen;
  final bool production;
  const CatalogAuditCardRoyalClean({
    super.key,
    required this.product,
    required this.onOpen,
    this.production = true,
  });

  @override
  Widget build(BuildContext context) {
    final source = product['source'] as Map?;
    final description =
        '${product['description'] ?? source?['description'] ?? ''}'.trim();
    final audited = product['audited'] == true;
    final stock = product['stock'] as Map?;
    final presentations = product['presentations'] as List? ?? [];
    final price = presentations.whereType<Map>().firstOrNull;
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE3EBEF)),
      ),
      child: LayoutButtonRoyalClean(
        id: 'catalog.product.${product['id']}',
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CatalogAuditImageRoyalClean(product: product),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${product['title'] ?? 'Novo produto'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF092F43),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description.isEmpty
                            ? 'Confira os dados e complete a descrição.'
                            : description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF607783),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Código: ${product['code'] ?? 'Não informado'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF607783),
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      if (!production && price != null) ...[
                        Text(
                          catalogMoneyRoyalClean(price['pjCents']),
                          style: const TextStyle(
                            color: Color(0xFF092F43),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Preço para CNPJ',
                          style: TextStyle(
                            color: Color(0xFF007F9F),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'Pessoa física: ${catalogMoneyRoyalClean(price['pfCents'])}',
                          style: const TextStyle(
                            color: Color(0xFF607783),
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (!production && stock != null)
                        Text(
                          '${stock['boxes']} caixas · ${stock['loose']} avulsas',
                          style: const TextStyle(
                            color: Color(0xFF607783),
                            fontSize: 11,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        product['archived'] == true
                            ? 'Arquivado'
                            : !production
                            ? switch (product['status']) {
                                'published' => 'Publicado',
                                'suspended' => 'Suspenso',
                                _ => 'Receita',
                              }
                            : audited
                            ? 'Auditoria concluída'
                            : 'Aguardando auditoria',
                        style: const TextStyle(
                          color: Color(0xFF007F9F),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              !production
                                  ? 'Editar produto'
                                  : audited
                                  ? 'Revisar cadastro'
                                  : 'Auditar produto',
                              style: const TextStyle(
                                color: Color(0xFF092F43),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF007F9F),
                            size: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CatalogAuditImageRoyalClean extends StatelessWidget {
  final Map<String, dynamic> product;
  const CatalogAuditImageRoyalClean({super.key, required this.product});
  @override
  Widget build(BuildContext context) {
    final presentations = product['presentations'] as List? ?? [];
    final photo = presentations
        .whereType<Map>()
        .map((p) => '${p['imageUrl'] ?? ''}')
        .firstWhere((url) => url.startsWith('https://'), orElse: () => '');
    final usePhoto = product['audited'] == true && photo.isNotEmpty;
    return AspectRatio(
      aspectRatio: 1,
      child: ColoredBox(
        color: const Color(0xFFE7F3F8),
        child: usePhoto
            ? Image.network(
                photo,
                fit: BoxFit.contain,
                cacheWidth: 420,
                frameBuilder: (_, child, frame, synchronous) =>
                    synchronous || frame != null
                    ? child
                    : const CatalogAuditPlaceholderRoyalClean(),
                errorBuilder: (_, _, _) =>
                    const CatalogAuditPlaceholderRoyalClean(),
              )
            : const CatalogAuditPlaceholderRoyalClean(),
      ),
    );
  }
}

/// A single cached, static composition avoids a live animation per grid card.
class CatalogAuditPlaceholderRoyalClean extends StatelessWidget {
  const CatalogAuditPlaceholderRoyalClean({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: TickerMode(
      enabled: false,
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/preview/royal-store/royal-gaveta.webp',
              fit: BoxFit.contain,
              cacheWidth: 300,
            ),
            Align(
              alignment: const Alignment(0, -.4),
              child: FractionallySizedBox(
                widthFactor: .65,
                heightFactor: .55,
                child: Image.asset(
                  'assets/preview/royal-store/produtos-royal.webp',
                  fit: BoxFit.contain,
                  cacheWidth: 220,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
