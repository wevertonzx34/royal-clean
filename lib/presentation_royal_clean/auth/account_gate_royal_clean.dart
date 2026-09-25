import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/account_access_royal_clean.dart';
import '../preview/preview_page_royal_clean.dart';
import 'logout_royal_clean.dart';
import '../home/home_page_royal_clean.dart';
import 'account_ui_royal_clean.dart';
import 'my_data_page_royal_clean.dart';
import 'registration_page_royal_clean.dart';
import 'biometric_gate_royal_clean.dart';

class AccountGateRoyalClean extends StatefulWidget {
  final Future<void> firebaseInitialization;
  final bool personalData;
  const AccountGateRoyalClean({
    super.key,
    required this.firebaseInitialization,
    this.personalData = false,
  });
  @override
  State<AccountGateRoyalClean> createState() => _AccountGateRoyalCleanState();
}

class _AccountGateRoyalCleanState extends State<AccountGateRoyalClean> {
  bool _ready = false;
  bool _failed = false;
  String? _registrationUid;
  @override
  void initState() {
    super.initState();
    _ready = AccountAccessRoyalClean.instance.started;
    if (!_ready) {
      widget.firebaseInitialization.then(
        (_) {
          AccountAccessRoyalClean.instance.start();
          if (mounted) setState(() => _ready = true);
        },
        onError: (Object error) {
          if (mounted) setState(() => _failed = true);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const _AccessMessage(
        'Não foi possível conectar. Confira sua conexão e tente novamente.',
      );
    }
    if (!_ready) return const _AccountLoading();
    return ValueListenableBuilder<AccountAccessState>(
      valueListenable: AccountAccessRoyalClean.instance,
      builder: (context, access, _) {
        if (access.status == AccountAccessStatus.signedOut) {
          return const PreviewPageRoyalClean();
        }
        if (access.status == AccountAccessStatus.registration) {
          _registrationUid = access.identity?.uid;
        }
        final finishingRegistration =
            _registrationUid != null &&
            _registrationUid == access.identity?.uid &&
            (access.status == AccountAccessStatus.checking ||
                access.status == AccountAccessStatus.registration);
        if (access.status == AccountAccessStatus.checking &&
            !finishingRegistration) {
          return const _AccountLoading();
        }
        if (access.status == AccountAccessStatus.unavailable) {
          return const _AccessMessage(
            'Não foi possível confirmar o acesso. Confira a conexão e tente novamente.',
          );
        }
        if (access.status == AccountAccessStatus.denied) {
          return const _AccessMessage(
            'Seu acesso está indisponível. Contate o responsável.',
          );
        }
        final user = FirebaseAuth.instance.currentUser;
        if (user == null || user.uid != access.identity?.uid) {
          return const _AccountLoading();
        }
        return BiometricGateRoyalClean(
          builder: (_) {
            if (finishingRegistration) {
              return RegistrationPageRoyalClean(
                key: ValueKey(user.uid),
                user: user,
              );
            }
            if (widget.personalData) {
              return MyDataPageRoyalClean(
                user: user,
                profile: access.profile ?? const {},
                isAdmin: access.status == AccountAccessStatus.admin,
              );
            }
            return access.status == AccountAccessStatus.admin
                ? const HomePageRoyalClean()
                : RoleAreaRoyalClean(profile: access.profile!);
          },
        );
      },
    );
  }
}

class _AccountLoading extends StatelessWidget {
  const _AccountLoading();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

const roleLabelsRoyalClean = {
  'master': 'Mestre',
  'consumer': 'Consumidor',
  'collaborator': 'Colaborador',
  'promoter': 'Promotor',
};

class RoleAreaRoyalClean extends StatelessWidget {
  final Map<String, dynamic> profile;
  const RoleAreaRoyalClean({super.key, required this.profile});
  @override
  Widget build(BuildContext context) {
    final role = profile['role'];
    final label = roleLabelsRoyalClean[role] ?? 'Consumidor';
    return AccountLayoutRoyalClean(
      title: 'Área do ${label.toLowerCase()}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            role == 'master'
                ? Icons.workspace_premium_outlined
                : role == 'collaborator'
                ? Icons.badge_outlined
                : role == 'promoter'
                ? Icons.campaign_outlined
                : Icons.shopping_bag_outlined,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            'Olá, ${profile['name'] ?? ''}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            role == 'master'
                ? 'Seu cadastro como Mestre foi autorizado por convite da administração.'
                : role == 'collaborator'
                ? 'Seu espaço de colaboração com a Royal Clean.'
                : role == 'promoter'
                ? 'Seu espaço de relacionamento e divulgação da Royal Clean.'
                : 'Seu espaço para acompanhar a Royal Clean e manter seus dados atualizados.',
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Meus dados'),
              subtitle: const Text('Nome, CPF/CNPJ opcional e preferências'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/my-data'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Produtos e notícias'),
              subtitle: const Text('Explorar a prévia pública'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/preview'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Perfil: $label. As permissões são definidas pela administração.',
          ),
          if (profile['referral'] != null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Origem do cadastro identificada por convite. Sem benefícios comerciais associados.',
              ),
            ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => logoutToPreviewRoyalClean(context),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

class _AccessMessage extends StatelessWidget {
  final String message;
  const _AccessMessage(this.message);
  @override
  Widget build(BuildContext context) => AccountLayoutRoyalClean(
    title: 'Minha conta',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (_) => false,
          ),
          child: const Text('Ir para login'),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/preview',
            (_) => false,
          ),
          child: const Text('Voltar à prévia pública'),
        ),
      ],
    ),
  );
}
