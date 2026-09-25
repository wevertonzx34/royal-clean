import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/intercom_royal_clean.dart';
import '../auth/account_ui_royal_clean.dart';

class IntercomPageRoyalClean extends StatefulWidget {
  const IntercomPageRoyalClean({super.key});
  @override
  State<IntercomPageRoyalClean> createState() => _IntercomPageState();
}

class _IntercomPageState extends State<IntercomPageRoyalClean> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) => AccountLayoutRoyalClean(
    title: 'Interfone',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Comunique novidades e avisos da Royal Clean. As publicações aparecem no mundinho para todos, inclusive visitantes.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text('Nova publicação'),
          onPressed: () => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const _PublishDialog(),
          ),
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in [
                'Publicadas',
                'Vencidas',
                'Avaliadas',
              ].asMap().entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: _tab == entry.key,
                    onSelected: (_) => setState(() => _tab = entry.key),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Histórico das 200 publicações mais recentes. Avaliadas são notificações revisadas pelo usuário.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 16),
        if (_tab == 2)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.rate_review_outlined),
                  SizedBox(height: 12),
                  Text(
                    'Avaliações dos usuários',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Espaço reservado para as notificações revisadas pelos usuários. Os tópicos e a forma de avaliação serão definidos em uma próxima etapa.',
                  ),
                  SizedBox(height: 8),
                  Text('Marcar uma notificação como lida não é uma avaliação.'),
                ],
              ),
            ),
          )
        else
          ListenableBuilder(
            listenable: IntercomRoyalClean.instance,
            builder: (context, _) {
              final feed = IntercomRoyalClean.instance;
              if (feed.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = feed.messages
                  .where(
                    (message) =>
                        message.activeAt(DateTime.now()) == (_tab == 0),
                  )
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (feed.error != null) ...[
                    Text(feed.error!),
                    TextButton(
                      onPressed: feed.reload,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                  if (messages.isEmpty && feed.error == null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Nenhuma publicação nesta guia.'),
                    ),
                  for (final message in messages)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              message.kind.toUpperCase(),
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              message.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            SelectableText(message.body),
                            const SizedBox(height: 12),
                            Text(
                              'Publicada: ${intercomDateRoyalClean(message.publishedAt)}\nValidade: ${intercomDateRoyalClean(message.expiresAt)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    ),
  );
}

class _PublishDialog extends StatefulWidget {
  const _PublishDialog();
  @override
  State<_PublishDialog> createState() => _PublishDialogState();
}

class _PublishDialogState extends State<_PublishDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(), _body = TextEditingController();
  late final _id = FirebaseFirestore.instance
      .collection('intercom_messages')
      .doc()
      .id;
  String _kind = 'Mensagem';
  int _days = 7;
  bool _busy = false;
  String? _error;
  Future<void> _publish() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await IntercomRoyalClean.publish(
        id: _id,
        title: _title.text,
        body: _body.text,
        kind: _kind,
        expiresAt: DateTime.now().add(Duration(days: _days)),
      );
      if (mounted) {
        showAccountMessageRoyalClean(
          context,
          'Publicação confirmada. A mensagem já está disponível no mundinho.',
        );
        Navigator.pop(context);
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => _error =
              failure is FirebaseException &&
                  failure.code == 'permission-denied'
              ? 'Publicação não autorizada. Verifique o acesso de admin e publique as regras atualizadas do Interfone no Firebase.'
              : 'Não foi possível confirmar a publicação. Verifique a conexão e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Nova publicação'),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Conteúdo público. Não inclua dados pessoais ou informações internas.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: ['Notificação', 'Alerta', 'Mensagem']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _kind = value!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                enabled: !_busy,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Informe um título com pelo menos 3 caracteres.'
                    : null,
              ),
              TextFormField(
                controller: _body,
                enabled: !_busy,
                maxLength: 2000,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Mensagem'),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? 'Escreva a mensagem.'
                    : null,
              ),
              DropdownButtonFormField<int>(
                initialValue: _days,
                decoration: const InputDecoration(labelText: 'Validade'),
                items: [1, 7, 30]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value ${value == 1 ? 'dia' : 'dias'}'),
                      ),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _days = value!),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _publish,
          child: Text(_busy ? 'Publicando…' : 'Publicar'),
        ),
      ],
    ),
  );
}
