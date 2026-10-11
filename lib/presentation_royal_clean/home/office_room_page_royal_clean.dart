import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth/admin_route_guard_royal_clean.dart';
import '../shared/layout_button_royal_clean.dart';
import 'office_image_action_royal_clean.dart';
import 'nfe_page_royal_clean.dart';
import 'production_drawer_royal_clean.dart';
import 'office_balloon_royal_clean.dart';

Future<void> openOfficeRoomRoyalClean(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AdminRouteGuardRoyalClean(
          firebaseInitialization: Future<void>.value(),
          builder: (_) => const OfficeRoomPageRoyalClean(),
        ),
      ),
    );

class OfficeRoomPageRoyalClean extends StatelessWidget {
  final Future<void> Function()? onOpenNfe;
  final Future<void> Function()? onOpenProduction, onOpenOrders;
  const OfficeRoomPageRoyalClean({
    super.key,
    this.onOpenNfe,
    this.onOpenProduction,
    this.onOpenOrders,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    extendBody: true,
    appBar: AppBar(
      title: const Text('Escritório'),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/preview/royal-store/royal-sala.webp',
          fit: BoxFit.cover,
          cacheWidth: 1080,
          excludeFromSemantics: true,
        ),
        _OfficeLayers(
          buttons: [
            SafeArea(
              child: Align(
                alignment: const Alignment(0, -.65),
                child: SizedBox(
                  width: (MediaQuery.sizeOf(context).width * .58).clamp(
                    120,
                    200,
                  ),
                  child: OfficeRecipeShortcutRoyalClean(
                    onOpen: onOpenProduction,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: const Alignment(0, -.15),
                child: SizedBox(
                  width: (MediaQuery.sizeOf(context).width * .7).clamp(
                    160,
                    300,
                  ),
                  child: OfficeOrdersShortcutRoyalClean(onOpen: onOpenOrders),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: const Alignment(0, .45),
                child: SizedBox(
                  width: (MediaQuery.sizeOf(context).width * .7).clamp(
                    160,
                    300,
                  ),
                  child: LayoutButtonRoyalClean(
                    id: 'office.royal-papper',
                    hitTestAsset:
                        'assets/preview/royal-store/royal-papper.webp',
                    freeMovement: true,
                    alwaysOverlay: true,
                    child: AspectRatio(
                      aspectRatio: 1253 / 600,
                      child: Builder(
                        builder: (layoutContext) => Semantics(
                          button: true,
                          label: 'Abrir NF-e',
                          child: OfficeImageActionRoyalClean(
                            key: const ValueKey('royal-papper-shortcut'),
                            asset:
                                'assets/preview/royal-store/royal-papper.webp',
                            cacheWidth: 700,
                            onAdminEdit:
                                LayoutButtonRoyalClean.adminLongPressOf(
                                  layoutContext,
                                ),
                            onActivate: () =>
                                onOpenNfe?.call() ?? openNfeRoyalClean(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          balloons: [
            _balloon(context, 'balao-di', -.85, 200),
            _balloon(context, 'balaozin-es', -.45, 300),
            _balloon(context, 'balao-es', .15, 300),
          ],
        ),
      ],
    ),
  );

  Widget _balloon(
    BuildContext context,
    String name,
    double y,
    double maxWidth,
  ) => SafeArea(
    child: Align(
      alignment: Alignment(0, y),
      child: SizedBox(
        width: (MediaQuery.sizeOf(context).width * .7).clamp(120, maxWidth),
        child: OfficeBalloonRoyalClean(name: name),
      ),
    ),
  );
}

/// Separate overlay entries keep every balloon/title above every button portal,
/// regardless of which admin adjustment is restored or edited last.
class _OfficeLayers extends StatefulWidget {
  final List<Widget> buttons, balloons;
  const _OfficeLayers({required this.buttons, required this.balloons});
  @override
  State<_OfficeLayers> createState() => _OfficeLayersState();
}

class _OfficeLayersState extends State<_OfficeLayers> {
  late final _entries = [
    OverlayEntry(
      builder: (_) => Stack(fit: StackFit.expand, children: widget.buttons),
    ),
    OverlayEntry(
      builder: (_) => Stack(fit: StackFit.expand, children: widget.balloons),
    ),
  ];
  @override
  void didUpdateWidget(covariant _OfficeLayers oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final entry in _entries) {
      entry.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.remove();
      entry.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: _entries);
}
