import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/account_service_royal_clean.dart';
import 'account_ui_royal_clean.dart';

class RegistrationPageRoyalClean extends StatefulWidget {
  final Future<void>? firebaseInitialization;
  final User? user;
  const RegistrationPageRoyalClean({
    super.key,
    this.firebaseInitialization,
    this.user,
  });
  @override
  State<RegistrationPageRoyalClean> createState() => _RegistrationState();
}

class _RegistrationState extends State<RegistrationPageRoyalClean> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _confirmEmail = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _invite = TextEditingController();
  bool _terms = false, _offers = false, _busy = false, _obscure = true;
  User? _user;
  String? _error;
  DateTime? _lastSent;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _name.text = _user?.displayName ?? '';
    _email.text = _user?.email ?? '';
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _confirmEmail,
      _password,
      _confirmPassword,
      _invite,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _sendVerification() async {
    if (_busy) return;
    if (_lastSent != null &&
        DateTime.now().difference(_lastSent!).inSeconds < 60) {
      showAccountMessageRoyalClean(
        context,
        'Aguarde um minuto antes de reenviar.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _user!.sendEmailVerification();
      _lastSent = DateTime.now();
      if (mounted) {
        showAccountMessageRoyalClean(
          context,
          'Enviamos o link. Confira também a pasta de spam.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = AccountServiceRoyalClean.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    if (!_terms) {
      setState(
        () => _error = 'Leia os documentos e aceite os termos para continuar.',
      );
      return;
    }
    final registrationData = <String, dynamic>{
      'name': _name.text.trim(),
      'inviteCode': _invite.text.trim().toUpperCase(),
      'acceptTerms': _terms,
      'legalVersion': legalVersionRoyalClean,
      'offers': _offers,
    };
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.firebaseInitialization?.timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (_user == null) {
        final result = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _email.text.trim(),
              password: _password.text,
            );
        if (!mounted) return;
        _user = result.user!;
        _password.clear();
        _confirmPassword.clear();
        // No invite is consumed until the owner verifies their e-mail.
        await _user!.sendEmailVerification();
        _lastSent = DateTime.now();
      }
      if (!mounted) return;
      final expectedUid = _user!.uid;
      await _user!.reload();
      _user = FirebaseAuth.instance.currentUser;
      if (!mounted) return;
      if (_user == null || _user!.uid != expectedUid) {
        throw StateError('Sessão encerrada');
      }
      if (!_user!.emailVerified) {
        if (mounted) {
          setState(
            () => _error =
                'Abra o link recebido no e-mail e toque em “Já verifiquei, concluir cadastro”.',
          );
        }
        return;
      }
      await _user!.getIdToken(true);
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != expectedUid) {
        return;
      }
      await AccountServiceRoyalClean.call('registerAccount', registrationData);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/account',
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = AccountServiceRoyalClean.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    bool password = false,
    bool email = false,
    List<String>? autofillHints,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      validator: validator,
      obscureText: password && _obscure,
      autocorrect: !password && !email,
      enableSuggestions: !password,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
      textCapitalization: email || password
          ? TextCapitalization.none
          : TextCapitalization.words,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: password
            ? IconButton(
                tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              )
            : null,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AccountLayoutRoyalClean(
    title: _user == null ? 'Novo usuário' : 'Concluir cadastro',
    child: AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bem-vindo à Royal Clean',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Crie sua conta com poucos dados. CPF ou CNPJ podem ser adicionados depois, em Meus dados.',
            ),
            const SizedBox(height: 24),
            _field(
              _name,
              'Nome',
              validator: validateNameRoyalClean,
              autofillHints: const [AutofillHints.name],
            ),
            if (_user == null) ...[
              _field(
                _email,
                'E-mail',
                email: true,
                validator: validateEmailRoyalClean,
                autofillHints: const [AutofillHints.email],
              ),
              _field(
                _confirmEmail,
                'Confirmar e-mail',
                email: true,
                validator: (v) =>
                    v?.trim().toLowerCase() == _email.text.trim().toLowerCase()
                    ? null
                    : 'Os e-mails não conferem.',
              ),
              _field(
                _password,
                'Senha',
                password: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) =>
                    (v?.length ?? 0) >= 15 && (v?.length ?? 0) <= 128
                    ? null
                    : 'Use entre 15 e 128 caracteres.',
              ),
              _field(
                _confirmPassword,
                'Confirmar senha',
                password: true,
                validator: (v) =>
                    v == _password.text ? null : 'As senhas não conferem.',
              ),
              const Text(
                'Use uma senha longa e exclusiva. Você pode colar uma senha do seu gerenciador.',
              ),
            ] else ...[
              Text('Conta: ${_user!.email ?? ''}'),
              if (!_user!.emailVerified) ...[
                const SizedBox(height: 12),
                const Text(
                  'Verifique seu e-mail antes de concluir. O convite ainda não foi utilizado.',
                ),
                TextButton(
                  onPressed: _busy ? null : _sendVerification,
                  child: const Text('Reenviar verificação de e-mail'),
                ),
              ],
            ],
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Tem um código de convite?'),
              subtitle: const Text('Opcional • somente no cadastro inicial'),
              children: [
                const Text(
                  'Adicione para identificar a origem do seu cadastro. O código não concede benefícios ou permissões e não poderá ser incluído depois.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _invite,
                  enabled: !_busy,
                  maxLength: 8,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Código de convite',
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _invite.clear();
                          _error = null;
                        }),
                  child: const Text(
                    'Remover código e continuar com conta comum',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const LegalPageRoyalClean(privacy: false),
                    ),
                  ),
                  child: const Text('Ler Termos de Uso'),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const LegalPageRoyalClean(privacy: true),
                    ),
                  ),
                  child: const Text('Ler Aviso de Privacidade'),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _terms,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _terms = v ?? false),
              title: const Text(
                'Aceito os Termos de Uso e li o Aviso de Privacidade.',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _offers,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _offers = v ?? false),
              title: const Text(
                'Quero receber ofertas da Royal Clean (opcional).',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(
                _busy
                    ? 'Aguarde…'
                    : _user != null && !_user!.emailVerified
                    ? 'Já verifiquei, concluir cadastro'
                    : 'Concluir cadastro',
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      if (_user != null) await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => route.isFirst,
                        );
                      }
                    },
              child: const Text('Já tenho conta / voltar ao login'),
            ),
          ],
        ),
      ),
    ),
  );
}
