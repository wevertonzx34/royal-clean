import 'package:flutter/material.dart';
import '../../shared/header_actions_royal_clean.dart';

class InviteStatusDetailsPageRoyalClean extends StatelessWidget {
  final Map<String, dynamic> inviteMap;

  const InviteStatusDetailsPageRoyalClean({super.key, required this.inviteMap});

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF90E0EF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _stringValue(String key) {
    final value = inviteMap[key];
    if (value == null) return '-';
    final text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do convite'),
        actions: const [HeaderActionsRoyalClean()],
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xB8062B3D),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF155A78)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Detalhes completos',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 18),
                    _row(context, 'Nome', _stringValue('fullName')),
                    _row(context, 'E-mail', _stringValue('email')),
                    _row(context, 'Perfil', _stringValue('profile')),
                    if (_stringValue('collaboratorFunction') != '-')
                      _row(
                        context,
                        'Função',
                        _stringValue('collaboratorFunction'),
                      ),
                    _row(context, 'Código', _stringValue('inviteCode')),
                    _row(context, 'WhatsApp', _stringValue('whatsapp')),
                    _row(context, 'Status', _stringValue('status')),
                    _row(context, 'Usado', _stringValue('isUsed')),
                    _row(
                      context,
                      'Cadastro ativo',
                      _stringValue('registrationEnabled'),
                    ),
                    _row(context, 'Criado em', _stringValue('createdAt')),
                    _row(context, 'Usado em', _stringValue('usedAt')),
                    _row(context, 'Usado por UID', _stringValue('usedByUid')),
                    _row(context, 'Invite ID', _stringValue('inviteId')),
                    _row(
                      context,
                      'Criado por UID',
                      _stringValue('createdByUid'),
                    ),
                    _row(
                      context,
                      'Criado por e-mail',
                      _stringValue('createdByEmail'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
