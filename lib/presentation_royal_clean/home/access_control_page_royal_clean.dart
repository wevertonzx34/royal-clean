import 'package:flutter/material.dart';
import '../../core_royal_clean/constants/app_routes_royal_clean.dart';
import 'home_background_royal_clean.dart';
import 'home_buttons_royal_clean.dart';

class AccessControlPageRoyalClean extends StatelessWidget {
  const AccessControlPageRoyalClean({super.key});

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
                          'Controle de acesso',
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
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
                                  'Autorize o cadastro de Mestres com convites vinculados ao e-mail e telefone de cada pessoa.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(height: 18),
                            HomePrimaryButtonRoyalClean(
                              title: 'Criar convite',
                              subtitle:
                                  'Liberar cadastro como Mestre. Uso único e validade de 30 dias.',
                              icon: Icons.person_add_alt_1_rounded,
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutesRoyalClean.createInvite,
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            HomePrimaryButtonRoyalClean(
                              title: 'Status convite',
                              subtitle:
                                  'Consultar convites emitidos e seus estados.',
                              icon: Icons.assignment_turned_in_rounded,
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutesRoyalClean.inviteStatus,
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
