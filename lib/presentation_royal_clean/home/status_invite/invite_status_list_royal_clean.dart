import 'package:flutter/material.dart';

import '../../../../core_royal_clean/models/invite_status_royal_clean_model.dart';
import 'invite_status_card_royal_clean.dart';

class InviteStatusListRoyalClean extends StatelessWidget {
  final List<InviteStatusRoyalCleanModel> invites;
  final void Function(InviteStatusRoyalCleanModel invite) onCopyMessagePressed;
  final void Function(InviteStatusRoyalCleanModel invite) onSharePressed;
  final void Function(InviteStatusRoyalCleanModel invite) onDetailsPressed;

  const InviteStatusListRoyalClean({
    super.key,
    required this.invites,
    required this.onCopyMessagePressed,
    required this.onSharePressed,
    required this.onDetailsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final totalActive = invites.where((item) => item.isActive).length;
    final totalUsed = invites.where((item) => item.isUsed).length;
    final totalProcessing = invites.where((item) => item.isProcessing).length;

    if (invites.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xB8062B3D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF155A78)),
        ),
        child: Text(
          'Nenhum convite encontrado.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xB8062B3D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF155A78)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryItem(title: 'Total Ativo', value: totalActive.toString()),
              const SizedBox(height: 12),
              _SummaryItem(title: 'Total Usado', value: totalUsed.toString()),
              const SizedBox(height: 12),
              _SummaryItem(
                title: 'Total Processing',
                value: totalProcessing.toString(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...invites.map(
          (invite) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: InviteStatusCardRoyalClean(
              invite: invite,
              onCopyMessagePressed: () => onCopyMessagePressed(invite),
              onSharePressed: () => onSharePressed(invite),
              onDetailsPressed: () => onDetailsPressed(invite),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x14000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF155A78)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF0096C7),
            ),
          ),
        ],
      ),
    );
  }
}
