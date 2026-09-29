import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'office_shortcut_royal_clean.dart';
import 'stock_lighting_royal_clean.dart';
import 'nfe_page_royal_clean.dart';
import '../shared/header_actions_royal_clean.dart';

class StockFunctionsPageRoyalClean extends StatelessWidget {
  const StockFunctionsPageRoyalClean({super.key});
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
      actions: const [HeaderActionsRoyalClean()],
    ),
    body: StockBackgroundRoyalClean(
      showOffice: true,
      onOpenOffice: () => openNfeRoyalClean(context),
    ),
  );
}

/// Public decorative background: safe to show while access is being checked.
class StockBackgroundRoyalClean extends StatefulWidget {
  final bool showOffice;
  final Future<void> Function()? onOpenOffice;
  const StockBackgroundRoyalClean({
    super.key,
    this.showOffice = false,
    this.onOpenOffice,
  });

  // Coordinates in the original royal-stoque image (2250 x 4000).
  // The office and backdrop share one transform, including cover cropping.
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
  Widget build(BuildContext context) => SizedBox.expand(
    child: Stack(
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
                StockLightingRoyalClean(trigger: _lightTouch),
                if (widget.showOffice)
                  Positioned.fromRect(
                    rect: StockBackgroundRoyalClean.productionRect,
                    child: OfficeShortcutRoyalClean.production(
                      onTouch: _flashLights,
                    ),
                  ),
                if (widget.showOffice)
                  Positioned.fromRect(
                    rect: StockBackgroundRoyalClean.officeRect,
                    child: OfficeShortcutRoyalClean(
                      onTouch: _flashLights,
                      onOpen: widget.onOpenOffice,
                    ),
                  ),
              ],
            ),
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
    ),
  );
}
