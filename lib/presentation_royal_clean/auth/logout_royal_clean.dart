import 'package:flutter/material.dart';
import '../../core_royal_clean/services/auth_service_royal_clean.dart';

Future<void> logoutToPreviewRoyalClean(
  BuildContext context, {
  Future<void> Function()? signOut,
}) async {
  // Authentication listeners may dispose this page before signOut completes.
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await (signOut ?? AuthServiceRoyalClean.signOut)();
    if (navigator.mounted) {
      navigator.pushNamedAndRemoveUntil('/preview', (_) => false);
    }
  } catch (_) {
    if (messenger.mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível sair. Tente novamente.'),
        ),
      );
    }
  }
}
