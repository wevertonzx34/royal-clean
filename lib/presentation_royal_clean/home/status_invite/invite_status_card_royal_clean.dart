import 'package:flutter/material.dart';

import '../../../../core_royal_clean/models/invite_status_royal_clean_model.dart';

class InviteStatusCardRoyalClean extends StatelessWidget {
  final InviteStatusRoyalCleanModel invite;
  final VoidCallback onCopyMessagePressed;
  final VoidCallback onSharePressed;
  final VoidCallback onDetailsPressed;

  const InviteStatusCardRoyalClean({
    super.key,
    required this.invite,
    required this.onCopyMessagePressed,
    required this.onSharePressed,
    required this.onDetailsPressed,
  });

  String _formatDate(DateTime? value) {
    if (value == null) return '-';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  String _statusLabel() {
    if (invite.isUsed) return 'Usado';
    if (invite.isExpired) return 'Expirado';
    if (invite.isActive) return 'Ativo';
    if (invite.isProcessing) return 'Processing';
    return invite.status.isEmpty ? '-' : invite.status;
  }

  Color _statusColor() {
    if (invite.isUsed) return const Color(0xFFE57373);
    if (invite.isActive) return const Color(0xFF81C784);
    if (invite.isProcessing) return const Color(0xFF0096C7);
    return Colors.white70;
  }

  Color _profileColor() {
    switch (invite.profile) {
      case 'Cliente':
        return const Color(0xFF4FC3F7);
      case 'Colaborador':
        return const Color(0xFF0288D1);
      case 'Promotor':
        return const Color(0xFF00A6C8);
      default:
        return Colors.white70;
    }
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = _statusLabel();
    final statusColor = _statusColor();
    final profileColor = _profileColor();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xB8062B3D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF155A78)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          /// Nome
          Text(
            invite.fullName.isEmpty ? 'Sem nome' : invite.fullName,
            style: theme.textTheme.titleMedium,
          ),

          const SizedBox(height: 6),

          /// Botão Detalhes (lado esquerdo)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onDetailsPressed,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Detalhes'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          /// Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: statusColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              statusLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 12),

          /// Perfil
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: profileColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: profileColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              invite.profile,
              style: theme.textTheme.bodySmall?.copyWith(
                color: profileColor,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 14),

          /// Função colaborador
          if (invite.profile == 'Colaborador' &&
              invite.collaboratorFunction != null)
            _row(context, 'Função', invite.collaboratorFunction!),

          _row(context, 'Código', invite.inviteCode),
          _row(context, 'WhatsApp', invite.whatsapp),
          _row(context, 'Criado em', _formatDate(invite.createdAt)),

          const SizedBox(height: 8),

          /// Botão Copiar
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onCopyMessagePressed,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar'),
            ),
          ),

          const SizedBox(height: 10),

          /// Botão Compartilhar menor
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              height: 42,
              width: 180,
              child: ElevatedButton.icon(
                onPressed: onSharePressed,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Compartilhar'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
