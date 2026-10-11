import 'dart:math' as math;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core_royal_clean/services/account_access_royal_clean.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth/admin_route_guard_royal_clean.dart';
import '../shared/layout_button_royal_clean.dart';
import 'avatar_aura_royal_clean.dart';
import 'image_action_royal_clean.dart';
import 'office_image_action_royal_clean.dart';
import 'neon_image_royal_clean.dart';
import 'order_care_page_royal_clean.dart';
import 'royal_catalog_page_royal_clean.dart';
import 'recent_products_hologram_royal_clean.dart';

Future<void> openProductionDrawerRoyalClean(
  BuildContext context, {
  bool showOrders = true,
  bool showRevenue = true,
}) async {
  if (!context.mounted) return;
  final scaffold = Scaffold.maybeOf(context);
  if (scaffold != null) {
    final controller = scaffold.showBottomSheet(
      (_) => ProductionDrawerRoyalClean(
        showOrders: showOrders,
        showRevenue: showRevenue,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      enableDrag: false,
    );
    await controller.closed;
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    elevation: 0,
    showDragHandle: false,
    enableDrag: false,
    builder: (_) => ProductionDrawerRoyalClean(
      showOrders: showOrders,
      showRevenue: showRevenue,
    ),
  );
}

class ProductionDrawerRoyalClean extends StatefulWidget {
  final bool showOrders;
  final bool showRevenue;
  final Future<void> Function()? onOpenOrders;
  final Future<void> Function()? onOpenProducts;
  final Future<void> Function()? onOpenRevenue;
  final Future<Uint8List?> Function()? captureLayoutPreview;
  final Stream<List<Map<String, dynamic>>>? recentProducts;
  const ProductionDrawerRoyalClean({
    super.key,
    this.showOrders = true,
    this.showRevenue = true,
    this.onOpenOrders,
    this.onOpenProducts,
    this.onOpenRevenue,
    this.captureLayoutPreview,
    this.recentProducts,
  });
  @override
  State<ProductionDrawerRoyalClean> createState() => _ProductionDrawerState();
}

class _ProductionDrawerState extends State<ProductionDrawerRoyalClean> {
  // IDs belong to physical slots so approved geometry survives content swaps.
  static const _ids = [
    'production.royal-produtos',
    'production.royal-pedidos',
    'production.royal-receita',
  ];
  static const _names = ['Produtos', 'Pedidos', 'Produção'];
  static const _keys = [
    'royal-produtos-shortcut',
    'royal-pedidos-shortcut',
    'royal-receita-shortcut',
  ];
  List<int> _slots = [0, 1, 2];
  int _selectionVersion = 0;
  String? _adminUid;

  @override
  void initState() {
    super.initState();
    final access = AccountAccessRoyalClean.instance.value;
    if (access.status == AccountAccessStatus.admin) {
      _adminUid = access.identity?.uid;
      unawaited(_restoreSelection());
    }
  }

  Future<void> _restoreSelection() async {
    final uid = _adminUid;
    if (uid == null) return;
    final version = _selectionVersion;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('production.button_slots.v1.$uid');
      if (!mounted ||
          version != _selectionVersion ||
          saved == null ||
          AccountAccessRoyalClean.instance.value.identity?.uid != uid) {
        return;
      }
      final slots = saved.map(int.tryParse).toList();
      if (slots.length == 3 && slots.toSet().containsAll([0, 1, 2])) {
        if ((!widget.showOrders && slots[0] == 1) ||
            (!widget.showRevenue && slots[0] == 2)) {
          final productSlot = slots.indexOf(0);
          slots[productSlot] = slots[0];
          slots[0] = 0;
        }
        setState(() => _slots = slots.cast<int>());
      }
    } catch (_) {
      /* Keep the original ordering if preferences are unavailable. */
    }
  }

  Future<void> _saveSelection(List<int> slots, String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'production.button_slots.v1.$uid',
        slots.map((x) => '$x').toList(),
      );
    } catch (_) {
      /* Navigation remains usable if local persistence fails. */
    }
  }

  Future<void> _activateButton(BuildContext context, int button) async {
    final access = AccountAccessRoyalClean.instance.value;
    if (access.status == AccountAccessStatus.admin &&
        access.identity?.uid == _adminUid) {
      final slot = _slots.indexOf(button);
      if (slot != 0) {
        setState(() {
          final previous = _slots[0];
          _slots[0] = button;
          _slots[slot] = previous;
          _selectionVersion++;
        });
        if (_adminUid != null) {
          unawaited(_saveSelection(List.of(_slots), _adminUid!));
        }
      }
    }
    switch (button) {
      case 0:
        await (widget.onOpenProducts?.call() ?? _openCatalog(context, false));
      case 1:
        await (widget.onOpenOrders?.call() ?? openOrderCareRoyalClean(context));
      case 2:
        await (widget.onOpenRevenue?.call() ?? _openCatalog(context, true));
    }
  }

  Widget _slotButton(BuildContext context, int slot) {
    final button = _slots[slot];
    if (!widget.showOrders && button == 1) return const SizedBox.shrink();
    if (!widget.showRevenue && button == 2) return const SizedBox.shrink();
    final principal = slot == 0;
    return _ProductionImageButton(
      key: ValueKey(_ids[slot]),
      id: _ids[slot],
      shortcutKey: ValueKey(_keys[button]),
      asset: [_products, _orders, _revenue][button],
      title: _names[button],
      titleVerticalOffset: .11,
      titleFontSize: button == 1 ? 22 * (slot == 1 ? .78 / .62 : 1) : 20,
      semanticsLabel:
          '${principal ? 'Principal. ' : ''}${switch (button) {
            0 => 'Abrir consulta de produtos',
            1 => 'Abrir atendimento do pedido',
            _ => 'Produção: abrir consulta de receita',
          }}',
      aura: true,
      auraParticles: principal,
      captureLayoutPreview: widget.captureLayoutPreview,
      onActivate: () => _activateButton(context, button),
    );
  }

  static const _orders = 'assets/preview/royal-store/royal-pedidos.webp';
  static const _products = 'assets/preview/royal-store/royal-produtos.webp';
  static const _revenue = 'assets/preview/royal-store/royal-receita.webp';

  Future<void> _openCatalog(BuildContext context, bool production) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AdminRouteGuardRoyalClean(
            firebaseInitialization: Future<void>.value(),
            builder: (_) => RoyalCatalogPageRoyalClean(production: production),
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
                          hitTestAsset:
                              'assets/preview/royal-store/royal-gaveta.webp',
                          layoutScope: 'app',
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
                      Align(
                        alignment: const Alignment(0, -1.7),
                        child: FractionallySizedBox(
                          widthFactor: .8,
                          child: RecentProductsHologramRoyalClean(
                            products: widget.recentProducts,
                            capturePreview: widget.captureLayoutPreview,
                            onOpen: () => _activateButton(context, 0),
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: .78,
                        child: _slotButton(context, 1),
                      ),
                      Align(
                        alignment: const Alignment(0, -.67),
                        child: FractionallySizedBox(
                          widthFactor: .62,
                          child: _slotButton(context, 0),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, .67),
                        child: FractionallySizedBox(
                          widthFactor: .62,
                          child: _slotButton(context, 2),
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

class OfficeRecipeShortcutRoyalClean extends StatelessWidget {
  final Future<void> Function()? onOpen;
  const OfficeRecipeShortcutRoyalClean({super.key, this.onOpen});
  @override
  Widget build(BuildContext context) => _ProductionImageButton(
    id: 'office.royal-receita',
    shortcutKey: const ValueKey('office-royal-receita-shortcut'),
    asset: 'assets/preview/royal-store/royal-receita.webp',
    title: '',
    titleVerticalOffset: .11,
    titleFontSize: 20,
    semanticsLabel: 'Produção: abrir auditoria de produtos',
    aura: true,
    auraParticles: false,
    onActivate: () =>
        onOpen?.call() ??
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => AdminRouteGuardRoyalClean(
              firebaseInitialization: Future<void>.value(),
              builder: (_) =>
                  const RoyalCatalogPageRoyalClean(production: true),
            ),
          ),
        ),
  );
}

class OfficeOrdersShortcutRoyalClean extends StatelessWidget {
  final Future<void> Function()? onOpen;
  const OfficeOrdersShortcutRoyalClean({super.key, this.onOpen});
  @override
  Widget build(BuildContext context) => _ProductionImageButton(
    id: 'office.royal-pedidos',
    shortcutKey: const ValueKey('office-royal-pedidos-shortcut'),
    asset: 'assets/preview/royal-store/royal-pedidos.webp',
    title: '',
    titleVerticalOffset: .11,
    titleFontSize: 22,
    semanticsLabel: 'Abrir atendimento do pedido',
    aura: true,
    auraParticles: false,
    onActivate: () => onOpen?.call() ?? openOrderCareRoyalClean(context),
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
    super.key,
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
    hitTestAsset: id.startsWith('office.') ? asset : null,
    layoutScope: 'app',
    freeMovement: id.startsWith('office.'),
    maxScale: id == 'office.royal-receita' ? 7 : 2.5,
    alwaysOverlay: id.startsWith('office.'),
    capturePreview: captureLayoutPreview ?? () => _assetPreview(asset),
    child: AspectRatio(
      aspectRatio: 1253 / 600,
      child: Builder(
        builder: (layoutContext) => Semantics(
          button: true,
          label: semanticsLabel,
          child: id.startsWith('office.')
              ? OfficeImageActionRoyalClean(
                  key: shortcutKey,
                  asset: asset,
                  cacheWidth: id == 'office.royal-receita' ? 1253 : 900,
                  onActivate: onActivate,
                  onAdminEdit: LayoutButtonRoyalClean.adminLongPressOf(
                    layoutContext,
                  ),
                )
              : ImageActionRoyalClean(
                  key: shortcutKey,
                  pulses: 2,
                  activateBeforeAnimation: true,
                  duration: const Duration(milliseconds: 600),
                  scaleDepth: .018,
                  replayAfterActivation: true,
                  onActivate: onActivate,
                  onAdminEdit: LayoutButtonRoyalClean.adminLongPressOf(
                    layoutContext,
                  ),
                  builder: (_, flash) {
                    final content = Stack(
                      alignment: Alignment.center,
                      children: [
                        NeonImageRoyalClean(
                          asset: asset,
                          cacheWidth: id == 'office.royal-receita' ? 1253 : 900,
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
                            particleColor: const Color(0xFFC08AFF),
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
