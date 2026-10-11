import 'package:flutter/material.dart';
import '../shared/layout_button_royal_clean.dart';

/// Independent admin-adjustable decoration, with no business click action.
class OfficeBalloonRoyalClean extends StatelessWidget {
  final String name;
  const OfficeBalloonRoyalClean({super.key, required this.name});
  @override
  Widget build(BuildContext context) => LayoutButtonRoyalClean(
    id: switch (name) {
      'balao-di' => 'office.balao-di',
      'balao-es' => 'office.balao-es',
      _ => 'office.balaozin-es',
    },
    layoutScope: 'app',
    hitTestAsset: 'assets/preview/royal-store/$name.webp',
    freeMovement: true,
    minScale: .1,
    alwaysOverlay: true,
    passThroughTap: true,
    child: AspectRatio(
      aspectRatio: name == 'balaozin-es' ? 438 / 182 : 631 / 152,
      child: Semantics(
        label: 'Balão $name. Segure para ajustar posição e tamanho.',
        child: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              IgnorePointer(
                child: Image.asset(
                  'assets/preview/royal-store/$name.webp',
                  fit: BoxFit.contain,
                  cacheWidth: 700,
                  excludeFromSemantics: true,
                ),
              ),
              Align(
                alignment: const Alignment(0, -.2),
                child: LayoutButtonRoyalClean(
                  id: switch (name) {
                    'balao-di' => 'office.title.production',
                    'balao-es' => 'office.title.operation',
                    _ => 'office.title.orders',
                  },
                  layoutScope: 'app',
                  freeMovement: true,
                  alwaysOverlay: true,
                  passThroughTap: true,
                  minScale: .1,
                  child: IgnorePointer(
                    child: Text(
                      switch (name) {
                        'balao-di' => 'Produção',
                        'balao-es' => 'Operação',
                        _ => 'Pedidos',
                      },
                      style: const TextStyle(
                        color: Color(0xFF092F43),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
