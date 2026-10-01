import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shared/layout_button_royal_clean.dart';
import 'image_action_royal_clean.dart';
import 'neon_image_royal_clean.dart';
import 'wall_light_royal_clean.dart';

const royalBluBackgroundProvider = ResizeImage(
  AssetImage('assets/preview/royal-store/royal-home.webp'),
  width: 1800,
);
const royalBluLinkProvider = ResizeImage(
  AssetImage('assets/preview/royal-store/royal-link-blu.webp'),
  width: 900,
);
Future<void> prepareRoyalBlu(BuildContext context) async {
  await precacheImage(royalBluBackgroundProvider, context);
  if (!context.mounted) return;
  await precacheImage(royalBluLinkProvider, context);
}

/// The wall crop and its light share the same 720 x 1280 cover transform.
class RoyalBluPage extends StatefulWidget {
  final Future<bool> Function(Uri)? openLink;
  const RoyalBluPage({super.key, this.openLink});
  @override
  State<RoyalBluPage> createState() => _RoyalBluPageState();
}

class _RoyalBluPageState extends State<RoyalBluPage> {
  final _lightState = ValueNotifier<bool>(false);
  final _fault = ValueNotifier<int>(0);
  bool _openingLink = false;
  Future<void> _openLink() async {
    if (_openingLink) return;
    _openingLink = true;
    _fault.value++;
    final uri = Uri.parse(
      'https://bytes4273.vercel.app/#:~:text=O%20Futuro%20do%20Impacto%20Social%20e%20da%20Seguran%C3%A7a%20Empresarial.%20A%20miss%C3%A3o%20%C3%A9%20clara%3A%20fortalecer%20neg%C3%B3cios%2C%20proteger%20patrim%C3%B4nio%20e%20combater%20a%20corrup%C3%A7%C3%A3o%2C%20garantindo%20qualidade%20de%20servi%C3%A7os%20e%20efici%C3%AAncia%20no%20uso%20dos%20recursos%20p%C3%BAblicos.',
    );
    try {
      final opened =
          await (widget.openLink?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened) throw StateError('Link indisponível');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o site. Tente novamente.'),
          ),
        );
      }
    } finally {
      _openingLink = false;
    }
  }

  @override
  void dispose() {
    _lightState.dispose();
    _fault.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: const Color(0xFF03152E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: 720,
                height: 1280,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Original asset is 2250 x 4000. Select only the illuminated wall.
                    const Positioned(
                      left: -490 * 720 / 740,
                      top: -350 * 720 / 740,
                      width: 2250 * 720 / 740,
                      height: 4000 * 720 / 740,
                      child: Image(
                        image: royalBluBackgroundProvider,
                        fit: BoxFit.fill,
                        excludeFromSemantics: true,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 70,
                      bottom: 0,
                      child: WallLightRoyalClean(
                        openState: _lightState,
                        faultSignal: _fault,
                        fillBounds: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = math.min(
                  constraints.maxHeight * .5,
                  constraints.maxWidth * .9 * 609 / 594,
                );
                return Center(
                  child: SizedBox(
                    height: height,
                    width: height * 594 / 609,
                    child: LayoutButtonRoyalClean(
                      id: 'blu.link-image',
                      maxScale: 1.4,
                      freeMovement: true,
                      child: Semantics(
                        button: true,
                        label: 'Abrir site Blue Fund no navegador',
                        child: Tooltip(
                          message: 'Abrir site Blue Fund',
                          child: ImageActionRoyalClean(
                            key: const ValueKey('royal-link-blu'),
                            pulses: 2,
                            duration: const Duration(milliseconds: 600),
                            scaleDepth: .018,
                            onActivate: _openLink,
                            builder: (_, flash) => NeonImageRoyalClean(
                              asset:
                                  'assets/preview/royal-store/royal-link-blu.webp',
                              aspectRatio: 594 / 609,
                              cacheWidth: 900,
                              glow: const Color(0xFF5CE7EC),
                              activation: flash,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: LayoutButtonRoyalClean(
                  id: 'blu.back',
                  child: IconButton(
                    tooltip: 'Voltar',
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
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
