import 'package:flutter/material.dart';

/// Local illustrative artwork; the crown is decorative, not an official logo.
class PartnerDemoArtRoyalClean extends StatelessWidget {
  final String id;
  const PartnerDemoArtRoyalClean({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final palettes = [
      [const Color(0xFF031923), const Color(0xFF11617B)],
      [const Color(0xFF06142F), const Color(0xFF2758A0)],
      [const Color(0xFF073B44), const Color(0xFF178C93)],
      [const Color(0xFF171D35), const Color(0xFF655735)],
    ];
    final index = (int.tryParse(id.split('-').last) ?? 1) - 1;
    return Semantics(
      label: 'Arte demonstrativa Royal Clean com coroa decorativa',
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palettes[index.clamp(0, 3)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: -30,
              top: -90,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .12),
                    width: 28,
                  ),
                ),
              ),
            ),
            Positioned(
              left: -60,
              bottom: -120,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                    width: 1,
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 46,
                    height: 30,
                    child: CustomPaint(painter: _CrownPainter()),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 110,
                    width: 190,
                    child: Image.asset(
                      'assets/logo/logo-splash.webp',
                      cacheWidth: 570,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * .2)
      ..lineTo(size.width * .25, size.height * .47)
      ..lineTo(size.width * .5, 0)
      ..lineTo(size.width * .75, size.height * .47)
      ..lineTo(size.width, size.height * .2)
      ..lineTo(size.width * .87, size.height * .82)
      ..lineTo(size.width * .13, size.height * .82)
      ..close();
    final paint = Paint()..color = const Color(0xFFE8C879);
    canvas.drawPath(path, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * .13,
          size.height * .91,
          size.width * .74,
          size.height * .09,
        ),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => false;
}
