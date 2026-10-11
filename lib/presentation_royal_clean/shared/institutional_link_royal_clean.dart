import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core_royal_clean/services/web_configuration_royal_clean.dart';
import 'layout_button_royal_clean.dart';

class InstitutionalLinkRoyalClean extends StatelessWidget {
  const InstitutionalLinkRoyalClean({super.key});

  @override
  Widget build(BuildContext context) {
    final uri = WebConfigurationRoyalClean.institutionalUri;
    if (!kIsWeb || uri == null) return const SizedBox.shrink();
    return LayoutButtonRoyalClean(
      id: 'web.institutional_link',
      child: TextButton.icon(
        icon: const Icon(Icons.open_in_new),
        label: const Text('Site institucional'),
        onPressed: () async {
          try {
            final opened = await launchUrl(uri, webOnlyWindowName: '_self');
            if (!opened) throw StateError('Institutional page unavailable');
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Não foi possível abrir o site institucional.'),
                ),
              );
            }
          }
        },
      ),
    );
  }
}
