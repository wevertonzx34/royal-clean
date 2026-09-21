import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core_royal_clean/services/invite_service_royal_clean.dart';
import 'home_background_royal_clean.dart';

class CreateInvitePageRoyalClean extends StatefulWidget {
  const CreateInvitePageRoyalClean({super.key});

  @override
  State<CreateInvitePageRoyalClean> createState() =>
      _CreateInvitePageRoyalCleanState();
}

class _CreateInvitePageRoyalCleanState
    extends State<CreateInvitePageRoyalClean> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();

  bool _isGenerating = false;
  bool _isSaving = false;
  bool _inviteSaved = false;

  String _selectedProfile = InviteServiceRoyalClean.availableProfiles.first;
  String? _selectedCollaboratorFunction;
  InvitePreviewData? _preview;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_clearPreviewIfNeeded);
    _whatsappController.addListener(_clearPreviewIfNeeded);
  }

  @override
  void dispose() {
    _nameController.removeListener(_clearPreviewIfNeeded);
    _whatsappController.removeListener(_clearPreviewIfNeeded);
    _nameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  void _clearPreviewIfNeeded() {
    if (_preview != null || _inviteSaved) {
      setState(() {
        _preview = null;
        _inviteSaved = false;
      });
    }
  }

  bool get _isCollaborator => _selectedProfile == 'Colaborador';

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Informe o nome.';
    }

    if (text.length < 3) {
      return 'Digite um nome mais completo.';
    }

    return null;
  }

  String? _validateWhatsapp(String? value) {
    final digits = InviteServiceRoyalClean.normalizeDigits(value ?? '');

    if (digits.isEmpty) {
      return 'Informe o WhatsApp com DDD.';
    }

    if (digits.length < 10 || digits.length > 11) {
      return 'Digite o WhatsApp com DDD em um único campo.';
    }

    return null;
  }

  Future<void> _generatePreview() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isGenerating = true;
      _preview = null;
      _inviteSaved = false;
    });

    final result = InviteServiceRoyalClean.generateInvitePreview(
      fullName: _nameController.text,
      whatsappInput: _whatsappController.text,
      profile: _selectedProfile,
      collaboratorFunction: _isCollaborator
          ? _selectedCollaboratorFunction
          : null,
    );

    if (!mounted) return;

    setState(() {
      _isGenerating = false;
      _preview = result.preview;
      _inviteSaved = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveInvite() async {
    final preview = _preview;
    if (preview == null) return;

    setState(() {
      _isSaving = true;
    });

    final result = await InviteServiceRoyalClean.saveInvite(preview: preview);

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _inviteSaved = result.success;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copyInviteMessage() async {
    final preview = _preview;
    if (preview == null || !_inviteSaved) return;

    final message = InviteServiceRoyalClean.buildInviteMessage(
      fullName: preview.fullName,
      inviteCode: preview.inviteCode,
      profile: preview.profile,
      collaboratorFunction: preview.collaboratorFunction,
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

  Future<void> _openWhatsapp() async {
    final preview = _preview;
    if (preview == null || !_inviteSaved) return;

    final message = InviteServiceRoyalClean.buildInviteMessage(
      fullName: preview.fullName,
      inviteCode: preview.inviteCode,
      profile: preview.profile,
      collaboratorFunction: preview.collaboratorFunction,
    );

    final uri = Uri.parse(
      'https://wa.me/${preview.internationalWhatsapp}?text=${Uri.encodeComponent(message)}',
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

  Widget _buildProfileField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedProfile,
      decoration: const InputDecoration(
        labelText: 'Perfil',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      items: InviteServiceRoyalClean.availableProfiles
          .map(
            (profile) =>
                DropdownMenuItem<String>(value: profile, child: Text(profile)),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _selectedProfile = value;
          if (_selectedProfile != 'Colaborador') {
            _selectedCollaboratorFunction = null;
          }
          _preview = null;
          _inviteSaved = false;
        });
      },
    );
  }

  Widget _buildCollaboratorFunctionField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCollaboratorFunction,
      decoration: const InputDecoration(
        labelText: 'Função',
        prefixIcon: Icon(Icons.work_outline_rounded),
      ),
      items: InviteServiceRoyalClean.collaboratorFunctions
          .map(
            (role) => DropdownMenuItem<String>(value: role, child: Text(role)),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedCollaboratorFunction = value;
          _preview = null;
          _inviteSaved = false;
        });
      },
      validator: (_) {
        if (_isCollaborator && _selectedCollaboratorFunction == null) {
          return 'Selecione a função do colaborador.';
        }
        return null;
      },
    );
  }

  Widget _buildPreviewCard(BuildContext context, InvitePreviewData preview) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x100096C7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x220096C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Preview do convite', style: theme.textTheme.titleMedium),
          const SizedBox(height: 14),
          _PreviewRow(label: 'Nome', value: preview.fullName),
          _PreviewRow(label: 'Perfil', value: preview.profile),
          if (preview.profile == 'Colaborador' &&
              preview.collaboratorFunction != null)
            _PreviewRow(label: 'Função', value: preview.collaboratorFunction!),
          _PreviewRow(label: 'WhatsApp', value: preview.internationalWhatsapp),
          _PreviewRow(label: 'Código', value: preview.inviteCode),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: (_isSaving || _inviteSaved) ? null : _saveInvite,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _isSaving
                    ? 'Salvando...'
                    : _inviteSaved
                    ? 'Salvo'
                    : 'Salvar',
              ),
            ),
          ),
          if (_inviteSaved) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _copyInviteMessage,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copiar mensagem'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _openWhatsapp,
                icon: const Icon(Icons.share_rounded),
                label: const Text('Compartilhar'),
              ),
            ),
          ],
        ],
      ),
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
                          'Criar convite',
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
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xB8062B3D),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF155A78)),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Novo convite de acesso',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Preencha nome, WhatsApp com DDD e perfil. Para Colaborador, selecione também a função. O convite será gerado primeiro em preview e só será salvo no Firebase após sua confirmação.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _nameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Nome',
                                    hintText: 'Digite o nome completo',
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                    ),
                                  ),
                                  validator: _validateName,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _whatsappController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9()\-\s]'),
                                    ),
                                    LengthLimitingTextInputFormatter(15),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'WhatsApp com DDD',
                                    hintText: '11999998888',
                                    prefixIcon: Icon(
                                      Icons.phone_iphone_rounded,
                                    ),
                                  ),
                                  validator: _validateWhatsapp,
                                ),
                                const SizedBox(height: 16),
                                _buildProfileField(),
                                if (_isCollaborator) ...[
                                  const SizedBox(height: 16),
                                  _buildCollaboratorFunctionField(),
                                ],
                                const SizedBox(height: 22),
                                ElevatedButton(
                                  onPressed: _isGenerating
                                      ? null
                                      : _generatePreview,
                                  child: _isGenerating
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.black,
                                          ),
                                        )
                                      : const Text('Gerar convite'),
                                ),
                                if (_preview != null) ...[
                                  const SizedBox(height: 22),
                                  _buildPreviewCard(context, _preview!),
                                ],
                              ],
                            ),
                          ),
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

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
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
}
