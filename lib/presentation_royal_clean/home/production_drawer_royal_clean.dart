import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth/admin_route_guard_royal_clean.dart';
import '../shared/layout_button_royal_clean.dart';
import 'avatar_aura_royal_clean.dart';
import 'bling_data_page_royal_clean.dart';
import 'image_action_royal_clean.dart';
import 'neon_image_royal_clean.dart';
import 'order_care_page_royal_clean.dart';

Future<void> openProductionDrawerRoyalClean(BuildContext context) async {
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    enableDrag: false,
    builder: (_) => const ProductionDrawerRoyalClean(),
  );
}

class ProductionDrawerRoyalClean extends StatelessWidget {
  final Future<void> Function()? onOpenOrders;
  final Future<void> Function()? onOpenProducts;
  final Future<void> Function()? onOpenRevenue;
  final Future<Uint8List?> Function()? captureLayoutPreview;
  const ProductionDrawerRoyalClean({
    super.key,
    this.onOpenOrders,
    this.onOpenProducts,
    this.onOpenRevenue,
    this.captureLayoutPreview,
  });
  static const _orders = 'assets/preview/royal-store/royal-pedidos.webp';
  static const _products = 'assets/preview/royal-store/royal-produtos.webp';
  static const _revenue = 'assets/preview/royal-store/royal-receita.webp';

  Future<void> _openData(BuildContext context, String kind) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AdminRouteGuardRoyalClean(
            firebaseInitialization: Future<void>.value(),
            builder: (_) => BlingDataPageRoyalClean(initialKind: kind),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AspectRatio(
                  aspectRatio: 859 / 807,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: LayoutButtonRoyalClean(
                          id: 'production.royal-gaveta',
                          freeMovement: true,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: RepaintBoundary(
                                    child: Image.asset(
                                      'assets/preview/royal-store/royal-gaveta.webp',
                                      fit: BoxFit.contain,
                                      cacheWidth: 1000,
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                ),
                              ),
                              const Positioned.fill(
                                child: _DrawerAshRoyalClean(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: .78,
                        child: _ProductionImageButton(
                          id: 'production.royal-pedidos',
                          shortcutKey: const ValueKey('royal-pedidos-shortcut'),
                          asset: _orders,
                          title: 'Pedidos',
                          // Match the title/image proportion of the .62 buttons.
                          titleFontSize: 22 * .78 / .62,
                          semanticsLabel: 'Abrir atendimento do pedido',
                          aura: true,
                          captureLayoutPreview: captureLayoutPreview,
                          onActivate:
                              onOpenOrders ??
                              () => openOrderCareRoyalClean(context),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, -.67),
                        child: FractionallySizedBox(
                          widthFactor: .62,
                          child: _ProductionImageButton(
                            id: 'production.royal-produtos',
                            shortcutKey: const ValueKey(
                              'royal-produtos-shortcut',
                            ),
                            asset: _products,
                            title: 'Produtos',
                            titleVerticalOffset: .11,
                            semanticsLabel: 'Abrir consulta de produtos',
                            aura: true,
                            auraParticles: false,
                            captureLayoutPreview: captureLayoutPreview,
                            onActivate:
                                onOpenProducts ??
                                () => _openData(context, 'products'),
                          ),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, .67),
                        child: FractionallySizedBox(
                          widthFactor: .62,
                          child: _ProductionImageButton(
                            id: 'production.royal-receita',
                            shortcutKey: const ValueKey(
                              'royal-receita-shortcut',
                            ),
                            asset: _revenue,
                            title: 'Produção',
                            semanticsLabel:
                                'Produção: abrir consulta de receita',
                            aura: true,
                            auraParticles: false,
                            captureLayoutPreview: captureLayoutPreview,
                            onActivate:
                                onOpenRevenue ??
                                () => _openData(context, 'invoices'),
                          ),
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
}

class _ProductionImageButton extends StatelessWidget {
  final String id, asset, title, semanticsLabel;
  final double titleVerticalOffset;
  final double titleFontSize;
  final Key shortcutKey;
  final Future<void> Function() onActivate;
  final bool aura;
  final bool auraParticles;
  final Future<Uint8List?> Function()? captureLayoutPreview;
  const _ProductionImageButton({
    required this.id,
    required this.shortcutKey,
    required this.asset,
    required this.title,
    this.titleVerticalOffset = .11,
    this.titleFontSize = 20,
    required this.semanticsLabel,
    required this.onActivate,
    this.aura = false,
    this.auraParticles = true,
    this.captureLayoutPreview,
  });

  @override
  Widget build(BuildContext context) => LayoutButtonRoyalClean(
    id: id,
    capturePreview: captureLayoutPreview ?? () => _assetPreview(asset),
    child: AspectRatio(
      aspectRatio: 1253 / 600,
      child: Builder(
        builder: (layoutContext) => Semantics(
          button: true,
          label: semanticsLabel,
          child: ImageActionRoyalClean(
            key: shortcutKey,
            pulses: 2,
            activateBeforeAnimation: true,
            duration: const Duration(milliseconds: 600),
            scaleDepth: .018,
            replayAfterActivation: true,
            onActivate: onActivate,
            onAdminEdit: LayoutButtonRoyalClean.adminLongPressOf(layoutContext),
            builder: (_, flash) {
              final content = Stack(
                alignment: Alignment.center,
                children: [
                  NeonImageRoyalClean(
                    asset: asset,
                    aspectRatio: 1253 / 600,
                    glow: const Color(0xFF9955FF),
                    activation: flash,
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: LayoutBuilder(
                        builder: (_, constraints) => Transform.translate(
                          offset: Offset(
                            0,
                            constraints.maxHeight * titleVerticalOffset,
                          ),
                          child: Center(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: const Color(0xFF092F43),
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
              return aura
                  ? AvatarAuraRoyalClean(
                      asset: asset,
                      activation: flash,
                      particles: auraParticles,
                      child: content,
                    )
                  : content;
            },
          ),
        ),
      ),
    ),
  );

  static Future<Uint8List> _assetPreview(String asset) async {
    final data = await rootBundle.load(asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}

/// Fixed particle budget; no blur, image decoding or allocations outside paint.
class _DrawerAshRoyalClean extends StatefulWidget {
  const _DrawerAshRoyalClean();
  @override
  State<_DrawerAshRoyalClean> createState() => _DrawerAshState();
}

class _DrawerAshState extends State<_DrawerAshRoyalClean>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  bool _foreground = true, _enabled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _updateMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _updateMotion();
  }

  void _updateMotion() {
    if (_enabled && _foreground) {
      if (!_flow.isAnimating) _flow.repeat();
    } else {
      _flow.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(painter: _DrawerAshPainter(_flow, _enabled)),
      ),
    ),
  );
}

class _DrawerAshPainter extends CustomPainter {
  final Animation<double> flow;
  final bool enabled;
  _DrawerAshPainter(this.flow, this.enabled) : super(repaint: flow);
  @override
  void paint(Canvas canvas, Size size) {
    if (!enabled || size.isEmpty) return;
    final scale = size.shortestSide;
    for (var i = 0; i < 36; i++) {
      final age = (flow.value + i * .618034) % 1;
      final fade = math.sin(age * math.pi);
      final seed = math.sin(i * 127.1 + 311.7) * 43758.5453;
      final x = (seed - seed.floorToDouble()) * .82 + .09;
      final sway = math.sin(age * math.pi * 3 + i * 1.7) * scale * .025;
      final center = Offset(
        size.width * x + sway,
        size.height * (.82 - age * .75),
      );
      final radius = scale * (.0035 + (i % 4) * .0011);
      final flake = Path()
        ..moveTo(center.dx - radius, center.dy)
        ..lineTo(center.dx - radius * .15, center.dy - radius * .65)
        ..lineTo(center.dx + radius, center.dy - radius * .1)
        ..lineTo(center.dx + radius * .2, center.dy + radius * .7)
        ..close();
      canvas.drawPath(
        flake,
        Paint()..color = const Color(0xFFBDEFFF).withValues(alpha: fade * .72),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DrawerAshPainter old) =>
      old.enabled != enabled || old.flow != flow;
}
