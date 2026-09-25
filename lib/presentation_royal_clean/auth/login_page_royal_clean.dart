import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../shared/header_actions_royal_clean.dart';
import 'package:flutter/services.dart';
import '../../core_royal_clean/services/account_service_royal_clean.dart';
import '../../core_royal_clean/services/session_preferences_royal_clean.dart';
import '../../core_royal_clean/services/biometric_access_royal_clean.dart';
import '../../core_royal_clean/services/remembered_login_royal_clean.dart';
import 'auth_background_royal_clean.dart';
import 'account_ui_royal_clean.dart';

class LoginPageRoyalClean extends StatefulWidget {
  final Future<void>? firebaseInitialization;
  final SessionPreferencesRoyalClean? sessionPreferences;
  final BiometricAccessRoyalClean? biometricAccess;
  final RememberedLoginRoyalClean? rememberedLogin;
  final Future<void> Function(String email, String password)? passwordSignIn;
  const LoginPageRoyalClean({
    super.key,
    this.firebaseInitialization,
    this.sessionPreferences,
    this.biometricAccess,
    this.rememberedLogin,
    this.passwordSignIn,
  });
  @override
  State<LoginPageRoyalClean> createState() => _LoginState();
}

class _LoginState extends State<LoginPageRoyalClean> {
  static final _secondaryButtonStyle = TextButton.styleFrom(
    foregroundColor: Colors.white,
    disabledForegroundColor: Colors.white38,
  );
  static final _socialButtonStyle = TextButton.styleFrom(
    foregroundColor: Colors.white,
    disabledForegroundColor: Colors.white38,
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
  );
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = true, _obscure = true, _remember = true;
  late final _preferences =
      widget.sessionPreferences ?? SessionPreferencesRoyalClean.instance;
  late final _biometric =
      widget.biometricAccess ?? BiometricAccessRoyalClean.instance;
  late final _rememberedLogin =
      widget.rememberedLogin ?? RememberedLoginRoyalClean.instance;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _offerBiometric() async {
    // Never make an optional device feature a condition for a valid login.
    try {
      if (_biometric.enabled ||
          !await _biometric.checkAvailable() ||
          !mounted) {
        return;
      }
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.fingerprint, size: 40),
          title: const Text('Proteger acesso neste aparelho?'),
          content: const Text(
            'Ao fechar e reabrir o aplicativo, confirme sua digital ou use o PIN, padrão ou senha do aparelho para acessar o perfil. Apenas alternar entre aplicativos não bloqueia o acesso. Ative somente no seu aparelho pessoal.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Agora não'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ativar'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
      final enabled = await _biometric.enable(confirmDevice: false);
      if (mounted) {
        showAccountMessageRoyalClean(
          context,
          enabled
              ? 'Proteção ativada para a próxima abertura do aplicativo.'
              : 'Proteção não ativada. Seu login continua normalmente.',
        );
      }
    } catch (_) {
      if (mounted) {
        showAccountMessageRoyalClean(
          context,
          'Não foi possível ativar a biometria. Seu login continua normalmente.',
        );
      }
    }
  }

  Future<void> _loadPreference() async {
    var remember = false;
    try {
      remember = await _preferences.read();
    } catch (_) {
      // Fail closed; login also requires a successful preference write.
    }
    if (remember) {
      try {
        final email = await _rememberedLogin.read();
        if (mounted && _email.text.isEmpty && email != null) {
          _email.text = email;
        }
      } catch (_) {
        // A saved email is optional; storage failure must not block normal login.
      }
    }
    if (mounted) {
      setState(() {
        _remember = remember;
        _busy = false;
      });
    }
  }

  Future<void> _changeRemember(bool value) async {
    setState(() => _busy = true);
    try {
      await _preferences.save(value);
      if (!value) {
        TextInput.finishAutofillContext(shouldSave: false);
        try {
          await _rememberedLogin.write(null);
        } catch (_) {
          // The disabled preference also prevents loading any remembered email.
        }
      }
      if (mounted) setState(() => _remember = value);
    } catch (_) {
      if (mounted) {
        showAccountMessageRoyalClean(
          context,
          'Não foi possível salvar a preferência. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _authenticate(
    Future<void> Function() action, {
    bool passwordLogin = false,
  }) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await widget.firebaseInitialization?.timeout(const Duration(seconds: 15));
      // Persist the choice before authentication, including Google and Apple.
      await _preferences.save(_remember);
      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(
          _remember ? Persistence.LOCAL : Persistence.NONE,
        );
      }
      await action();
      _biometric.credentialsAccepted();
      try {
        await _rememberedLogin.write(
          _remember
              ? (passwordLogin
                    ? _email.text.trim()
                    : FirebaseAuth.instance.currentUser?.email)
              : null,
        );
      } catch (_) {
        if (mounted) {
          showAccountMessageRoyalClean(
            context,
            'Login realizado. Não foi possível lembrar o e-mail neste dispositivo.',
          );
        }
      }
      if (!mounted) return;
      await _offerBiometric();
      // Request saving only valid credentials, after the consent dialog closes.
      TextInput.finishAutofillContext(shouldSave: _remember && passwordLogin);
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
    appBar: AppBar(actions: const [HeaderActionsRoyalClean(showMyData: false)]),
    body: AuthBackgroundRoyalClean(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
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
                        autofillHints: _remember
                            ? const [
                                AutofillHints.username,
                                AutofillHints.email,
                              ]
                            : null,
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
                        autofillHints: _remember
                            ? const [AutofillHints.password]
                            : null,
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
                                    if (widget.passwordSignIn != null) {
                                      await widget.passwordSignIn!(
                                        _email.text.trim(),
                                        _password.text,
                                      );
                                    } else {
                                      await FirebaseAuth.instance
                                          .signInWithEmailAndPassword(
                                            email: _email.text.trim(),
                                            password: _password.text,
                                          );
                                    }
                                  }, passwordLogin: true);
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
                                style: _socialButtonStyle,
                                onPressed: _busy
                                    ? null
                                    : () => _authenticate(
                                        AccountServiceRoyalClean.apple,
                                      ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.apple, size: 22),
                                    SizedBox(width: 4),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Continuar com Apple',
                                          maxLines: 1,
                                          softWrap: false,
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
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
                                style: _socialButtonStyle,
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
                                    const SizedBox(width: 4),
                                    const Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          'Continuar com Google',
                                          maxLines: 1,
                                          softWrap: false,
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _remember,
                        onChanged: _busy
                            ? null
                            : (value) => _changeRemember(value ?? false),
                        title: const Text(
                          'Manter conectado',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _remember
                            ? 'Sua sessão e seu e-mail serão lembrados neste dispositivo. A senha pode ser salva pelo gerenciador do aparelho.'
                            : 'Ao reiniciar o aplicativo, entre novamente. O preenchimento automático não será solicitado.',
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
