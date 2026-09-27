import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    body: const StockBackgroundRoyalClean(),
  );
}

/// Public decorative background: safe to show while access is being checked.
class StockBackgroundRoyalClean extends StatelessWidget {
  const StockBackgroundRoyalClean({super.key});
  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/preview/royal-store/royal-stoque.webp',
          fit: BoxFit.cover,
          cacheWidth: 1080,
          excludeFromSemantics: true,
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
