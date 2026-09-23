import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core_royal_clean/constants/app_routes_royal_clean.dart';
import 'preview_content_royal_clean.dart';

const _navy = Color(0xFF092F43);
const _teal = Color(0xFF007F9F);
const _muted = Color(0xFF607783);
const _paper = Color(0xFFF5F8FA);

class PreviewPageRoyalClean extends StatefulWidget {
  final Stream<bool>? authenticated;
  const PreviewPageRoyalClean({super.key, this.authenticated});

  @override
  State<PreviewPageRoyalClean> createState() => _PreviewPageRoyalCleanState();
}

class _PreviewPageRoyalCleanState extends State<PreviewPageRoyalClean> {
  final _productsKey = GlobalKey();
  final _newsKey = GlobalKey();
  String _category = 'Todos';
  late final _session = widget.authenticated ?? Stream<bool>.value(false);

  void _goTo(GlobalKey key) {
    final section = key.currentContext;
    if (section != null) {
      Scrollable.ensureVisible(
        section,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

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
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Fechar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: _navy),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(image, height: 230, fit: BoxFit.cover),
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
    builder: (context, snapshot) => _buildPage(context, snapshot.data == true),
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
                    width: 42,
                    height: 42,
                  ),
                ),
                const SizedBox(width: 10),
                const Flexible(
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
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    signedIn ? '/account' : AppRoutesRoyalClean.login,
                  ),
                  icon: const Icon(Icons.person_outline_rounded, size: 18),
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
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewPaddingOf(context).bottom + 16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'EXPLORE A ROYAL CLEAN',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _muted,
                              letterSpacing: .8,
                            ),
                          ),
                          Wrap(
                            children: [
                              TextButton(
                                onPressed: () => _goTo(_productsKey),
                                child: const Text('Produtos'),
                              ),
                              TextButton(
                                onPressed: () => _goTo(_newsKey),
                                child: const Text('Novidades'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final category in [
                                'Todos',
                                'Dia a dia',
                                'Kits',
                              ])
                                ChoiceChip(
                                  label: Text(category),
                                  selected: category == _category,
                                  showCheckmark: false,
                                  selectedColor: _navy,
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: category == _category
                                        ? _navy
                                        : const Color(0xFFDCE5EA),
                                  ),
                                  labelStyle: TextStyle(
                                    color: category == _category
                                        ? Colors.white
                                        : _muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _category = category),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 250 + MediaQuery.textScalerOf(context).scale(110),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                              body: product.description,
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
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    signedIn
                                        ? '/account'
                                        : AppRoutesRoyalClean.login,
                                  ),
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
                            'ROYAL CLEAN',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _navy,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Cuidado em cada detalhe.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted, fontSize: 12),
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
        ),
      ),
    );
  }

  List<PreviewProductRoyalClean> get _visibleProducts =>
      previewProductsRoyalClean
          .where(
            (product) => _category == 'Todos' || product.category == _category,
          )
          .toList();

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
