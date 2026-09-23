import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/account_service_royal_clean.dart';
import '../auth/account_gate_royal_clean.dart';
import '../auth/account_ui_royal_clean.dart';

class UserManagementPageRoyalClean extends StatefulWidget {
  const UserManagementPageRoyalClean({super.key});
  @override
  State<UserManagementPageRoyalClean> createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagementPageRoyalClean> {
  final _search = TextEditingController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _users = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _last;
  bool _busy = false, _more = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      if (reset) {
        _users = [];
        _last = null;
      }
    });
    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
        'users',
      );
      final email = _search.text.trim();
      if (email.isNotEmpty) query = query.where('email', isEqualTo: email);
      query = query.orderBy(FieldPath.documentId).limit(25);
      if (_last != null) query = query.startAfterDocument(_last!);
      final page = await query.get(const GetOptions(source: Source.server));
      if (!mounted) return;
      setState(() {
        _users.addAll(page.docs);
        _more = page.docs.length == 25;
        if (page.docs.isNotEmpty) _last = page.docs.last;
      });
    } catch (e) {
      if (mounted) setState(() => _error = AccountServiceRoyalClean.error(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    var role = data['role'] as String? ?? 'consumer';
    if (!roleLabelsRoyalClean.containsKey(role)) role = 'consumer';
    var active = data['active'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Definir acesso'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${data['name']}\n${data['email']}'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  isExpanded: true,
                  items: roleLabelsRoyalClean.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => update(() => role = v ?? role),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Acesso ativo'),
                  value: active,
                  onChanged: (v) => update(() => active = v),
                ),
                const Text(
                  'O convite é apenas uma referência. Confirme a identidade e o vínculo antes de conceder outro perfil.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar acesso'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await AccountServiceRoyalClean.call('setUserRole', {
        'uid': doc.id,
        'role': role,
        'active': active,
      });
      if (mounted) showAccountMessageRoyalClean(context, 'Acesso atualizado.');
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
    if (mounted) await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) => AccountLayoutRoyalClean(
    title: 'Usuários e perfis',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Novos cadastros começam como consumidores. Apenas um administrador ativo pode alterar o perfil. Documentos pessoais não aparecem nesta lista.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Buscar pelo e-mail completo',
          ),
        ),
        TextButton(
          onPressed: _busy ? null : () => _load(reset: true),
          child: const Text('Buscar / atualizar'),
        ),
        if (_error != null) Text(_error!),
        for (final doc in _users)
          Card(
            child: ListTile(
              title: Text(doc.data()['name'] as String? ?? ''),
              subtitle: Text(
                '${doc.data()['email']}\n${roleLabelsRoyalClean[doc.data()['role']] ?? 'Perfil desconhecido'} • ${doc.data()['active'] == true ? 'Ativo' : 'Inativo'}'
                '${doc.data()['referral'] is Map ? '\nConvite: ${(doc.data()['referral'] as Map)['code']} • referência: ${(doc.data()['referral'] as Map)['profileReference']}' : ''}',
              ),
              trailing: IconButton(
                tooltip: 'Definir acesso',
                onPressed: _busy ? null : () => _edit(doc),
                icon: const Icon(Icons.manage_accounts),
              ),
            ),
          ),
        if (_users.isEmpty && !_busy && _error == null)
          const Text('Nenhum cadastro encontrado.'),
        if (_busy) const Center(child: CircularProgressIndicator()),
        if (_more && !_busy && _users.isNotEmpty)
          TextButton(onPressed: _load, child: const Text('Carregar mais')),
      ],
    ),
  );
}
