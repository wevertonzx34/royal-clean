import 'package:royal_clean/presentation_royal_clean/shared/layout_button_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/services/touch_feedback_royal_clean.dart';
import '../home/profile_images_royal_clean.dart';
import '../shared/header_actions_royal_clean.dart';
import '../shared/institutional_link_royal_clean.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

import '../../core_royal_clean/constants/app_routes_royal_clean.dart';
import '../../core_royal_clean/services/biometric_access_royal_clean.dart';
import 'preview_content_royal_clean.dart';
import 'partnership_content_royal_clean.dart';
import 'partnership_section_royal_clean.dart';
import 'product_filters_royal_clean.dart';
import 'product_categories_royal_clean.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import '../../core_royal_clean/services/royal_catalog_royal_clean.dart';
import '../../core_royal_clean/services/catalog_feed_royal_clean.dart';
import '../home/royal_price_benefit_page_royal_clean.dart';
import '../home/catalog_audit_card_royal_clean.dart';
import 'performance_overview_page_royal_clean.dart';

const _navy = Color(0xFF092F43);
const _teal = Color(0xFF007F9F);
const _muted = Color(0xFF607783);
const _paper = Color(0xFFF5F8FA);
const _accountColumnWidth = 104.0;

PreviewProductRoyalClean _previewProductFromRecord(Map<String, dynamic> p) {
  final niches = (p['niches'] as List? ?? []).cast<String>();
  return PreviewProductRoyalClean(
    '${p['title']} · ${p['presentation'] == 'box' ? 'Caixa / pacote' : 'Unidade'}',
    niches.firstOrNull ?? 'Dia a dia',
    '${p['imageUrl']}',
    '${p['description'] ?? ''}',
    code: '${p['code'] ?? p['id']}',
    catalogId: '${p['id']}',
    tags: ['${p['measure']}', '${p['unit']}'],
    niches: niches,
    generalCategory: '${p['category']}',
    generalCategories: (p['categories'] as List? ?? []).cast<String>(),
    pfCents: p['pfCents'] as int?,
    pjCents: p['pjCents'] as int?,
    official: true,
    quoteOnly: p['quoteOnly'] == true,
  );
}

Widget _catalogImage(
  String image, {
  double? height,
  double? width,
  int cacheWidth = 630,
  BoxFit fit = BoxFit.cover,
}) => image.startsWith('https://')
    ? Image.network(
        image,
        height: height,
        width: width,
        fit: fit,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => SizedBox(
          height: height,
          width: width,
          child: const Center(child: Icon(Icons.image_not_supported_outlined)),
        ),
      )
    : Image.asset(
        image,
        height: height,
        width: width,
        fit: fit,
        cacheWidth: cacheWidth,
      );

/// The admin preview reuses the public storefront's filters and product cards.
class PreviewStorefrontRoyalClean extends StatefulWidget {
  final Stream<List<Map<String, dynamic>>>? products;
  const PreviewStorefrontRoyalClean({super.key, this.products});
  @override
  State<PreviewStorefrontRoyalClean> createState() => _StorefrontPreviewState();
}

class _StorefrontPreviewState extends State<PreviewStorefrontRoyalClean> {
  late final _feed = widget.products ?? CatalogFeedRoyalClean.published();
  String _niche = 'Todos', _search = '';
  String? _category;
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: _feed,
    builder: (context, snapshot) {
      final products = (snapshot.data ?? [])
          .where((p) => p['published'] == true)
          .map(_previewProductFromRecord)
          .where(
            (p) =>
                (_niche == 'Todos' || p.niches.contains(_niche)) &&
                (_category == null ||
                    p.generalCategories.contains(_category)) &&
                normalizeProductSearchRoyalClean(
                  '${p.name} ${p.code} ${p.description}',
                ).contains(normalizeProductSearchRoyalClean(_search)),
          )
          .toList();
      return Material(
        color: _paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE3EBEF)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _SectionTitle(
                  eyebrow: 'NOSSA VITRINE',
                  title: 'Encontre seu essencial.',
                  subtitle: 'Prévia em tempo real dos produtos publicados.',
                ),
              ),
              const SizedBox(height: 14),
              ProductFiltersRoyalClean(
                onCategory: (value) => setState(() => _niche = value),
                onSearch: (value) => setState(() => _search = value),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 32 + MediaQuery.textScalerOf(context).scale(24),
                child: ProductCategoriesRoyalClean(
                  selected: _category,
                  onSelected: (value) => setState(() => _category = value),
                ),
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const LinearProgressIndicator(),
              if (products.isEmpty &&
                  snapshot.connectionState != ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Nenhum produto publicado para esta seleção.',
                    style: TextStyle(color: _muted),
                  ),
                ),
              if (products.isNotEmpty)
                SizedBox(
                  height: 320 + MediaQuery.textScalerOf(context).scale(110),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) => _ProductCard(
                      product: products[index],
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(products[index].name),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _catalogImage(
                                  products[index].image,
                                  height: 180,
                                  fit: BoxFit.contain,
                                ),
                                Text(products[index].description),
                                Text(
                                  products[index].quoteOnly
                                      ? 'Solicitar orçamento'
                                      : 'Preço para CNPJ: ${catalogMoneyRoyalClean(products[index].pjCents)}\nPessoa física: ${catalogMoneyRoyalClean(products[index].pfCents)}',
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            LayoutButtonRoyalClean(
                              id: 'catalog.preview.close',
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Fechar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class PreviewPageRoyalClean extends StatefulWidget {
  final bool productsOnly;
  final Stream<List<Map<String, dynamic>>>? products;
  final List<Map<String, dynamic>> initialProducts;
  final ValueChanged<String>? onPreviewSection;
  final bool initialAuthenticated;
  final Stream<bool>? authenticated;
  final Future<void> Function()? prepareAccount;
  final Stream<List<PublicPartnerRoyalClean>>? partners;
  final Stream<List<PublicPartnerRoyalClean>>? partnerAds;
  const PreviewPageRoyalClean({
    super.key,
    this.authenticated,
    this.prepareAccount,
    this.partners,
    this.partnerAds,
    this.productsOnly = false,
    this.products,
    this.initialProducts = const [],
    this.onPreviewSection,
    this.initialAuthenticated = false,
  });

  @override
  State<PreviewPageRoyalClean> createState() => _PreviewPageRoyalCleanState();
}

class _PreviewPageRoyalCleanState extends State<PreviewPageRoyalClean> {
  final _productsKey = GlobalKey();
  final _newsKey = GlobalKey();
  final _partnersKey = GlobalKey();
  final _pageScroll = ScrollController();
  String _category = 'Todos';
  String? _generalCategory;
  String _searchQuery = '';
  bool _openingAccount = false;
  bool _signedIn = false;
  late final _session = (widget.authenticated ?? Stream<bool>.value(false))
      .asBroadcastStream(onCancel: (subscription) => subscription.cancel());
  late final _catalogFeed =
      (widget.products ?? CatalogFeedRoyalClean.published()).asBroadcastStream(
        onCancel: (subscription) => subscription.cancel(),
      );
  StreamSubscription<List<Map<String, dynamic>>>? _catalogSubscription;
  List<Map<String, dynamic>> _catalogRecords = [];
  List<PreviewProductRoyalClean> _catalogProducts = [];
  bool _catalogLive = false;
  @override
  void initState() {
    super.initState();
    _signedIn = widget.initialAuthenticated;
    if (widget.productsOnly ||
        widget.products != null ||
        Firebase.apps.isNotEmpty) {
      _catalogLive = true;
      _catalogRecords = _publishedRecords(widget.initialProducts);
      _catalogProducts = _catalogRecords
          .map(_previewProductFromRecord)
          .toList();
      _catalogSubscription = _catalogFeed.listen(
        (records) {
          if (!mounted) return;
          setState(() {
            _catalogRecords = _publishedRecords(records);
            _catalogProducts = _catalogRecords
                .map(_previewProductFromRecord)
                .toList();
            _catalogLive = true;
          });
        },
        onError: (Object error) {
          /* Keep the last successfully loaded catalogue. */
        },
      );
    }
  }

  List<Map<String, dynamic>> _publishedRecords(
    List<Map<String, dynamic>> rows,
  ) =>
      rows
          .where(
            (p) =>
                p['published'] == true &&
                p['archived'] != true &&
                p['royalCatalog'] == true,
          )
          .toList()
        ..sort(
          (a, b) =>
              '${b['updatedAt'] ?? ''}'.compareTo('${a['updatedAt'] ?? ''}'),
        );

  void _openProducts() {
    if (widget.productsOnly) {
      _pageScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/preview/products'),
        builder: (_) => PreviewPageRoyalClean(
          productsOnly: true,
          authenticated: _session,
          initialAuthenticated: _signedIn,
          prepareAccount: widget.prepareAccount,
          products: _catalogFeed,
          initialProducts: _catalogRecords,
          onPreviewSection: (section) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _goTo(section == 'about' ? _newsKey : _partnersKey);
            });
          },
        ),
      ),
    );
  }

  void _openPreviewSection(String section) {
    if (section == 'performance') {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/preview/performance'),
          builder: (_) => const PerformanceOverviewPageRoyalClean(),
        ),
      );
      return;
    }
    if (!widget.productsOnly) {
      _goTo(section == 'about' ? _newsKey : _partnersKey);
      return;
    }
    Navigator.of(context).pop();
    widget.onPreviewSection?.call(section);
  }

  Future<void>? _imagesReady;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _imagesReady ??= precacheProfileImagesRoyalClean(context);
  }

  Future<void> _openAccount(bool signedIn) async {
    if (_openingAccount) return;
    if (!signedIn) {
      Navigator.pushNamed(context, AppRoutesRoyalClean.login);
      return;
    }
    setState(() => _openingAccount = true);
    try {
      await widget.prepareAccount?.call();
      if (mounted && _signedIn) Navigator.pushNamed(context, '/account');
    } on BiometricCancelledRoyalClean {
      if (mounted) {
        _profileMessage(
          'Perfil protegido. Na janela do aparelho, use a digital ou escolha PIN, padrão ou senha.',
          deviceUnlock: true,
        );
      }
    } catch (_) {
      if (mounted) {
        _profileMessage(
          'Não foi possível abrir seu perfil. Confira a conexão e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingAccount = false);
    }
  }

  void _profileMessage(String message, {bool deviceUnlock = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: deviceUnlock ? 'PIN do aparelho' : 'Tentar novamente',
          onPressed: tactileActionRoyalClean(() => _openAccount(_signedIn)),
        ),
      ),
    );
  }

  void _goTo(GlobalKey key) {
    final section = key.currentContext;
    final target = section?.findRenderObject();
    if (target != null && _pageScroll.hasClients) {
      final offset = RenderAbstractViewport.of(
        target,
      ).getOffsetToReveal(target, 0).offset;
      final header = key == _productsKey
          ? 0.0
          : 32 + MediaQuery.textScalerOf(context).scale(24);
      _pageScroll.animateTo(
        (offset - header).clamp(0.0, _pageScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _catalogSubscription?.cancel();
    _pageScroll.dispose();
    super.dispose();
  }

  Widget _menuButton(String title, VoidCallback? onPressed) =>
      LayoutButtonRoyalClean(
        id: 'preview_page_royal_clean.control_01',
        instanceKey: title,
        child: TextButton(
          onPressed: tactileTapRoyalClean(onPressed),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title, maxLines: 1, softWrap: false),
          ),
        ),
      );

  void _openStory(
    BuildContext context, {
    required String title,
    required String label,
    required String image,
    required String body,
    bool demonstration = true,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .84,
        minChildSize: .4,
        maxChildSize: .95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Row(
              children: [
                const HeaderActionsRoyalClean(color: _navy, showMyData: false),
                const Spacer(),
                LayoutButtonRoyalClean(
                  id: 'preview_page_royal_clean.control_02',
                  child: IconButton(
                    tooltip: 'Fechar',
                    onPressed: tactileTapRoyalClean(
                      () => Navigator.pop(context),
                    ),
                    icon: const Icon(Icons.close_rounded, color: _navy),
                  ),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _catalogImage(
                image,
                height: 230,
                fit: BoxFit.cover,
                cacheWidth: 1080,
              ),
            ),
            const SizedBox(height: 24),
            _Eyebrow(label),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _navy,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              body,
              style: const TextStyle(fontSize: 16, height: 1.65, color: _muted),
            ),
            const SizedBox(height: 24),
            if (demonstration) const _DemoNote(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: _session,
    initialData: widget.initialAuthenticated,
    builder: (context, snapshot) {
      _signedIn = snapshot.data == true;
      return _buildPage(context, _signedIn);
    },
  );

  Widget _buildPage(BuildContext context, bool signedIn) {
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _teal,
        primary: _teal,
        secondary: _navy,
        surface: Colors.white,
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: _navy,
        displayColor: _navy,
      ),
    );
    return Theme(
      data: lightTheme,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 76,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 1,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.white,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
              systemNavigationBarColor: _paper,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
            titleSpacing: 20,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/logo/logo-laucher.webp',
                    cacheWidth: 168,
                    width: 42,
                    height: 42,
                  ),
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ROYAL CLEAN',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .5,
                            color: _navy,
                          ),
                        ),
                        Text(
                          'D I S T R I B U I D O R A',
                          style: TextStyle(fontSize: 8, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (signedIn)
                LayoutButtonRoyalClean(
                  id: 'preview.price.benefit',
                  child: IconButton(
                    tooltip: 'Ativar convite de preço PJ',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RoyalPriceBenefitPageRoyalClean(),
                      ),
                    ),
                    icon: const Icon(Icons.card_giftcard_outlined),
                  ),
                ),
              const NotificationButtonRoyalClean(color: _navy),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: _accountColumnWidth,
                  child: LayoutButtonRoyalClean(
                    id: 'preview_page_royal_clean.control_03',
                    child: FilledButton.icon(
                      onPressed: tactileTapRoyalClean(
                        _openingAccount ? null : () => _openAccount(signedIn),
                      ),
                      icon: _openingAccount
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_outline_rounded, size: 18),
                      label: Text(signedIn ? 'Perfil' : 'Login'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Row(
                      children: [
                        Expanded(child: _menuButton('Produtos', _openProducts)),
                        Expanded(
                          child: _menuButton(
                            'Novidades',
                            () => _openPreviewSection('news'),
                          ),
                        ),
                        Expanded(
                          child: _menuButton(
                            'Desempenho',
                            () => _openPreviewSection('performance'),
                          ),
                        ),
                        SizedBox(
                          width: _accountColumnWidth,
                          child: _menuButton(
                            'Sobre nós',
                            () => _openPreviewSection('about'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: widget.productsOnly
              ? _productsPage(context)
              : CustomScrollView(
                  controller: _pageScroll,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _hero(),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  22,
                                  22,
                                  4,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome_outlined,
                                      size: 19,
                                      color: _teal,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Um cuidado especial para cada ambiente.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _navy.withValues(alpha: .8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  30,
                                  20,
                                  0,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _SectionTitle(
                                      key: _productsKey,
                                      eyebrow: 'NOSSA VITRINE',
                                      title: 'Encontre seu essencial.',
                                      subtitle:
                                          'Explore uma seleção feita para inspirar.',
                                    ),
                                    const SizedBox(height: 18),
                                    ProductFiltersRoyalClean(
                                      onCategory: (value) =>
                                          setState(() => _category = value),
                                      onSearch: (value) =>
                                          setState(() => _searchQuery = value),
                                    ),
                                    const SizedBox(height: 18),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _CategoryHeaderRoyalClean(
                        height: 32 + MediaQuery.textScalerOf(context).scale(24),
                        child: ProductCategoriesRoyalClean(
                          selected: _generalCategory,
                          onSelected: tactileSelectionRoyalClean((value) {
                            setState(() => _generalCategory = value);
                            _goTo(_productsKey);
                          }),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 18),
                              if (_visibleProducts.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'Nenhum produto encontrado. Tente outro termo ou nicho.',
                                    style: TextStyle(color: _muted),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              if (_visibleProducts.isNotEmpty)
                                SizedBox(
                                  height:
                                      (_catalogLive ? 320 : 250) +
                                      MediaQuery.textScalerOf(
                                        context,
                                      ).scale(110),
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    itemCount: _visibleProducts.length,
                                    separatorBuilder: (_, index) =>
                                        const SizedBox(width: 14),
                                    itemBuilder: (context, index) {
                                      final product = _visibleProducts[index];
                                      return _ProductCard(
                                        product: product,
                                        onTap: tactileActionRoyalClean(
                                          () => _openStory(
                                            context,
                                            title: product.name,
                                            label: product.official
                                                ? 'PRODUTO ROYAL CLEAN'
                                                : 'PRODUTO DEMONSTRATIVO',
                                            image: product.image,
                                            body:
                                                '${product.description}\n\nCódigo: ${product.code}\n${product.tags.join(' · ')}${product.official ? '\n\n${product.quoteOnly ? 'Solicite um orçamento para este produto.' : 'Preço para CNPJ: ${catalogMoneyRoyalClean(product.pjCents)}\nPessoa física: ${catalogMoneyRoyalClean(product.pfCents)}\nPreço PJ sujeito ao cadastro ou benefício válido.'}' : ''}',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              if (!_catalogLive)
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                                  child: _DemoNote(),
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  38,
                                  20,
                                  24,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _SectionTitle(
                                      key: _newsKey,
                                      eyebrow: 'FIQUE POR DENTRO',
                                      title: 'Acontece na Royal.',
                                      subtitle:
                                          'Histórias, ideias e novas possibilidades.',
                                    ),
                                    const SizedBox(height: 20),
                                    for (final news in previewNewsRoyalClean)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 14,
                                        ),
                                        child: _NewsCard(
                                          news: news,
                                          onTap: tactileActionRoyalClean(
                                            () => _openStory(
                                              context,
                                              title: news.title,
                                              label:
                                                  '${news.category} · DEMONSTRAÇÃO',
                                              image: news.image,
                                              body: news.body,
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 14),
                                    PartnershipSectionRoyalClean(
                                      key: _partnersKey,
                                      partners: widget.partners,
                                      ads: widget.partnerAds,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: _navy,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.waving_hand_outlined,
                                            color: Color(0xFF7CDDED),
                                            size: 27,
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Bom ter você por aqui.',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 23,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Já tem acesso? Entre na sua conta para continuar.',
                                            style: TextStyle(
                                              color: Color(0xFFB6CED9),
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          LayoutButtonRoyalClean(
                                            id: 'preview_page_royal_clean.control_04',
                                            child: FilledButton.icon(
                                              onPressed: tactileTapRoyalClean(
                                                _openingAccount
                                                    ? null
                                                    : () => _openAccount(
                                                        signedIn,
                                                      ),
                                              ),
                                              icon: const Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                'Acessar minha conta',
                                              ),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                foregroundColor: _navy,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                    const Text(
                                      'ROYAL CLEAN DISTRIBUIDORA LTDA',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _navy,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        height: 1.5,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Cuidado em cada detalhe.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'CNPJ 62.581.826/0001-49',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'R. Ouro Preto\nSetor Candida de Morais, Goiânia-GO',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Center(child: InstitutionalLinkRoyalClean()),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: MediaQuery.viewPaddingOf(context).bottom + 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _productsPage(BuildContext context) {
    final products = _visibleProducts;
    return CustomScrollView(
      key: const ValueKey('preview-products-page'),
      controller: _pageScroll,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    LayoutButtonRoyalClean(
                      id: 'preview.products.back',
                      child: IconButton(
                        tooltip: 'Voltar ao Preview',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Produtos',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${products.length} ${products.length == 1 ? 'produto' : 'produtos'}',
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ProductFiltersRoyalClean(
                  onCategory: (value) => setState(() => _category = value),
                  onSearch: (value) => setState(() => _searchQuery = value),
                ),
              ],
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _CategoryHeaderRoyalClean(
            height: 32 + MediaQuery.textScalerOf(context).scale(24),
            child: ProductCategoriesRoyalClean(
              selected: _generalCategory,
              onSelected: (value) => setState(() => _generalCategory = value),
            ),
          ),
        ),
        if (products.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                _catalogProducts.isEmpty
                    ? 'Nenhum produto publicado no momento.'
                    : 'Nenhum produto encontrado. Tente outro termo ou filtro.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.crossAxisExtent - 12) / 2;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent:
                      width + MediaQuery.textScalerOf(context).scale(270),
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = products[index];
                  return _PublicProductCard(
                    product: product,
                    onTap: () => _openStory(
                      context,
                      title: product.name,
                      label: 'PRODUTO ROYAL CLEAN',
                      demonstration: false,
                      image: product.image,
                      body:
                          '${product.description}\n\nCódigo: ${product.code}\n${product.tags.join(' · ')}\n\n${product.quoteOnly ? 'Solicite um orçamento para este produto.' : 'Preço para CNPJ: ${catalogMoneyRoyalClean(product.pjCents)}\nPessoa física: ${catalogMoneyRoyalClean(product.pfCents)}\nPreço PJ sujeito ao cadastro ou benefício válido.'}',
                    ),
                  );
                }, childCount: products.length),
              );
            },
          ),
        ),
      ],
    );
  }

  List<PreviewProductRoyalClean> get _visibleProducts =>
      (_catalogLive ? _catalogProducts : previewProductsRoyalClean).where((
        product,
      ) {
        final categoryMatches =
            _category == 'Todos' ||
            product.category == _category ||
            product.niches.contains(_category);
        final haystack = normalizeProductSearchRoyalClean(
          '${product.name} ${product.description} ${product.code} ${product.tags.join(' ')}',
        );
        final words = normalizeProductSearchRoyalClean(
          _searchQuery,
        ).split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
        return (_generalCategory == null ||
                product.generalCategory == _generalCategory ||
                product.generalCategories.contains(_generalCategory)) &&
            categoryMatches &&
            words.every(haystack.contains);
      }).toList();

  Widget _hero() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: ColoredBox(
        color: const Color(0xFFE7F3F8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final copy = Padding(
              padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Eyebrow('BEM-VINDO À ROYAL CLEAN'),
                  const SizedBox(height: 12),
                  const Text(
                    'Cuidado que faz\na diferença.',
                    style: TextStyle(
                      fontSize: 35,
                      height: 1.07,
                      letterSpacing: -1.2,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Descubra produtos e novidades\npara renovar sua rotina.',
                    style: TextStyle(fontSize: 14, color: _muted, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  LayoutButtonRoyalClean(
                    id: 'preview_page_royal_clean.control_05',
                    child: FilledButton.icon(
                      onPressed: tactileTapRoyalClean(
                        () => _goTo(_productsKey),
                      ),
                      label: const Text('Explorar produtos'),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                      style: FilledButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
            final photo = Image.asset(
              'assets/preview/collection.png',
              cacheWidth: 1080,
              width: double.infinity,
              height: constraints.maxWidth > 700 ? 360 : 205,
              fit: BoxFit.cover,
              alignment: const Alignment(0, .25),
            );
            if (constraints.maxWidth > 700) {
              return Row(
                children: [
                  Expanded(child: copy),
                  Expanded(child: photo),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, photo],
            );
          },
        ),
      ),
    ),
  );
}

class _Eyebrow extends StatelessWidget {
  final String text;
  const _Eyebrow(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      letterSpacing: 1.4,
      fontWeight: FontWeight.w800,
      color: _teal,
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String eyebrow, title, subtitle;
  const _SectionTitle({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _Eyebrow(eyebrow),
      const SizedBox(height: 9),
      Text(
        title,
        style: const TextStyle(
          fontSize: 26,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -.7,
          color: _navy,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: _muted, height: 1.5),
      ),
    ],
  );
}

class _DemoNote extends StatelessWidget {
  const _DemoNote();
  @override
  Widget build(BuildContext context) => const Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.info_outline_rounded, size: 14, color: _muted),
      SizedBox(width: 7),
      Expanded(
        child: Text(
          'Prévia demonstrativa · imagens e conteúdos ilustrativos.',
          style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
        ),
      ),
    ],
  );
}

class _ProductCard extends StatelessWidget {
  final PreviewProductRoyalClean product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE3EBEF)),
      ),
      child: LayoutButtonRoyalClean(
        id: 'preview_page_royal_clean.control_06',
        child: InkWell(
          onTap: tactileTapRoyalClean(onTap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _catalogImage(
                product.image,
                cacheWidth: 630,
                height: 194,
                width: 210,
                fit: BoxFit.cover,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.category.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        letterSpacing: 1,
                        color: _teal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      product.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    if (product.official) ...[
                      if (product.quoteOnly)
                        const Text(
                          'Solicitar orçamento',
                          style: TextStyle(
                            color: _teal,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else ...[
                        Text(
                          catalogMoneyRoyalClean(product.pjCents),
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Preço para CNPJ',
                          style: TextStyle(color: _muted, fontSize: 10),
                        ),
                        Text(
                          'Pessoa física: ${catalogMoneyRoyalClean(product.pfCents)}',
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                    const Row(
                      children: [
                        Text(
                          'Conhecer',
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                        Spacer(),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: _teal,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PublicProductCard extends StatelessWidget {
  final PreviewProductRoyalClean product;
  final VoidCallback onTap;
  const _PublicProductCard({required this.product, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey('public-product-${product.catalogId}'),
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE3EBEF)),
    ),
    child: LayoutButtonRoyalClean(
      id: 'preview.products.card.${product.catalogId}',
      child: InkWell(
        onTap: tactileTapRoyalClean(onTap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CatalogAuditImageRoyalClean(
              product: {
                'audited': true,
                'presentations': [
                  {'imageUrl': product.image},
                ],
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                    const Spacer(),
                    if (product.quoteOnly)
                      const Text(
                        'Solicitar orçamento',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _teal,
                        ),
                      )
                    else ...[
                      Text(
                        catalogMoneyRoyalClean(product.pjCents),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _navy,
                        ),
                      ),
                      const Text(
                        'Preço para CNPJ',
                        style: TextStyle(fontSize: 10, color: _teal),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'PF: ${catalogMoneyRoyalClean(product.pfCents)}',
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ver produto',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: _muted),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: _teal,
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

class _CategoryHeaderRoyalClean extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  const _CategoryHeaderRoyalClean({required this.height, required this.child});
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: _paper,
    elevation: overlapsContent ? 1 : 0,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: child,
      ),
    ),
  );
  @override
  bool shouldRebuild(_CategoryHeaderRoyalClean oldDelegate) =>
      height != oldDelegate.height || child != oldDelegate.child;
}

class _NewsCard extends StatelessWidget {
  final PreviewNewsRoyalClean news;
  final VoidCallback onTap;
  const _NewsCard({required this.news, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE3EBEF)),
    ),
    child: LayoutButtonRoyalClean(
      id: 'preview_page_royal_clean.control_07',
      child: InkWell(
        onTap: tactileTapRoyalClean(onTap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(
              news.image,
              cacheWidth: 1080,
              height: 164,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -.2),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Eyebrow(news.category),
                  const SizedBox(height: 10),
                  Text(
                    news.title,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    news.summary,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Editorial demonstrativo',
                          style: TextStyle(fontSize: 10, color: _muted),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Ler mais',
                        style: TextStyle(
                          fontSize: 12,
                          color: _teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: _teal, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
