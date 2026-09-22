import 'package:flutter/material.dart';
import '../../core_royal_clean/constants/app_routes_royal_clean.dart';
import '../../core_royal_clean/services/admin_access_royal_clean.dart';

class AdminRouteGuardRoyalClean extends StatefulWidget {
  final Future<void> firebaseInitialization;
  final WidgetBuilder builder;
  final Stream<AdminAccessRoyalClean> Function() accessStream;

  const AdminRouteGuardRoyalClean({
    super.key,
    required this.firebaseInitialization,
    required this.builder,
    this.accessStream = watchAdminAccessRoyalClean,
  });

  @override
  State<AdminRouteGuardRoyalClean> createState() =>
      _AdminRouteGuardRoyalCleanState();
}

class _AdminRouteGuardRoyalCleanState extends State<AdminRouteGuardRoyalClean> {
  late final Future<Stream<AdminAccessRoyalClean>> _ready;

  @override
  void initState() {
    super.initState();
    _ready = widget.firebaseInitialization
        .timeout(const Duration(seconds: 15))
        .then((_) => widget.accessStream());
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<Stream<AdminAccessRoyalClean>>(
    future: _ready,
    builder: (context, initialization) {
      if (initialization.hasError) {
        return _blocked(AdminAccessRoyalClean.unavailable);
      }
      if (!initialization.hasData) {
        return _blocked(AdminAccessRoyalClean.checking);
      }
      return StreamBuilder<AdminAccessRoyalClean>(
        stream: initialization.data,
        builder: (context, snapshot) {
          final state =
              snapshot.hasError ||
                  snapshot.connectionState == ConnectionState.done
              ? AdminAccessRoyalClean.unavailable
              : snapshot.data ?? AdminAccessRoyalClean.checking;
          // Lazy construction: protected widgets never build before authorization.
          return state == AdminAccessRoyalClean.allowed
              ? widget.builder(context)
              : _blocked(state);
        },
      );
    },
  );

  Widget _blocked(AdminAccessRoyalClean state) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state == AdminAccessRoyalClean.checking)
                  const CircularProgressIndicator()
                else
                  const Icon(Icons.lock_outline_rounded, size: 40),
                const SizedBox(height: 20),
                Text(switch (state) {
                  AdminAccessRoyalClean.checking =>
                    'Verificando acesso administrativo...',
                  AdminAccessRoyalClean.signedOut =>
                    'Entre com uma conta administrativa para continuar.',
                  AdminAccessRoyalClean.unavailable =>
                    'Não foi possível confirmar sua permissão. Verifique a conexão e tente entrar novamente.',
                  _ => 'Acesso restrito a administradores ativos.',
                }, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (state != AdminAccessRoyalClean.checking)
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutesRoyalClean.login,
                      (_) => false,
                    ),
                    child: const Text('Ir para login'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutesRoyalClean.preview,
                    (_) => false,
                  ),
                  child: const Text('Voltar à prévia'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
