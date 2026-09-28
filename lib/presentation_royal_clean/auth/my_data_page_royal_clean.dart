import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/account_service_royal_clean.dart';
import '../../core_royal_clean/services/touch_feedback_royal_clean.dart';
import 'account_ui_royal_clean.dart';
import 'phone_verification_royal_clean.dart';
import 'profile_media_royal_clean.dart';

class MyDataPageRoyalClean extends StatefulWidget {
  final User user;
  final Map<String, dynamic> profile;
  final bool isAdmin;
  final Future<Map<String, dynamic>> Function()? loadData;
  final Future<void> Function(Map<String, dynamic>)? saveData;
  const MyDataPageRoyalClean({
    super.key,
    required this.user,
    required this.profile,
    this.isAdmin = false,
    this.loadData,
    this.saveData,
  });
  @override
  State<MyDataPageRoyalClean> createState() => _MyDataState();
}

class _MyDataState extends State<MyDataPageRoyalClean> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{
    for (final key in [
      'name',
      'cpf',
      'cnpj',
      'companyLegalName',
      'tradeName',
      'description',
      'phone',
      'postalCode',
      'address',
      'addressNumber',
      'complement',
      'district',
      'city',
      'state',
    ])
      key: TextEditingController(),
  };
  String _personType = 'individual', _photo = '', _logo = '';
  bool _offers = false, _busy = true, _loaded = false;
  String? _error;
  String? _verifiedPhone;
  bool _mediaBusy = false;
  bool get _enabled => !_busy && _loaded && !_mediaBusy;
  @override
  void initState() {
    super.initState();
    _verifiedPhone = widget.user.phoneNumber;
    _load();
  }

  Future<void> _load() async {
    try {
      final data = widget.loadData != null
          ? await widget.loadData!()
          : (await FirebaseFirestore.instance
                        .doc('personal_data/${widget.user.uid}')
                        .get(const GetOptions(source: Source.server)))
                    .data() ??
                <String, dynamic>{};
      if (!mounted) return;
      for (final entry in _fields.entries) {
        entry.value.text = data[entry.key] as String? ?? '';
      }
      _fields['name']!.text =
          data['name'] as String? ??
          widget.profile['name'] as String? ??
          widget.user.displayName ??
          '';
      if (data['documentKind'] == 'cpf' && _fields['cpf']!.text.isEmpty) {
        _fields['cpf']!.text = data['document'] as String? ?? '';
      }
      if (data['documentKind'] == 'cnpj' && _fields['cnpj']!.text.isEmpty) {
        _fields['cnpj']!.text = data['document'] as String? ?? '';
      }
      _personType =
          data['personType'] == 'company' ||
              (data['personType'] == null && data['documentKind'] == 'cnpj')
          ? 'company'
          : 'individual';
      _photo = data['photoPath'] as String? ?? '';
      _logo = data['logoPath'] as String? ?? '';
      _offers =
          data['offers'] == true ||
          (data['offers'] == null && widget.profile['offers'] == true);
      _loaded = true;
    } catch (e) {
      _error = AccountServiceRoyalClean.error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final input = <String, dynamic>{
        for (final entry in _fields.entries) entry.key: entry.value.text,
        'offers': _offers,
        'personType': _personType,
        'photoPath': _photo,
        'logoPath': _logo,
      };
      if (widget.saveData != null) {
        await widget.saveData!(input);
      } else {
        await AccountServiceRoyalClean.call('updateMyData', input);
      }
      if (mounted) showAccountMessageRoyalClean(context, 'Dados atualizados.');
    } catch (e) {
      if (mounted) setState(() => _error = AccountServiceRoyalClean.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyPhone() async {
    final phone = profilePhoneRoyalClean(_fields['phone']!.text);
    if (phone == null) {
      setState(() => _error = 'Informe um telefone brasileiro com DDD.');
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PhoneVerificationRoyalClean(user: widget.user, phone: phone),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      setState(
        () => _verifiedPhone = FirebaseAuth.instance.currentUser?.phoneNumber,
      );
      showAccountMessageRoyalClean(
        context,
        'Telefone confirmado. Salve os dados para atualizar o cadastro.',
      );
    }
  }

  Widget _field(
    String key,
    String label, {
    int max = 160,
    int lines = 1,
    TextInputType? keyboard,
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: _fields[key],
      enabled: _enabled,
      maxLength: max,
      maxLines: lines,
      keyboardType: keyboard,
      onTap: TouchFeedbackRoyalClean.pulse,
      onChanged: key == 'phone' ? (_) => setState(() {}) : null,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: key == 'name'
          ? validateNameRoyalClean
          : (value) => required && (value?.trim().isEmpty ?? true)
                ? 'Preencha este campo.'
                : null,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final phone = profilePhoneRoyalClean(_fields['phone']!.text);
    final verified = phone != null && phone == _verifiedPhone;
    return AccountLayoutRoyalClean(
      title: 'Meus dados',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.isAdmin ? 'Admin autenticado:' : 'E-mail verificado'),
            SelectableText(widget.user.email ?? ''),
            const SizedBox(height: 20),
            _field('name', 'Nome completo'),
            DropdownButtonFormField<String>(
              key: ValueKey(_personType),
              initialValue: _personType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo de pessoa'),
              items: const [
                DropdownMenuItem(
                  value: 'individual',
                  child: Text('Pessoa física'),
                ),
                DropdownMenuItem(
                  value: 'company',
                  child: Text('Pessoa jurídica'),
                ),
              ],
              onChanged: tactileValueRoyalClean(
                _enabled
                    ? (value) => setState(() => _personType = value!)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Completar o cadastro não altera suas permissões de acesso. Os dados desta página são privados.',
            ),
            const SizedBox(height: 16),
            ProfileMediaRoyalClean(
              uid: widget.user.uid,
              kind: 'photo',
              path: _photo,
              enabled: _enabled,
              onChanged: (value) => setState(() => _photo = value),
              onBusyChanged: (value) => setState(() => _mediaBusy = value),
            ),
            const SizedBox(height: 16),
            _field(
              'cpf',
              'CPF (opcional)',
              max: 14,
              keyboard: TextInputType.number,
            ),
            if (_personType == 'company') ...[
              _field('cnpj', 'CNPJ', max: 18, required: true),
              _field('companyLegalName', 'Razão social', required: true),
              _field('tradeName', 'Nome fantasia (opcional)'),
              ProfileMediaRoyalClean(
                uid: widget.user.uid,
                kind: 'logo',
                path: _logo,
                enabled: _enabled,
                onChanged: (value) => setState(() => _logo = value),
                onBusyChanged: (value) => setState(() => _mediaBusy = value),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'CPF e CNPJ são conferidos por formato e dígitos verificadores. Isso não comprova titularidade ou situação fiscal.',
            ),
            const SizedBox(height: 16),
            _field(
              'phone',
              'Telefone com DDD (opcional)',
              max: 30,
              keyboard: TextInputType.phone,
            ),
            OutlinedButton.icon(
              onPressed: tactileTapRoyalClean(
                _enabled && !verified ? _verifyPhone : null,
              ),
              icon: Icon(verified ? Icons.verified : Icons.sms_outlined),
              label: Text(
                verified ? 'Telefone confirmado' : 'Confirmar telefone por SMS',
              ),
            ),
            const SizedBox(height: 16),
            _field(
              'description',
              'Descrição pessoal (opcional)',
              max: 1000,
              lines: 3,
              keyboard: TextInputType.multiline,
            ),
            ExpansionTile(
              title: const Text('Endereço (opcional)'),
              children: [
                _field(
                  'postalCode',
                  'CEP',
                  max: 10,
                  keyboard: TextInputType.number,
                ),
                _field('address', 'Logradouro', max: 180),
                _field('addressNumber', 'Número', max: 20),
                _field('complement', 'Complemento', max: 100),
                _field('district', 'Bairro', max: 100),
                _field('city', 'Cidade', max: 100),
                _field('state', 'UF', max: 2),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _offers,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: tactileValueRoyalClean(
                _enabled
                    ? (value) => setState(() => _offers = value ?? false)
                    : null,
              ),
              title: const Text('Receber ofertas (opcional)'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: tactileTapRoyalClean(_enabled ? _save : null),
              child: Text(_busy ? 'Aguarde…' : 'Salvar dados'),
            ),
            if (!_loaded && !_busy)
              TextButton(
                onPressed: tactileTapRoyalClean(() {
                  setState(() {
                    _busy = true;
                    _error = null;
                  });
                  _load();
                }),
                child: const Text('Tentar carregar novamente'),
              ),
            const SizedBox(height: 16),
            const Text(
              'Consumidores não precisam de convite. Outros perfis dependem de autorização da Royal Clean.',
            ),
            TextButton(
              onPressed: tactileTapRoyalClean(
                () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalPageRoyalClean(privacy: true),
                  ),
                ),
              ),
              child: const Text('Aviso de privacidade'),
            ),
          ],
        ),
      ),
    );
  }
}
