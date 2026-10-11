import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../shared/layout_button_royal_clean.dart';
import '../../core_royal_clean/services/account_access_royal_clean.dart';

class RoyalPriceBenefitPageRoyalClean extends StatefulWidget {
  const RoyalPriceBenefitPageRoyalClean({super.key});
  @override
  State<RoyalPriceBenefitPageRoyalClean> createState() => _BenefitState();
}

class _BenefitState extends State<RoyalPriceBenefitPageRoyalClean> {
  final _code = TextEditingController(),
      _target = TextEditingController(),
      _activation = TextEditingController(text: '30'),
      _duration = TextEditingController(text: '90');
  bool _busy = false, _directed = false;
  String? _message;
  List<Map> _invites = [];
  bool get _admin =>
      AccountAccessRoyalClean.instance.value.status ==
      AccountAccessStatus.admin;
  Widget _button(String id, Widget child) =>
      LayoutButtonRoyalClean(id: 'price.benefit.$id', child: child);
  @override
  void initState() {
    super.initState();
    _run({'action': 'status'});
  }

  @override
  void dispose() {
    for (final c in [_code, _target, _activation, _duration]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Map<String, dynamic> input) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      ).httpsCallable('royalPriceBenefit').call(input);
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      setState(() {
        if (input['action'] == 'list') {
          _invites = (data['items'] as List).cast<Map>();
        } else if (data['code'] != null) {
          _message =
              'Convite criado: ${data['code']}\nCopie e entregue ao convidado. O código só é exibido nesta criação.\nPrazo para ativar: ${data['activateUntil']}';
        } else if (input['action'] == 'revoke') {
          _message = 'Benefício revogado.';
        } else {
          _message = data['active'] == true
              ? 'Benefício PJ ativo até ${data['until']}'
              : 'Você não possui benefício PJ ativo.';
        }
      });
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _message = e.message ?? 'Não foi possível concluir.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Verifique a conexão e tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: const Color(0xFF071F2B),
      foregroundColor: Colors.white,
      title: const Text('Convites · Preço PJ'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SelectableText(_message!),
          ),
        const Text(
          'Ativar um convite',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        TextField(
          controller: _code,
          decoration: const InputDecoration(
            labelText: 'Código recebido',
            border: OutlineInputBorder(),
          ),
        ),
        _button(
          'redeem',
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run({'action': 'redeem', 'code': _code.text}),
            child: const Text('Ativar benefício'),
          ),
        ),
        if (_admin) ...[
          const Divider(height: 40),
          const Text(
            'Criar convite',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          _button(
            'directed',
            SwitchListTile(
              value: _directed,
              onChanged: _busy ? null : (v) => setState(() => _directed = v),
              title: const Text('Somente para um perfil específico'),
            ),
          ),
          if (_directed)
            TextField(
              controller: _target,
              decoration: const InputDecoration(
                labelText: 'ID do perfil convidado',
              ),
            ),
          TextField(
            controller: _activation,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Dias para ativar · 1 a 365',
            ),
          ),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Dias de benefício após ativar · 1 a 365',
            ),
          ),
          const Text(
            'Convite livre pode ser doado ou vendido antes da ativação. Cada código só pode ser ativado uma vez.',
          ),
          _button(
            'create',
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run({
                      'action': 'create',
                      'activateDays': int.tryParse(_activation.text),
                      'benefitDays': int.tryParse(_duration.text),
                      'targetUid': _directed ? _target.text.trim() : null,
                    }),
              child: const Text('Criar convite'),
            ),
          ),
          _button(
            'list',
            OutlinedButton(
              onPressed: _busy ? null : () => _run({'action': 'list'}),
              child: const Text('Consultar convites e revogar'),
            ),
          ),
          for (final invite in _invites)
            Card(
              child: ListTile(
                title: Text(
                  invite['targetUid'] == null
                      ? 'Convite livre'
                      : 'Perfil: ${invite['targetUid']}',
                ),
                subtitle: Text(
                  '${invite['revoked'] == true
                      ? 'Revogado'
                      : invite['usedBy'] != null
                      ? 'Ativado por ${invite['usedBy']}'
                      : 'Aguardando ativação'}\nValidade: ${invite['activateUntil']}',
                ),
                trailing: invite['revoked'] == true
                    ? null
                    : _button(
                        'revoke.${invite['id']}',
                        IconButton(
                          tooltip: 'Revogar convite',
                          icon: const Icon(Icons.block),
                          onPressed: _busy
                              ? null
                              : () async {
                                  final yes = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text(
                                        'Revogar este convite e seu benefício?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Revogar'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (yes == true) {
                                    await _run({
                                      'action': 'revoke',
                                      'id': invite['id'],
                                    });
                                    await _run({'action': 'list'});
                                  }
                                },
                        ),
                      ),
              ),
            ),
        ],
      ],
    ),
  );
}
