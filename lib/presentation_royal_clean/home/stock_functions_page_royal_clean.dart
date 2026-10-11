import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'office_shortcut_royal_clean.dart';
import 'image_action_royal_clean.dart';
import 'my_property_page_royal_clean.dart';
import '../auth/admin_route_guard_royal_clean.dart';
import '../shared/layout_button_royal_clean.dart';
import 'stock_lighting_royal_clean.dart';
import 'royal_3d_neon.dart';
import 'stock_data_shortcut_royal_clean.dart';
import 'office_room_page_royal_clean.dart';
import 'production_drawer_royal_clean.dart';
import '../shared/header_actions_royal_clean.dart';

class StockFunctionsPageRoyalClean extends StatefulWidget {
  final Future<void> Function()? onOpenOffice;
  const StockFunctionsPageRoyalClean({super.key, this.onOpenOffice});

  @override
  State<StockFunctionsPageRoyalClean> createState() =>
      _StockFunctionsPageState();
}

class _StockFunctionsPageState extends State<StockFunctionsPageRoyalClean> {
  PersistentBottomSheetController? _drawer;

  Future<void> _toggleDrawer(BuildContext context) async {
    final current = _drawer;
    if (current != null) {
      current.close();
      return;
    }
    final controller = Scaffold.of(context).showBottomSheet(
      (_) => const ProductionDrawerRoyalClean(
        showOrders: false,
        showRevenue: false,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      enableDrag: false,
    );
    _drawer = controller;
    // Do not hold the shortcut's tap handler until the drawer closes.
    // Back navigation and explicit closure both release this same controller.
    controller.closed.then((_) {
      if (identical(_drawer, controller)) _drawer = null;
    });
  }

  Future<void> _openOffice(BuildContext context) async {
    final current = _drawer;
    if (current != null) {
      current.close();
      await current.closed;
    }
    if (!context.mounted) return;
    await (widget.onOpenOffice?.call() ?? openOfficeRoomRoyalClean(context));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    extendBody: true,
    appBar: AppBar(
      title: const Text('Funções de estoque', style: TextStyle(fontSize: 18)),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      actions: const [HeaderActionsRoyalClean(stockNeon: true)],
    ),
    body: Builder(
      builder: (context) => Stack(
        fit: StackFit.expand,
        children: [
          StockBackgroundRoyalClean(
            showOffice: true,
            onOpenOffice: () => _openOffice(context),
            onOpenProduction: () => _toggleDrawer(context),
            onOpenProperty: () async {
              await precacheImage(
                const ResizeImage(
                  AssetImage('assets/preview/royal-store/royal-pixels.webp'),
                  width: 1080,
                ),
                context,
              );
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdminRouteGuardRoyalClean(
                    firebaseInitialization: Future<void>.value(),
                    pendingBackground: const MyPropertyBackgroundRoyalClean(),
                    builder: (_) => const MyPropertyPageRoyalClean(),
                  ),
                ),
              );
            },
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: StockDataShortcutRoyalClean(keepAboveSheets: true),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Public decorative background: safe to show while access is being checked.
class StockBackgroundRoyalClean extends StatefulWidget {
  final bool showOffice;
  final Future<void> Function()? onOpenProperty;
  final Future<void> Function()? onOpenOffice;
  final Future<void> Function()? onOpenProduction;
  const StockBackgroundRoyalClean({
    super.key,
    this.showOffice = false,
    this.onOpenProperty,
    this.onOpenOffice,
    this.onOpenProduction,
  });

  // Coordinates in the original royal-stoque image (2250 x 4000).
  // The office and backdrop share one transform, including cover cropping.
  static const royal3dRect = Rect.fromLTWH(0, 0, 2250, 2250 * 391 / 625);
  static const sceneSize = Size(2250, 4000);
  static const officeRect = Rect.fromLTWH(1645, 1380, 620, 620 * 415 / 191);
  static const productionRect = Rect.fromLTWH(0, 2110, 660, 660 * 496 / 650);
  @override
  State<StockBackgroundRoyalClean> createState() => _StockBackgroundState();
}

class _StockBackgroundState extends State<StockBackgroundRoyalClean> {
  final _lightTouch = ValueNotifier<int>(0);

  void _flashLights() => _lightTouch.value++;

  @override
  void dispose() {
    _lightTouch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const scene = StockBackgroundRoyalClean.sceneSize;
      final scale = math.max(
        constraints.maxWidth / scene.width,
        constraints.maxHeight / scene.height,
      );
      final offset = Offset(
        (constraints.maxWidth - scene.width * scale) / 2,
        (constraints.maxHeight - scene.height * scale) / 2,
      );
      Rect sceneRect(Rect rect) => Rect.fromLTWH(
        offset.dx + rect.left * scale,
        offset.dy + rect.top * scale,
        rect.width * scale,
        rect.height * scale,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: StockBackgroundRoyalClean.sceneSize.width,
              height: StockBackgroundRoyalClean.sceneSize.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/preview/royal-store/royal-stoque.webp',
                    fit: BoxFit.fill,
                    cacheWidth: 1080,
                    excludeFromSemantics: true,
                  ),
                  if (widget.showOffice)
                    Positioned.fromRect(
                      rect: StockBackgroundRoyalClean.royal3dRect,
                      child: LayoutButtonRoyalClean(
                        id: 'stock.royal-3d',
                        child: Semantics(
                          button: true,
                          label: 'Royal 3D',
                          hint:
                              'Toque para iluminar. Segure para abrir My propriedade.',
                          child: ImageActionRoyalClean(
                            key: const ValueKey('royal-3d-shortcut'),
                            pulses: 2,
                            duration: const Duration(milliseconds: 120),
                            activateBeforeAnimation: true,
                            repeatActivationDuringAnimation: true,
                            scaleDepth: .006,
                            onActivate: _flashLights,
                            onLongActivate: () async {
                              await widget.onOpenProperty?.call();
                            },
                            builder: (_, flash) =>
                                Royal3dNeon(activation: flash),
                          ),
                        ),
                      ),
                    ),
                  StockLightingRoyalClean(trigger: _lightTouch),
                ],
              ),
            ),
          ),
          if (widget.showOffice)
            Positioned.fromRect(
              rect: sceneRect(StockBackgroundRoyalClean.productionRect),
              child: OfficeShortcutRoyalClean.production(
                onTouch: _flashLights,
                onOpen: widget.onOpenProduction,
              ),
            ),
          if (widget.showOffice)
            Positioned.fromRect(
              rect: sceneRect(StockBackgroundRoyalClean.officeRect),
              child: OfficeShortcutRoyalClean(
                onTouch: _flashLights,
                onOpen: widget.onOpenOffice,
              ),
            ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB3001420), Colors.transparent],
                  stops: [0, .25],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
