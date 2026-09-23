import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/account_service_royal_clean.dart';
import 'auth_background_royal_clean.dart';
import 'account_ui_royal_clean.dart';

class LoginPageRoyalClean extends StatefulWidget {
  final Future<void>? firebaseInitialization;
  const LoginPageRoyalClean({super.key, this.firebaseInitialization});
  @override
  State<LoginPageRoyalClean> createState() => _LoginState();
}

class _LoginState extends State<LoginPageRoyalClean> {
  static final _secondaryButtonStyle = TextButton.styleFrom(
    foregroundColor: Colors.white,
    disabledForegroundColor: Colors.white38,
  );
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _obscure = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _authenticate(Future<void> Function() action) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await widget.firebaseInitialization?.timeout(const Duration(seconds: 15));
      await action();
      if (!mounted) return;
      _password.clear();
      if (mounted) Navigator.pushReplacementNamed(context, '/account');
    } catch (e) {
      if (mounted) {
        showAccountMessageRoyalClean(
          context,
          AccountServiceRoyalClean.error(e),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _ResetDialog(initialEmail: _email.text),
    );
    if (value == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.firebaseInitialization?.timeout(const Duration(seconds: 15));
      await FirebaseAuth.instance.sendPasswordResetEmail(email: value);
      if (mounted) {
        showAccountMessageRoyalClean(
          context,
          'Se houver uma conta elegível, você receberá as instruções por e-mail.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showAccountMessageRoyalClean(
          context,
          e.code == 'user-not-found'
              ? 'Se houver uma conta elegível, você receberá as instruções por e-mail.'
              : AccountServiceRoyalClean.error(e),
        );
      }
    } catch (e) {
      if (mounted) {
        showAccountMessageRoyalClean(
          context,
          AccountServiceRoyalClean.error(e),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuthBackgroundRoyalClean(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/logo/logo-gif.webp',
                        height: 220,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                style: _secondaryButtonStyle,
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.pushNamed(
                                        context,
                                        '/register',
                                      ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.person_add_alt_1_outlined,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Flexible(child: Text('Novo usuário')),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: _secondaryButtonStyle,
                                onPressed: _busy ? null : _resetPassword,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.key_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Esqueci senha',
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: validateEmailRoyalClean,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: _obscure,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Informe sua senha.'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () {
                                if (_form.currentState!.validate()) {
                                  _authenticate(() async {
                                    await FirebaseAuth.instance
                                        .signInWithEmailAndPassword(
                                          email: _email.text.trim(),
                                          password: _password.text,
                                        );
                                  });
                                }
                              },
                        child: Text(_busy ? 'Aguarde…' : 'Entrar'),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'ou continue com',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textButtonTheme
                              .style
                              ?.textStyle
                              ?.resolve({})
                              ?.copyWith(color: Colors.yellow),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                style: _secondaryButtonStyle,
                                onPressed: _busy
                                    ? null
                                    : () => _authenticate(
                                        AccountServiceRoyalClean.apple,
                                      ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.apple, size: 22),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text('Continuar com Apple'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: _secondaryButtonStyle,
                                onPressed: _busy
                                    ? null
                                    : () => _authenticate(
                                        AccountServiceRoyalClean.google,
                                      ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Opacity(
                                      opacity: _busy ? 0.4 : 1,
                                      child: Image.asset(
                                        'assets/logo/google-g.png',
                                        width: 16,
                                        height: 16,
                                        excludeFromSemantics: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Flexible(
                                      child: Text('Continuar com Google'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Sua sessão fica disponível neste dispositivo. Use “Sair” ao terminar em um aparelho compartilhado.',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        style: _secondaryButtonStyle,
                        onPressed: _busy
                            ? null
                            : () => Navigator.pushNamedAndRemoveUntil(
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
            ),
          ),
        ),
      ),
    ),
  );
}

class _ResetDialog extends StatefulWidget {
  final String initialEmail;
  const _ResetDialog({required this.initialEmail});
  @override
  State<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<_ResetDialog> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Recuperar acesso'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'E-mail'),
        validator: validateEmailRoyalClean,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _email.text.trim());
          }
        },
        child: const Text('Enviar instruções'),
      ),
    ],
  );
}
