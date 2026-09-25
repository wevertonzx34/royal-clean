import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/account_ui_royal_clean.dart';

class BlingIntegrationPageRoyalClean extends StatefulWidget {
  const BlingIntegrationPageRoyalClean({super.key});
  @override
  State<BlingIntegrationPageRoyalClean> createState() =>
      _BlingIntegrationState();
}

class _BlingIntegrationState extends State<BlingIntegrationPageRoyalClean>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _status;
  String? _error;
  bool _busy = false;
  bool _needsVerification = false;
  bool _verificationSent = false;
  DateTime? _checkedAt;
  final _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  String _message(Object error) {
    if (error is TimeoutException) {
      return 'A consulta demorou mais que o esperado. Tente novamente.';
    }
    if (error is FirebaseAuthException) {
      if (error.code == 'too-many-requests') {
        return 'Aguarde alguns minutos antes de solicitar outro e-mail.';
      }
      return 'Não foi possível validar sua sessão. Verifique a conexão e tente novamente.';
    }
    if (error is FirebaseFunctionsException) {
      if (error.code == 'failed-precondition' ||
          error.code == 'resource-exhausted') {
        return error.message ??
            'A conexão precisa de configuração no servidor.';
      }
      if (error.code == 'permission-denied' ||
          error.code == 'unauthenticated') {
        return 'Verifique sua sessão de administrador e a validação do aplicativo.';
      }
      if (error.code == 'not-found') {
        return 'O backend da integração ainda precisa ser publicado no Firebase.';
      }
    }
    return 'Não foi possível consultar a integração. Verifique a conexão e tente novamente.';
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Reload only while verification is pending. Forcing token refresh on
      // every mount makes Firestore reauthenticate, which can remount this
      // protected route and start an endless status/refresh cycle.
      final wasUnverified =
          FirebaseAuth.instance.currentUser?.emailVerified == false;
      if (wasUnverified) {
        await FirebaseAuth.instance.currentUser?.reload().timeout(
          const Duration(seconds: 20),
        );
      }
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(code: 'unauthenticated');
      }
      if (!user.emailVerified) {
        if (mounted) {
          setState(() {
            _needsVerification = true;
            _status = null;
          });
        }
        return;
      }
      if (wasUnverified) {
        await user.getIdToken(true).timeout(const Duration(seconds: 20));
      }
      if (!mounted) return;
      if (mounted) setState(() => _needsVerification = false);
      final response = await _functions
          .httpsCallable(
            'blingConnectionStatus',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call()
          .timeout(const Duration(seconds: 35));
      if (mounted) {
        setState(() {
          _status = Map<String, dynamic>.from(response.data as Map);
          _checkedAt = DateTime.now();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendVerification() async {
    if (_busy || _verificationSent) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw FirebaseAuthException(code: 'unauthenticated');
      await user.sendEmailVerification().timeout(const Duration(seconds: 20));
      if (mounted) setState(() => _verificationSent = true);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renovar autorização do Bling'),
        content: const Text(
          'Após alterar os escopos no Bling, autorize novamente a mesma empresa Royal Clean. A conexão anterior será substituída somente após concluir a autorização.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _connect();
  }

  Future<void> _connect() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _functions
          .httpsCallable('blingBeginAuthorization')
          .call({'reconnect': _status?['status'] == 'authorized'});
      final url = Uri.parse((response.data as Map)['url'] as String);
      if (url.scheme != 'https' ||
          url.host !=
              'southamerica-east1-royal-clean-fire.cloudfunctions.net' ||
          url.path != '/blingCallback' ||
          !url.queryParameters.containsKey('start')) {
        throw StateError('Unexpected authorization address');
      }
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw StateError('Browser unavailable');
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status?['status'];
    final authorized = status == 'authorized';
    return AccountLayoutRoyalClean(
      title: 'Integração Bling',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.hub_outlined, size: 48),
          const SizedBox(height: 16),
          Text(
            _needsVerification
                ? 'Confirme seu e-mail'
                : authorized
                ? 'Autorização registrada'
                : status == 'ready'
                ? 'Pronto para autorizar'
                : 'Preparar conexão',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Conexão segura da conta Royal Clean. Consulta de dados restrita aos administradores.',
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_needsVerification) ...[
            Text(
              'Para conectar a conta da empresa, confirme o e-mail ${FirebaseAuth.instance.currentUser?.email ?? "da sua conta"}. Abra o link recebido e volte a esta tela.',
            ),
            const SizedBox(height: 12),
            if (_verificationSent)
              const Text(
                'E-mail de verificação enviado. Confira também a pasta de spam.',
              ),
            TextButton.icon(
              onPressed: _busy || _verificationSent ? null : _sendVerification,
              icon: const Icon(Icons.mark_email_read_outlined),
              label: Text(
                _verificationSent
                    ? 'E-mail enviado'
                    : 'Enviar e-mail de verificação',
              ),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(_error!),
            ),
          if (status == 'configuration_required')
            const Text(
              'Falta configurar as credenciais do aplicativo Bling e o acesso do backend ao Secret Manager. Nenhuma chave deve ser colocada no aplicativo móvel.',
            ),
          if (authorized) ...[
            const Text(
              'Consulte produtos e pedidos reais. A conexão é renovada automaticamente quando necessário durante as consultas.',
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/bling-data'),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Ver produtos e movimentações'),
            ),
            if (_status?['reauthorizationRequired'] == true)
              const Text(
                'A autorização precisa ser renovada antes de consultar os dados.',
              ),
            TextButton.icon(
              onPressed: _busy ? null : _confirmReconnect,
              icon: const Icon(Icons.link),
              label: const Text('Renovar autorização'),
            ),
          ],
          if (_status?['callbackUrl'] is String) ...[
            const SizedBox(height: 20),
            const Text('Link de redirecionamento para o cadastro no Bling'),
            const SizedBox(height: 8),
            SelectableText(_status!['callbackUrl'] as String),
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar endereço'),
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: _status!['callbackUrl'] as String),
                );
                if (context.mounted) {
                  showAccountMessageRoyalClean(context, 'Endereço copiado.');
                }
              },
            ),
          ],
          const SizedBox(height: 20),
          if (!authorized && !_needsVerification)
            FilledButton.icon(
              onPressed: !_busy && status == 'ready' ? _connect : null,
              icon: const Icon(Icons.open_in_browser_rounded),
              label: const Text('Conectar ao Bling'),
            ),
          TextButton.icon(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              _busy
                  ? 'Consultando…'
                  : _needsVerification
                  ? 'Já confirmei meu e-mail'
                  : 'Atualizar status',
            ),
          ),
          if (_checkedAt != null && !_needsVerification)
            Text(
              'Última consulta: ${TimeOfDay.fromDateTime(_checkedAt!).format(context)}',
            ),
          const SizedBox(height: 12),
          const Text(
            'Nesta etapa, nenhum produto, pedido, preço ou estoque é alterado. Ao autorizar no navegador, volte ao aplicativo para conferir o status.',
          ),
        ],
      ),
    );
  }
}
