import '../shared/header_actions_royal_clean.dart';
import 'package:flutter/material.dart';
import 'home_background_royal_clean.dart';
import 'home_buttons_royal_clean.dart';

class RulesControlPageRoyalClean extends StatelessWidget {
  const RulesControlPageRoyalClean({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: HomeBackgroundRoyalClean(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isSmall = constraints.maxWidth < 700;
            final double maxWidth = isSmall ? 560 : 720;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      Expanded(
                        child: Text(
                          'Controle de regras',
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const HeaderActionsRoyalClean(),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 16 : 24,
                        vertical: 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: const Color(0xB8062B3D),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFF155A78),
                                ),
                              ),
                              child: Text(
                                'A estrutura do módulo de regras já está preparada. A função de criar regras será implementada depois do controle de acesso.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(height: 18),
                            HomePrimaryButtonRoyalClean(
                              title: 'Criar regra',
                              subtitle:
                                  'Criar nova regra administrativa do sistema.',
                              icon: Icons.add_task_rounded,
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Criar regra será implementado depois do Controle de acesso.',
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            HomePrimaryButtonRoyalClean(
                              title: 'Status regra',
                              subtitle:
                                  'Consultar regras criadas e seus estados.',
                              icon: Icons.fact_check_rounded,
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Status regra será implementado depois do Controle de acesso.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
