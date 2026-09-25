import '../shared/header_actions_royal_clean.dart';
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

const _navy = Color(0xFF092F43);
const _teal = Color(0xFF007F9F);
const _muted = Color(0xFF607783);
const _paper = Color(0xFFF5F8FA);
const _accountColumnWidth = 104.0;

class PreviewPageRoyalClean extends StatefulWidget {
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
  late final _session = widget.authenticated ?? Stream<bool>.value(false);

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
          onPressed: () => _openAccount(_signedIn),
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
    _pageScroll.dispose();
    super.dispose();
  }

  Widget _menuButton(String title, VoidCallback? onPressed) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(title, maxLines: 1, softWrap: false),
    ),
  );

  void _openStory(
    BuildContext context, {
    required String title,
    required String label,
    required String image,
    required String body,
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
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: _navy),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
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
            const _DemoNote(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: _session,
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
              const NotificationButtonRoyalClean(color: _navy),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: _accountColumnWidth,
                  child: FilledButton.icon(
                    onPressed: _openingAccount
                        ? null
                        : () => _openAccount(signedIn),
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
                        Expanded(
                          child: _menuButton(
                            'Produtos',
                            () => _goTo(_productsKey),
                          ),
                        ),
                        Expanded(
                          child: _menuButton(
                            'Novidades',
                            () => _goTo(_partnersKey),
                          ),
                        ),
                        Expanded(
                          child: _menuButton(
                            'Desempenho',
                            () => _goTo(_partnersKey),
                          ),
                        ),
                        SizedBox(
                          width: _accountColumnWidth,
                          child: _menuButton(
                            'Sobre nós',
                            () => _goTo(_newsKey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: CustomScrollView(
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
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 4),
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
                          padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    onSelected: (value) {
                      setState(() => _generalCategory = value);
                      _goTo(_productsKey);
                    },
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
                                250 +
                                MediaQuery.textScalerOf(context).scale(110),
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
                                  onTap: () => _openStory(
                                    context,
                                    title: product.name,
                                    label: 'PRODUTO DEMONSTRATIVO',
                                    image: product.image,
                                    body:
                                        '${product.description}\n\nCódigo demonstrativo: ${product.code}\nTags: ${product.tags.join(', ')}',
                                  ),
                                );
                              },
                            ),
                          ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                          child: _DemoNote(),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 38, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _NewsCard(
                                    news: news,
                                    onTap: () => _openStory(
                                      context,
                                      title: news.title,
                                      label: '${news.category} · DEMONSTRAÇÃO',
                                      image: news.image,
                                      body: news.body,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    FilledButton.icon(
                                      onPressed: _openingAccount
                                          ? null
                                          : () => _openAccount(signedIn),
                                      icon: const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('Acessar minha conta'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: _navy,
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
                                style: TextStyle(color: _muted, fontSize: 12),
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

  List<PreviewProductRoyalClean> get _visibleProducts =>
      previewProductsRoyalClean.where((product) {
        final categoryMatches =
            _category == 'Todos' ||
            product.category == _category ||
            product.niches.contains(_category);
        final haystack = normalizeProductSearchRoyalClean(
          '${product.name} ${product.code} ${product.tags.join(' ')}',
        );
        final words = normalizeProductSearchRoyalClean(
          _searchQuery,
        ).split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
        return (_generalCategory == null ||
                product.generalCategory == _generalCategory) &&
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
                  FilledButton.icon(
                    onPressed: () => _goTo(_productsKey),
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
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Row(
                    children: [
                      Text(
                        'Conhecer',
                        style: TextStyle(fontSize: 12, color: _muted),
                      ),
                      Spacer(),
                      Icon(Icons.arrow_forward_rounded, size: 17, color: _teal),
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
    child: InkWell(
      onTap: onTap,
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
  );
}
