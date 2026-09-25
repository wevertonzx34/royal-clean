import 'dart:async';
import '../shared/header_actions_royal_clean.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'partnership_content_royal_clean.dart';
import 'partner_demo_art_royal_clean.dart';

const _navy = Color(0xFF092F43);
const _muted = Color(0xFF607783);

class PartnershipSectionRoyalClean extends StatelessWidget {
  final Stream<List<PublicPartnerRoyalClean>>? partners;
  final Stream<List<PublicPartnerRoyalClean>>? ads;
  const PartnershipSectionRoyalClean({super.key, this.partners, this.ads});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'NOSSA PARCERIA',
        style: TextStyle(
          color: Color(0xFF007F9F),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Boas conexões, novas descobertas.',
        style: TextStyle(
          color: _navy,
          fontSize: 27,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Conheça quem faz parte da nossa rede. Toque em uma logo para ver a apresentação pública.',
        style: TextStyle(color: _muted, height: 1.5),
      ),
      const SizedBox(height: 20),
      StreamBuilder<List<PublicPartnerRoyalClean>>(
        stream: partners,
        builder: (context, snapshot) {
          final published = snapshot.data ?? const <PublicPartnerRoyalClean>[];
          final items = snapshot.hasError || published.isEmpty
              ? partnerDemoProfilesRoyalClean
              : published;
          return LayoutBuilder(
            builder: (context, constraints) {
              // Four name columns, preserving the 64-pixel circular logos.
              final slots = math.min(
                4,
                math.max(1, (constraints.maxWidth / 64).floor()),
              );
              final width = constraints.maxWidth / slots;
              return SizedBox(
                height: 80 + MediaQuery.textScalerOf(context).scale(12) * 2.8,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  itemBuilder: (context, index) => SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        Tooltip(
                          message: items[index].title,
                          child: Semantics(
                            button: true,
                            label: 'Ver parceiro: ${items[index].title}',
                            child: SizedBox.square(
                              dimension: 64,
                              child: Material(
                                color: Colors.white,
                                shape: const CircleBorder(
                                  side: BorderSide(color: Color(0xFFD4E4EB)),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () =>
                                      _openPartner(context, items[index]),
                                  child: ClipOval(
                                    child: _Picture(
                                      item: items[index],
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            items[index].title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _navy,
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      const SizedBox(height: 24),
      const Text(
        'Vitrine parceira',
        style: TextStyle(
          color: _navy,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Conteúdo publicitário dos nossos parceiros.',
        style: TextStyle(color: _muted, height: 1.5),
      ),
      const SizedBox(height: 14),
      StreamBuilder<List<PublicPartnerRoyalClean>>(
        stream: ads,
        builder: (context, snapshot) {
          final published = (snapshot.data ?? const <PublicPartnerRoyalClean>[])
              .take(4)
              .toList();
          final items = snapshot.hasError || published.isEmpty
              ? partnerDemoAdsRoyalClean
              : published;
          return _AdCarousel(
            key: ValueKey(
              items
                  .map(
                    (e) => '${e.id}:${e.title}:${e.description}:${e.imageUrl}',
                  )
                  .join('|'),
            ),
            items: items,
          );
        },
      ),
      const SizedBox(height: 28),
    ],
  );
}

void _openPartner(BuildContext context, PublicPartnerRoyalClean item) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      minChildSize: .35,
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
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          SizedBox(
            height: 180,
            child: _Picture(item: item, fit: BoxFit.contain),
          ),
          const SizedBox(height: 24),
          Text(
            item.isDemo ? 'APRESENTAÇÃO DEMONSTRATIVA' : 'APRESENTAÇÃO PÚBLICA',
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(
              color: _navy,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            item.description,
            style: const TextStyle(color: _muted, fontSize: 16, height: 1.6),
          ),
        ],
      ),
    ),
  );
}

class _AdCarousel extends StatefulWidget {
  final List<PublicPartnerRoyalClean> items;
  const _AdCarousel({super.key, required this.items});
  @override
  State<_AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<_AdCarousel> with WidgetsBindingObserver {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;
  bool _paused = false;
  bool _active = true;
  bool _touching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!mounted ||
        !_active ||
        _paused ||
        _touching ||
        widget.items.length < 2 ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      return;
    }
    _timer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent == true &&
          _controller.hasClients &&
          !_controller.position.isScrollingNotifier.value) {
        _controller.animateToPage(
          (_index + 1) % widget.items.length,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic,
        );
      }
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Listener(
        onPointerDown: (_) {
          _touching = true;
          _timer?.cancel();
        },
        onPointerUp: (_) {
          _touching = false;
          _schedule();
        },
        onPointerCancel: (_) {
          _touching = false;
          _schedule();
        },
        child: SizedBox(
          height:
              244 +
              MediaQuery.textScalerOf(context).scale(11) * 2 +
              MediaQuery.textScalerOf(context).scale(23) * 2.6 +
              MediaQuery.textScalerOf(context).scale(13) * 4.8 +
              MediaQuery.textScalerOf(context).scale(12) * 2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              onPageChanged: (index) {
                setState(() => _index = index);
                _schedule();
              },
              itemBuilder: (context, index) =>
                  _AdCard(item: widget.items[index]),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'PUBLICIDADE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            Text(
              '${_index + 1} / ${widget.items.length}',
              style: const TextStyle(color: _muted),
            ),
            if (widget.items.length > 1)
              IconButton(
                tooltip: _paused
                    ? 'Retomar rolagem automática'
                    : 'Pausar rolagem automática',
                onPressed: () {
                  setState(() => _paused = !_paused);
                  _schedule();
                },
                icon: Icon(
                  _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: _navy,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _AdCard extends StatelessWidget {
  final PublicPartnerRoyalClean item;
  const _AdCard({required this.item});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE3EBEF)),
      ),
      child: InkWell(
        onTap: () => _openPartner(context, item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 164,
              child: _Picture(item: item, fit: BoxFit.cover),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.isDemo
                          ? 'VITRINE DEMONSTRATIVA'
                          : 'VITRINE PARCEIRA',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF007F9F),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.isDemo
                                ? 'Anúncio demonstrativo'
                                : 'Publicidade',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Ler mais',
                          style: TextStyle(
                            color: Color(0xFF007F9F),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF007F9F),
                          size: 16,
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

class _Picture extends StatelessWidget {
  final PublicPartnerRoyalClean item;
  final BoxFit fit;
  const _Picture({required this.item, required this.fit});
  @override
  Widget build(BuildContext context) => item.localImage != null
      ? Image.asset(
          item.localImage!,
          width: double.infinity,
          height: double.infinity,
          fit: fit,
          cacheWidth: 360,
          semanticLabel: item.title,
        )
      : item.isDemo
      ? PartnerDemoArtRoyalClean(id: item.id)
      : Image.network(
          item.imageUrl,
          width: double.infinity,
          height: double.infinity,
          fit: fit,
          cacheWidth: fit == BoxFit.contain ? 360 : 1080,
          semanticLabel: item.title,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: Color(0xFFE7F0F4),
            child: Center(
              child: Icon(Icons.storefront_outlined, color: _muted, size: 32),
            ),
          ),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const ColoredBox(
                  color: Color(0xFFE7F0F4),
                  child: Center(
                    child: Icon(Icons.image_outlined, color: _muted),
                  ),
                ),
        );
}
