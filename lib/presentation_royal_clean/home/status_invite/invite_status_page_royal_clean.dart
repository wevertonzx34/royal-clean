import 'package:flutter/material.dart';
import '../../shared/header_actions_royal_clean.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core_royal_clean/constants/app_routes_royal_clean.dart';
import '../../../../core_royal_clean/models/invite_status_royal_clean_model.dart';
import '../../../../core_royal_clean/services/invite_service_royal_clean.dart';
import '../../../../core_royal_clean/services/invite_status_service_royal_clean.dart';
import '../home_background_royal_clean.dart';
import 'invite_status_filters_royal_clean.dart';
import 'invite_status_list_royal_clean.dart';

class InviteStatusPageRoyalClean extends StatefulWidget {
  const InviteStatusPageRoyalClean({super.key});

  @override
  State<InviteStatusPageRoyalClean> createState() =>
      _InviteStatusPageRoyalCleanState();
}

class _InviteStatusPageRoyalCleanState
    extends State<InviteStatusPageRoyalClean> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedProfile = 'Todos';
  String _selectedStatus = 'Todos';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<InviteStatusRoyalCleanModel> _applyFilters(
    List<InviteStatusRoyalCleanModel> invites,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    return invites.where((invite) {
      final matchProfile = _selectedProfile == 'Todos'
          ? true
          : invite.profile.trim().toLowerCase() ==
                _selectedProfile.trim().toLowerCase();

      if (!matchProfile) return false;

      final matchStatus = switch (_selectedStatus) {
        'Ativo' => invite.isActive,
        'Usado' => invite.isUsed,
        'Processing' => invite.isProcessing,
        _ => true,
      };

      if (!matchStatus) return false;

      if (query.isEmpty) return true;

      final collaboratorFunction =
          invite.collaboratorFunction?.toLowerCase() ?? '';

      return invite.fullName.toLowerCase().contains(query) ||
          invite.whatsapp.toLowerCase().contains(query) ||
          invite.inviteCode.toLowerCase().contains(query) ||
          collaboratorFunction.contains(query);
    }).toList();
  }

  Future<void> _copyInviteMessage(InviteStatusRoyalCleanModel invite) async {
    final message = InviteServiceRoyalClean.buildInviteMessage(
      fullName: invite.fullName,
      inviteCode: invite.inviteCode,
      profile: invite.profile,
      collaboratorFunction: invite.collaboratorFunction,
    );

    await Clipboard.setData(ClipboardData(text: message));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensagem do convite copiada com sucesso.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareInvite(InviteStatusRoyalCleanModel invite) async {
    final message = InviteServiceRoyalClean.buildInviteMessage(
      fullName: invite.fullName,
      inviteCode: invite.inviteCode,
      profile: invite.profile,
      collaboratorFunction: invite.collaboratorFunction,
    );

    final uri = Uri.parse(
      'https://wa.me/${invite.whatsapp}?text=${Uri.encodeComponent(message)}',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o WhatsApp neste dispositivo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  void _openDetails(InviteStatusRoyalCleanModel invite) {
    Navigator.pushNamed(
      context,
      AppRoutesRoyalClean.inviteStatusDetails,
      arguments: {
        'inviteId': invite.inviteId,
        'inviteCode': invite.inviteCode,
        'fullName': invite.fullName,
        'email': invite.email,
        'profile': invite.profile,
        'collaboratorFunction': invite.collaboratorFunction,
        'whatsapp': invite.whatsapp,
        'status': invite.status,
        'registrationEnabled': invite.registrationEnabled.toString(),
        'isUsed': invite.isUsed.toString(),
        'createdAt': _formatDate(invite.createdAt),
        'usedAt': _formatDate(invite.usedAt),
        'usedByUid': invite.usedByUid ?? '-',
        'createdByUid': invite.createdByUid ?? '-',
        'createdByEmail': invite.createdByEmail ?? '-',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: HomeBackgroundRoyalClean(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isSmall = constraints.maxWidth < 700;
            final double maxWidth = isSmall ? 560 : 760;

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
                          'Status convite',
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const HeaderActionsRoyalClean(),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<InviteStatusRoyalCleanModel>>(
                    stream: InviteStatusServiceRoyalClean.watchInvites(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Erro ao carregar convites.',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final invites = snapshot.data ?? [];
                      final filteredInvites = _applyFilters(invites);

                      return Center(
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
                                  child: InviteStatusFiltersRoyalClean(
                                    searchController: _searchController,
                                    selectedProfile: _selectedProfile,
                                    selectedStatus: _selectedStatus,
                                    onProfileChanged: (value) {
                                      setState(() {
                                        _selectedProfile = value;
                                      });
                                    },
                                    onStatusChanged: (value) {
                                      setState(() {
                                        _selectedStatus = value;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 18),
                                InviteStatusListRoyalClean(
                                  invites: filteredInvites,
                                  onCopyMessagePressed: _copyInviteMessage,
                                  onSharePressed: _shareInvite,
                                  onDetailsPressed: _openDetails,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
