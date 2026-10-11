import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core_royal_clean/services/catalog_feed_royal_clean.dart';
import '../shared/layout_button_royal_clean.dart';

class RecentProductsHologramRoyalClean extends StatefulWidget {
  final VoidCallback onOpen;
  final Stream<List<Map<String, dynamic>>>? products;
  final Future<Uint8List?> Function()? capturePreview;
  const RecentProductsHologramRoyalClean({
    super.key,
    required this.onOpen,
    this.products,
    this.capturePreview,
  });
  @override
  State<RecentProductsHologramRoyalClean> createState() =>
      _RecentHologramState();
}

class _RecentHologramState extends State<RecentProductsHologramRoyalClean>
    with SingleTickerProviderStateMixin {
  static const _asset = 'assets/preview/royal-store/produtos-royal.webp';
  late final _feed = widget.products ?? CatalogFeedRoyalClean.recent();
  final _pages = PageController();
  late final _arrows = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  String _version = '';
  @override
  void dispose() {
    _pages.dispose();
    _arrows.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: _feed,
    builder: (context, snapshot) {
      final rows = CatalogFeedRoyalClean.latestTen(snapshot.data ?? []);
      final version = rows.map((r) => '${r['id']}:${r['updatedAt']}').join('|');
      if (version != _version) {
        _version = version;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pages.hasClients) _pages.jumpToPage(0);
        });
      }
      final motion =
          rows.length > 1 &&
          !MediaQuery.disableAnimationsOf(context) &&
          TickerMode.valuesOf(context).enabled;
      if (motion && !_arrows.isAnimating) _arrows.repeat(reverse: true);
      if (!motion && _arrows.isAnimating) _arrows.stop();
      return LayoutButtonRoyalClean(
        id: 'production.produtos-royal-gif',
        layoutScope: 'app',
        alwaysOverlay: true,
        hitTestAsset: rows.isEmpty ? _asset : null,
        circularHitTest: rows.isNotEmpty,
        capturePreview:
            widget.capturePreview ??
            () async {
              final data = await rootBundle.load(_asset);
              return data.buffer.asUint8List(
                data.offsetInBytes,
                data.lengthInBytes,
              );
            },
        child: Builder(
          builder: (layoutContext) => Semantics(
            button: true,
            label:
                'Produtos Vitrine. Deslize para ver os últimos produtos publicados.',
            child: GestureDetector(
              key: const ValueKey('produtos-royal-gif-shortcut'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.onOpen,
              onLongPress: LayoutButtonRoyalClean.adminLongPressOf(
                layoutContext,
              ),
              child: AspectRatio(
                aspectRatio: 470 / 304,
                child: rows.isEmpty
                    ? RepaintBoundary(
                        child: Image.asset(
                          _asset,
                          fit: BoxFit.contain,
                          cacheWidth: 470,
                          excludeFromSemantics: true,
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final diameter = constraints.biggest.shortestSide;
                          return Center(
                            child: SizedBox.square(
                              dimension: diameter,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFB875FF),
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x669955FF),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: ClipOval(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        PageView.builder(
                                          controller: _pages,
                                          physics: rows.length > 1
                                              ? const PageScrollPhysics()
                                              : const NeverScrollableScrollPhysics(),
                                          itemCount: rows.length,
                                          itemBuilder: (context, index) => AnimatedBuilder(
                                            animation: _pages,
                                            builder: (context, _) {
                                              final page =
                                                  _pages.hasClients &&
                                                      _pages
                                                          .position
                                                          .haveDimensions
                                                  ? _pages.page ?? 0
                                                  : 0.0;
                                              final distance = (index - page)
                                                  .clamp(-1.0, 1.0);
                                              final turn =
                                                  MediaQuery.disableAnimationsOf(
                                                    context,
                                                  )
                                                  ? 0.0
                                                  : distance * math.pi * .65;
                                              return Transform(
                                                alignment: Alignment.center,
                                                transform: Matrix4.identity()
                                                  ..setEntry(3, 2, .002)
                                                  ..rotateY(turn),
                                                child: ColoredBox(
                                                  color: const Color(
                                                    0xFFF5F8FA,
                                                  ),
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      Image.network(
                                                        '${rows[index]['imageUrl'] ?? ''}',
                                                        fit: BoxFit.contain,
                                                        cacheWidth: 420,
                                                        errorBuilder:
                                                            (_, _, _) =>
                                                                Image.asset(
                                                                  _asset,
                                                                  fit: BoxFit
                                                                      .contain,
                                                                  cacheWidth:
                                                                      300,
                                                                ),
                                                      ),
                                                      Align(
                                                        alignment: Alignment
                                                            .bottomCenter,
                                                        child: ColoredBox(
                                                          color: const Color(
                                                            0xCC092F43,
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.fromLTRB(
                                                                  22,
                                                                  4,
                                                                  22,
                                                                  12,
                                                                ),
                                                            child: Text(
                                                              '${rows[index]['title']} · ${index + 1}/${rows.length}',
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style:
                                                                  const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        11,
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
                                          ),
                                        ),
                                        if (rows.length > 1)
                                          IgnorePointer(
                                            child: AnimatedBuilder(
                                              animation: _arrows,
                                              builder: (context, _) => Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  _arrow(
                                                    Icons.chevron_left,
                                                    -1,
                                                    motion,
                                                  ),
                                                  _arrow(
                                                    Icons.chevron_right,
                                                    1,
                                                    motion,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
      );
    },
  );
  Widget _arrow(IconData icon, double direction, bool motion) =>
      Transform.translate(
        offset: Offset(direction * (motion ? _arrows.value * 3 : 0), 0),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xCC092F43),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFDFBEFF), size: 24),
        ),
      );
}
