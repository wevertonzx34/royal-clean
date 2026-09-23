import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/account_service_royal_clean.dart';
import 'account_ui_royal_clean.dart';

class MyDataPageRoyalClean extends StatefulWidget {
  final User user;
  final Map<String, dynamic> profile;
  const MyDataPageRoyalClean({
    super.key,
    required this.user,
    required this.profile,
  });
  @override
  State<MyDataPageRoyalClean> createState() => _MyDataState();
}

class _MyDataState extends State<MyDataPageRoyalClean> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _document = TextEditingController();
  String _kind = '';
  bool _offers = false, _busy = true;
  String? _error;
  bool _loaded = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .doc('personal_data/${widget.user.uid}')
          .get(const GetOptions(source: Source.server));
      if (!mounted) return;
      final data = snapshot.data() ?? {};
      _name.text =
          widget.profile['name'] as String? ??
          data['name'] as String? ??
          widget.user.displayName ??
          '';
      _document.text = data['document'] as String? ?? '';
      _kind = data['documentKind'] as String? ?? '';
      if (!['', 'cpf', 'cnpj'].contains(_kind)) _kind = '';
      _offers =
          widget.profile['offers'] == true ||
          (widget.profile.isEmpty && data['offers'] == true);
      _loaded = true;
    } catch (e) {
      _error = AccountServiceRoyalClean.error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _document.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AccountServiceRoyalClean.call('updateMyData', {
        'name': _name.text,
        'offers': _offers,
        'documentKind': _kind,
        'document': _kind.isEmpty ? '' : _document.text,
      });
      if (mounted) showAccountMessageRoyalClean(context, 'Dados atualizados.');
    } catch (e) {
      if (mounted) setState(() => _error = AccountServiceRoyalClean.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountLayoutRoyalClean(
    title: 'Meus dados',
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('E-mail: ${widget.user.email ?? ''}'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            enabled: !_busy && _loaded,
            decoration: const InputDecoration(labelText: 'Nome'),
            validator: validateNameRoyalClean,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _kind,
            key: ValueKey(_kind),
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Documento (opcional)',
            ),
            items: const [
              DropdownMenuItem(
                value: '',
                child: Text('Não informar / remover'),
              ),
              DropdownMenuItem(value: 'cpf', child: Text('CPF')),
              DropdownMenuItem(value: 'cnpj', child: Text('CNPJ')),
            ],
            onChanged: _busy || !_loaded
                ? null
                : (v) => setState(() {
                    _kind = v ?? '';
                    _document.clear();
                  }),
          ),
          if (_kind.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _document,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              keyboardType: _kind == 'cpf'
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(labelText: _kind.toUpperCase()),
              validator: (v) => (v?.trim().isEmpty ?? true)
                  ? 'Informe o documento ou selecione “Não informar”.'
                  : null,
            ),
            const SizedBox(height: 8),
            const Text(
              'Conferimos formato e dígitos no servidor. Isso não comprova titularidade ou situação fiscal.',
            ),
          ],
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _offers,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: _busy || !_loaded
                ? null
                : (v) => setState(() => _offers = v ?? false),
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
            onPressed: _busy || !_loaded ? null : _save,
            child: Text(_busy ? 'Aguarde…' : 'Salvar dados'),
          ),
          if (!_loaded && !_busy)
            TextButton(
              onPressed: () {
                setState(() {
                  _busy = true;
                  _error = null;
                });
                _load();
              },
              child: const Text('Tentar carregar novamente'),
            ),
          const SizedBox(height: 16),
          const Text(
            'Convites só podem ser informados no cadastro inicial. Seu perfil de acesso é administrado pela Royal Clean.',
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const LegalPageRoyalClean(privacy: true),
              ),
            ),
            child: const Text('Aviso de privacidade'),
          ),
        ],
      ),
    ),
  );
}
