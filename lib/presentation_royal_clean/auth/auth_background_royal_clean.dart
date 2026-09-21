import 'package:flutter/material.dart';

class AuthBackgroundRoyalClean extends StatelessWidget {
  final Widget child;

  const AuthBackgroundRoyalClean({super.key, required this.child});

  // =========================================
  // CONTROLE MANUAL DA IMAGEM DE FUNDO
  // =========================================
  //
  // Mantém a lógica atual, mas sempre baseada
  // no tamanho real da tela do dispositivo.
  //
  static const double backgroundScale = 1.0;
  static const double backgroundOffsetX = 0.0;
  static const double backgroundOffsetY = 0.0;

  static const double overlayTopOpacity = 0.35;
  static const double overlayCenterOpacity = 0.18;
  static const double overlayBottomOpacity = 0.45;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const overlayGradient = LinearGradient(
          colors: [
            Color.fromRGBO(0, 0, 0, overlayTopOpacity),
            Color.fromRGBO(0, 0, 0, overlayCenterOpacity),
            Color.fromRGBO(0, 0, 0, overlayBottomOpacity),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        final double screenWidth = constraints.maxWidth;
        final double screenHeight = constraints.maxHeight;

        // A imagem continua proporcional à tela do dispositivo.
        final double imageWidth = screenWidth * backgroundScale;
        final double imageHeight = screenHeight * backgroundScale;

        return SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: const Color(0xFF021722)),
              Positioned(
                left: ((screenWidth - imageWidth) / 2) + backgroundOffsetX,
                top: ((screenHeight - imageHeight) / 2) + backgroundOffsetY,
                width: imageWidth,
                height: imageHeight,
                child: Image.asset(
                  'assets/thema/theme-auth.webp',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF021722),
                      alignment: Alignment.center,
                      child: const Text(
                        'Falha ao carregar background',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
              Container(decoration: const BoxDecoration(gradient: overlayGradient)),
              SafeArea(child: child),
            ],
          ),
        );
      },
    );
  }
}
