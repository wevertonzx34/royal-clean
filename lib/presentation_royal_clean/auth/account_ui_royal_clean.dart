import 'package:flutter/material.dart';

class AccountLayoutRoyalClean extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  const AccountLayoutRoyalClean({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void showAccountMessageRoyalClean(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class LegalPageRoyalClean extends StatelessWidget {
  final bool privacy;
  const LegalPageRoyalClean({super.key, required this.privacy});
  @override
  Widget build(BuildContext context) => AccountLayoutRoyalClean(
    title: privacy ? 'Aviso de privacidade' : 'Termos de uso',
    child: SelectableText(
      privacy ? _privacy : _terms,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  );
}

// Supply the responsible entity and support channel before public release.
const _entity = String.fromEnvironment(
  'ROYAL_LEGAL_ENTITY',
  defaultValue: 'Royal Clean',
);
const _contact = String.fromEnvironment(
  'ROYAL_LEGAL_CONTACT',
  defaultValue:
      'Canal de atendimento a ser informado pela Royal Clean antes da abertura pública dos cadastros.',
);
const _privacy =
    '''AVISO DE PRIVACIDADE • versão 2026-09-22

Responsável: $_entity
Contato: $_contact

No cadastro, usamos nome, e-mail e identificador da conta para identificar você e permitir seu acesso. A senha é processada pelo Firebase Authentication; ela não é gravada nos documentos de perfil do aplicativo. Ao entrar com Google ou Apple, recebemos os dados de autenticação disponibilizados pelo provedor. Não solicitamos sua senha desses provedores.

O código de convite é opcional, registrado apenas na criação da conta e serve para identificar a origem do cadastro. Não concede benefícios comerciais nem permissões administrativas.

CPF ou CNPJ podem ser informados opcionalmente em Meus dados para futuras operações de compra e identificação fiscal. A verificação dos dígitos não comprova titularidade nem situação cadastral.

A opção de receber ofertas começa desmarcada e pode ser alterada em Meus dados. Ela não é condição para utilizar sua conta.

Os serviços Firebase/Google processam os dados necessários à autenticação e ao armazenamento. Os perfis são privados; o painel administrativo é restrito a pessoas autorizadas. Dados de documentos não são publicados na prévia.

Você pode corrigir nome, documento e preferências em Meus dados. Solicitações de acesso, exclusão e outras questões sobre seus dados devem ser encaminhadas ao contato acima. Prazos de retenção e eventual manutenção por obrigações aplicáveis precisam ser definidos na política definitiva antes da abertura pública.

Documento preparado para revisão da Royal Clean. Identificação completa, contato e política de retenção ainda devem ser confirmados antes de receber cadastros de clientes reais.''';
const _terms =
    '''TERMOS DE USO • versão 2026-09-22

Responsável: $_entity
Contato: $_contact

A prévia de produtos e notícias pode ser acessada sem conta. Os conteúdos demonstrativos da prévia não constituem confirmação de estoque, preço, pedido ou condição comercial.

Para criar uma conta, informe dados corretos, utilize um e-mail sob seu controle e proteja suas credenciais. O cadastro por senha exige verificação do e-mail. Você também pode utilizar os provedores sociais disponíveis.

As contas começam com perfil de consumidor. A Royal Clean define os acessos de colaboradores e promotores. O acesso administrativo é concedido separadamente, de forma restrita.

O convite é opcional, só pode ser utilizado na conclusão do cadastro inicial e serve exclusivamente como referência de identificação. Não pode ser incluído depois, não garante vínculo profissional e não concede descontos, comissões ou outros benefícios. Um código inválido, expirado ou utilizado pode ser removido para concluir um cadastro comum.

Não utilize contas de terceiros, não tente acessar dados sem autorização e não compartilhe sua senha. Acesso poderá ser restringido pela administração; dúvidas devem ser direcionadas ao atendimento.

Condições de venda, entrega, pagamento e devolução serão apresentadas quando essas funcionalidades estiverem disponíveis.

Documento preparado para revisão da Royal Clean antes da abertura pública dos cadastros.''';
