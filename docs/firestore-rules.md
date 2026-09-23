# Regras do Firestore — Royal Clean

Arquivo para copiar: `../firestore.rules`. Projeto: **royal-clean-fire**.

Este conjunto cobre o contrato do aplicativo atual e define um contrato inicial para produtos e notícias. Não é uma garantia de segurança absoluta nem uma implementação de funcionalidades futuras. As regras não foram publicadas automaticamente.

O cadastro e os perfis agora incluem backend em `functions/`. Consulte [ativação completa](ativacao-cadastro-firebase.md): publicar apenas as regras não ativa as funções, o Google, a Apple ou o App Check.

## Publicar no Firebase

1. Abra o projeto `royal-clean-fire`.
2. Entre em **Firestore Database > Regras**.
3. Copie TODO o conteúdo de `firestore.rules`, de `rules_version` até a última chave.
4. Substitua todo o texto do editor e clique em **Publicar**.
5. Confirme que o console aceitou as regras.

O caminho já está configurado em `firebase.json`. Para uma futura publicação pela CLI, use explicitamente `firebase deploy --only firestore:rules --project royal-clean-fire` com uma conta autorizada.

## Login administrativo

No Authentication, a conta precisa existir com login por e-mail/senha. No Firestore, o ID do documento `admin/{UID}` deve ser o UID dessa mesma conta.

| Campo | Tipo | Valor |
|---|---|---|
| email | string | Mesmo e-mail da conta, preferencialmente em minúsculas |
| eAdministrador | boolean | true |
| ativo | boolean | true |

A leitura do próprio documento é permitida a usuários autenticados, mesmo quando inativos, para que o login atual consiga explicar a recusa. Isso não autoriza acesso aos convites. O aplicativo não pode listar administradores, criar um administrador, alterar permissões ou excluir esse cadastro. Provisionamento administrativo é feito pelo console ou por backend confiável.

Para conferir: abra **Login** no aplicativo e entre com a conta do novo projeto. Credenciais corretas e documento administrativo válido devem abrir a Home. Não compartilhe a senha no chat.

Contas autenticadas comuns, contas sem documento administrativo, administradores inativos e cadastros com e-mail divergente não recebem acesso aos convites. Colocar `ativo: false` bloqueia novas operações protegidas no servidor. A interface administrativa acompanha o documento e oculta as páginas protegidas quando recebe a revogação, ou quando perde a confirmação do servidor. Isso não apaga dados já baixados nem equivale a revogar todos os tokens do Firebase Auth. Desativação da conta no Authentication tem seu próprio ciclo de detecção e revogação.

## Convites compatíveis com o aplicativo atual

- Novos convites: perfil Mestre, sem função de colaborador.
- E-mail do destinatário obrigatório, normalizado em minúsculas.
- Código de oito caracteres, com prefixo M.
- Nome de 3 a 160 caracteres; telefone brasileiro com DDD, conforme o formato já usado no app. Isso não comprova existência ou posse do número.
- Convite criado como `processing`, com cadastro habilitado e ainda não utilizado.
- Data de criação do servidor; UID e e-mail do criador iguais à conta autenticada.
- O convite, o índice do código e o índice WhatsApp/perfil devem ser criados na mesma transação ou lote.
- Os índices precisam reproduzir exatamente os dados do convite.
- O índice impede convites duplicados para o mesmo telefone/perfil.
- Leitura de convites e consulta individual dos índices somente para administradores ativos.
- Novos convites exigem `expiresAt`, com validade de 30 dias; regras aceitam até 31 dias para acomodar diferenças pequenas de relógio. Convites legados ficam no histórico e não liberam novos cadastros.
- Atualização e exclusão de convites/índices bloqueadas no cliente. O backend consome o convite em transação na conclusão do cadastro.

**Resgate do convite:** `registerAccount` exige identidade autenticada, e-mail verificado e App Check. Em transação, confere validade/uso, perfil Mestre, e-mail do Authentication e telefone normalizado contra o convite. Só então cria o perfil `master` e consome o código. Sem código, cria `consumer`. Não concede administração nem permite incluir convite depois. O telefone é conferido, não verificado por SMS. Índices e convites não são expostos a usuários comuns.

**Perfis e dados pessoais:** `users/{uid}` pode ser lido pelo titular verificado e pelo admin ativo; somente backend grava. `personal_data/{uid}` é privado ao titular autorizado e somente backend grava. Alteração de perfil passa por `setUserRole`; auditoria e contadores de tentativas ficam fechados ao cliente.

## Contrato da futura vitrine pública

A prévia atual ainda usa dados locais. Publicar estas regras não conecta a vitrine ao Firestore nem cria telas de publicação.

Coleções propostas: `products` e `news`. IDs: letras, números, hífen ou sublinhado, de 1 a 100 caracteres.

Campos comuns obrigatórios:

| Campo | Tipo e limite |
|---|---|
| title | string, 3 a 120 caracteres |
| category | string, 1 a 60 caracteres |
| imageUrl | string HTTPS, 9 a 2048 caracteres |
| published | boolean; false para rascunho, true para publicação |
| createdAt | timestamp do servidor na criação; imutável |
| updatedAt | timestamp do servidor em cada gravação |

Produtos exigem também `description` (string, 1 a 5000 caracteres).

Notícias exigem também `summary` (string, 1 a 320 caracteres) e `body` (string, 1 a 20000 caracteres).

Campos extras são recusados. Estes documentos devem conter SOMENTE conteúdo público. Preços, estoque, dados fiscais, faturamento, custos e credenciais de integração não fazem parte deste contrato e dependerão de modelagem própria. As regras validam o formato HTTPS da imagem, não sua existência ou autorização de uso.

Administradores ativos podem criar, editar, publicar, despublicar e excluir esses documentos. Visitantes e usuários comuns só podem ler documentos com `published == true`. A consulta pública deve incluir `where('published', isEqualTo: true)`; uma consulta sem esse filtro será recusada. As regras não filtram resultados automaticamente. Subcoleções continuam bloqueadas.

## Limites e próximas etapas

- Authentication valida credenciais; regras do Firestore autorizam operações no banco. Regras não impedem por si só a criação de contas no Authentication.
- Novos usuários comuns precisam de e-mail verificado. A política dos administradores existentes foi preservada; MFA dos usuários do aplicativo não foi implementado.
- App Check deve ser configurado e validado no aplicativo antes de ativar a exigência no console.
- Cloud Storage usa regras próprias; este arquivo não autoriza upload de imagens.
- O módulo visual Controle de regras não publica regras de segurança do Firebase.
- Todo caminho não declarado permanece bloqueado, incluindo faturamento e integrações.
- O SDK Admin e acessos administrativos do console não ficam sujeitos a estas regras. Suas permissões IAM e a validação no backend precisam de controle próprio.

## Testes locais

Em `security-tests`, execute `npm ci` e depois `npm test`, usando Java compatível com o emulador instalado. No ambiente Windows deste projeto foi usado o Java do Android Studio (`jbr`).

Os testes usam somente o projeto fictício `demo-royal-clean` no emulador `127.0.0.1:8185`. Eles não alteram o projeto Firebase real. A suíte cobre login, escalada de privilégios, contas inativas, transações e duplicidade de convites, campos inválidos, rascunhos, consultas públicas e bloqueio de caminhos desconhecidos.

Validação em 22/09/2026: a suíte inclui regras e handlers do backend, com Auth e Firestore locais. O login real e o App Check ainda deverão ser verificados após publicar as regras/funções e configurar os consoles.

## Referências oficiais

- https://firebase.google.com/docs/firestore/security/rules-conditions
- https://firebase.google.com/docs/firestore/security/rules-fields
- https://firebase.google.com/docs/firestore/manage-data/transactions
- https://firebase.google.com/docs/firestore/security/test-rules-emulator
