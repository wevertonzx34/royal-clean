import 'package:flutter/material.dart';
import '../../core_royal_clean/services/intercom_royal_clean.dart';

class NotificationsPanelRoyalClean extends StatelessWidget {
  const NotificationsPanelRoyalClean({super.key});
  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007F9F)),
      useMaterial3: true,
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
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
                  IconButton(
                    tooltip: 'Fechar notificações',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: IntercomRoyalClean.instance,
                builder: (context, _) {
                  final feed = IntercomRoyalClean.instance;
                  final messages = feed.active;
                  if (feed.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      if (feed.error != null) ...[
                        Text(
                          feed.error!,
                          style: const TextStyle(color: Color(0xFF092F43)),
                        ),
                        TextButton(
                          onPressed: feed.reload,
                          child: const Text('Tentar novamente'),
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
                          child: TextButton(
                            onPressed: () => feed.markRead(
                              messages.map((message) => message.id),
                            ),
                            child: const Text('Marcar todas como lidas'),
                          ),
                        ),
                      for (final message in messages)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '${message.kind}${feed.isUnread(message) ? ' • Nova' : ''}',
                                  style: const TextStyle(
                                    color: Color(0xFF007F9F),
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
                                  intercomDateRoyalClean(message.publishedAt),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if (feed.isUnread(message))
                                  TextButton(
                                    onPressed: () =>
                                        feed.markRead([message.id]),
                                    child: const Text('Marcar como lida'),
                                  ),
                              ],
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
  );
}
