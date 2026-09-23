import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core_royal_clean/services/admin_access_royal_clean.dart';
import '../home/home_page_royal_clean.dart';
import 'account_ui_royal_clean.dart';
import 'my_data_page_royal_clean.dart';
import 'registration_page_royal_clean.dart';

class AccountGateRoyalClean extends StatelessWidget {
  final Future<void> firebaseInitialization;
  final bool personalData;
  const AccountGateRoyalClean({
    super.key,
    required this.firebaseInitialization,
    this.personalData = false,
  });
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: firebaseInitialization,
    builder: (context, initialization) {
      if (initialization.hasError) {
        return const _AccessMessage(
          'Não foi possível conectar. Reabra o aplicativo e tente novamente.',
        );
      }
      if (initialization.connectionState != ConnectionState.done) {
        return const _AccessMessage('Conectando…');
      }
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.idTokenChanges(),
        builder: (context, auth) {
          if (auth.hasError) {
            return const _AccessMessage(
              'Sessão indisponível. Entre novamente.',
            );
          }
          if (auth.connectionState == ConnectionState.waiting) {
            return const _AccessMessage('Verificando sessão…');
          }
          if (auth.data == null) {
            return const _AccessMessage('Entre para acessar sua conta.');
          }
          return _AccountSession(
            key: ValueKey(auth.data!.uid),
            user: auth.data!,
            personalData: personalData,
          );
        },
      );
    },
  );
}

class _AccountSession extends StatefulWidget {
  final User user;
  final bool personalData;
  const _AccountSession({
    super.key,
    required this.user,
    required this.personalData,
  });
  @override
  State<_AccountSession> createState() => _AccountSessionState();
}

class _AccountSessionState extends State<_AccountSession> {
  bool _finishingRegistration = false;
  late final _admin = FirebaseFirestore.instance
      .doc('admin/${widget.user.uid}')
      .snapshots(includeMetadataChanges: true);
  late final _profile = FirebaseFirestore.instance
      .doc('users/${widget.user.uid}')
      .snapshots(includeMetadataChanges: true);

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: _admin,
    builder: (context, admin) {
      if (admin.hasError) {
        return const _AccessMessage(
          'Não foi possível verificar o acesso. Confira a conexão e tente entrar novamente.',
        );
      }
      if (!admin.hasData ||
          admin.data!.metadata.isFromCache ||
          admin.data!.metadata.hasPendingWrites) {
        return const _AccessMessage('Verificando permissões no servidor…');
      }
      if (admin.data!.exists) {
        if (!isActiveAdminRoyalClean(admin.data!.data(), widget.user.email)) {
          return const _AccessMessage(
            'Acesso administrativo indisponível. Contate o responsável.',
          );
        }
        return widget.personalData
            ? MyDataPageRoyalClean(user: widget.user, profile: const {})
            : const HomePageRoyalClean();
      }
      if (!widget.user.emailVerified) _finishingRegistration = true;
      if (_finishingRegistration) {
        return RegistrationPageRoyalClean(user: widget.user);
      }
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profile,
        builder: (context, profile) {
          if (profile.hasError) {
            return const _AccessMessage(
              'Não foi possível carregar seu cadastro. Confira a conexão e tente novamente.',
            );
          }
          if (!profile.hasData ||
              profile.data!.metadata.isFromCache ||
              profile.data!.metadata.hasPendingWrites) {
            return const _AccessMessage('Carregando seu perfil…');
          }
          if (!profile.data!.exists) {
            return RegistrationPageRoyalClean(user: widget.user);
          }
          final data = profile.data!.data()!;
          if (data['active'] != true ||
              !roleLabelsRoyalClean.containsKey(data['role'])) {
            return const _AccessMessage(
              'Seu acesso está indisponível. Entre em contato com o atendimento.',
            );
          }
          return widget.personalData
              ? MyDataPageRoyalClean(user: widget.user, profile: data)
              : RoleAreaRoyalClean(profile: data);
        },
      );
    },
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
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/preview',
                  (_) => false,
                );
              }
            },
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
