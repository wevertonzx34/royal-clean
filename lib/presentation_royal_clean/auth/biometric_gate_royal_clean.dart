import 'package:flutter/material.dart';
import '../../core_royal_clean/services/biometric_access_royal_clean.dart';

/// Defense in depth: private widgets are not built until local unlock succeeds.
/// Firebase/Firestore authorization still runs after this gate.
class BiometricGateRoyalClean extends StatefulWidget {
  final WidgetBuilder builder;
  final BiometricAccessRoyalClean? access;
  const BiometricGateRoyalClean({
    super.key,
    required this.builder,
    this.access,
  });
  @override
  State<BiometricGateRoyalClean> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGateRoyalClean> {
  late final service = widget.access ?? BiometricAccessRoyalClean.instance;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && service.locked) _unlock();
    });
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final confirmed = await service.unlock();
      if (mounted && !confirmed) {
        setState(
          () => _error =
              'Desbloqueio não confirmado. Use a digital ou escolha a senha do aparelho na janela do sistema.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível confirmar o acesso. Verifique a conexão e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.locked) return widget.builder(context);
        return Scaffold(
          appBar: AppBar(title: const Text('Desbloquear perfil')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fingerprint, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'Use a digital, o PIN, o padrão ou a senha deste aparelho para acessar seu perfil.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Text(_error!, textAlign: TextAlign.center),
                  FilledButton.icon(
                    onPressed: _busy ? null : _unlock,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(
                      _busy ? 'Confirmando…' : 'Desbloquear aparelho',
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (_) => false,
                    ),
                    child: const Text('Entrar com outra conta'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/preview',
                      (_) => false,
                    ),
                    child: const Text('Voltar à loja'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
