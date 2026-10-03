import 'package:royal_clean/presentation_royal_clean/shared/layout_button_royal_clean.dart';
import 'package:royal_clean/core_royal_clean/services/touch_feedback_royal_clean.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/intercom_royal_clean.dart';

class NotificationsPanelRoyalClean extends StatefulWidget {
  const NotificationsPanelRoyalClean({super.key});
  @override
  State<NotificationsPanelRoyalClean> createState() =>
      _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanelRoyalClean> {
  bool _unreadOnly = false;
  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007F9F)),
      useMaterial3: true,
    ),
    child: Material(
      color: const Color(0xFFF2F7FA),
      child: SafeArea(
        top: true,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notificações',
                        style: TextStyle(
                          color: Color(0xFF092F43),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    LayoutButtonRoyalClean(
                      id: 'notifications_panel_royal_clean.control_01',
                      child: IconButton(
                        tooltip: 'Fechar notificações',
                        onPressed: tactileTapRoyalClean(
                          () => Navigator.pop(context),
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: IntercomRoyalClean.instance,
                  builder: (context, _) {
                    final feed = IntercomRoyalClean.instance;
                    final messages = feed.active
                        .where(
                          (message) => _unreadOnly
                              ? feed.isUnread(message)
                              : message.isToday(DateTime.now()),
                        )
                        .toList();
                    if (feed.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            LayoutButtonRoyalClean(
                              id: 'notifications.today',
                              child: ChoiceChip(
                                label: const Text('Hoje'),
                                selected: !_unreadOnly,
                                onSelected: (_) =>
                                    setState(() => _unreadOnly = false),
                              ),
                            ),
                            LayoutButtonRoyalClean(
                              id: 'notifications.unread',
                              child: ChoiceChip(
                                label: Text(
                                  'Mensagens não lidas (${feed.unreadCount})',
                                ),
                                selected: _unreadOnly,
                                onSelected: (_) =>
                                    setState(() => _unreadOnly = true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_unreadOnly)
                          const Text(
                            'Não lidas de todos os dias disponíveis no histórico.',
                          ),
                        if (feed.error != null) ...[
                          Text(
                            feed.error!,
                            style: const TextStyle(color: Color(0xFF092F43)),
                          ),
                          LayoutButtonRoyalClean(
                            id: 'notifications_panel_royal_clean.control_02',
                            child: TextButton(
                              onPressed: tactileTapRoyalClean(feed.reload),
                              child: const Text('Tentar novamente'),
                            ),
                          ),
                        ],
                        if (messages.isEmpty && feed.error == null)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.public_rounded,
                                  size: 44,
                                  color: Color(0xFF007F9F),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Nenhuma notificação por aqui.',
                                  style: TextStyle(
                                    color: Color(0xFF092F43),
                                    fontSize: 18,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Enquanto isso, explore as novidades e parcerias da Royal Clean.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFF607783)),
                                ),
                              ],
                            ),
                          ),
                        if (feed.unreadCount > 0)
                          Align(
                            alignment: Alignment.centerRight,
                            child: LayoutButtonRoyalClean(
                              id: 'notifications_panel_royal_clean.control_03',
                              child: TextButton(
                                onPressed: tactileTapRoyalClean(
                                  () => feed.markRead(
                                    messages.map((message) => message.id),
                                  ),
                                ),
                                child: const Text('Marcar lista como lida'),
                              ),
                            ),
                          ),
                        for (final message in messages)
                          Card(
                            color: feed.isUnread(message)
                                ? Colors.white
                                : const Color(0xFF102E63),
                            child: DefaultTextStyle.merge(
                              style: TextStyle(
                                color: feed.isUnread(message)
                                    ? const Color(0xFF092F43)
                                    : Colors.white,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '${message.kind}${feed.isUnread(message) ? ' • Nova' : ''}',
                                      style: const TextStyle(
                                        color: Color(0xFF409CBD),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      message.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SelectableText(message.body),
                                    const SizedBox(height: 12),
                                    Text(
                                      '${message.occurredAt == null ? 'Recebida em: ' : 'Fato em: '}${intercomDateRoyalClean(message.displayDate)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    if (feed.isUnread(message))
                                      LayoutButtonRoyalClean(
                                        id: 'notifications.read.${message.id}',
                                        child: TextButton(
                                          onPressed: tactileTapRoyalClean(
                                            () => feed.markRead([message.id]),
                                          ),
                                          child: const Text('Marcar como lida'),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
