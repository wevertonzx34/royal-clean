# Ativação do cadastro e dos perfis — Royal Clean

Projeto: **royal-clean-fire**. Aplicativo Android: **com.example.royal_clean**. A versão do app permanece **1.0.3+4**.

O código local está integrado. Isso não publica automaticamente regras, funções nem configura OAuth no Firebase. Não foram apagados ou migrados dados reais. A prévia pública continua com seu conteúdo demonstrativo atual.

## Comportamento implementado

- Inicialização → prévia pública → botão Login. A prévia não depende de sessão nem do banco.
- Login por e-mail/senha, Google ou Apple. Recuperação de senha disponível.
- “Novo usuário” abaixo de “Esqueci minha senha”. Nome, e-mail, confirmação de e-mail, senha e confirmação de senha. Convite expansível e opcional. Termos/privacidade acessíveis. Ofertas desmarcadas inicialmente.
- Cadastro por senha: criação da identidade no Authentication, envio do link de verificação e conclusão no servidor após verificação. Se a pessoa interromper, pode entrar novamente e concluir os dados. A identidade no Authentication pode existir antes do perfil `users`; isso é um cadastro incompleto, sem acesso às áreas internas. Convite só é consumido ao concluir.
- Google/Apple: aproveitam o e-mail fornecido pelo provedor, sem pedir outra senha; novo usuário completa nome, termos e convite opcional. Se o provedor não confirmar e-mail, a verificação é exigida. O usuário pode informar um nome quando o provedor não fornecer.
- Todas as contas novas começam como **consumer**. O convite identifica origem e perfil de referência, sem conceder perfil, benefício, desconto ou comissão.
- Admin → botão “Usuários e perfis” no topo do painel → busca por e-mail completo, paginação e edição de consumidor/colaborador/promotor/ativo. Alterações são auditadas pelo servidor. Esse fluxo nunca cria administradores.
- Cada perfil tem sua área, acesso à prévia e “Meus dados”. Pedidos, comissões e operações internas futuras não são simulados como funcionalidades prontas.
- “Meus dados”: nome, ofertas e CPF/CNPJ opcionais. Documento validado no servidor, incluindo CNPJ alfanumérico, sem consulta de titularidade à Receita. Selecionar “Não informar / remover” e salvar remove o documento desse cadastro.
- Convite inválido, utilizado, desativado ou expirado impede concluir **com aquele código**. Remover o código permite uma conta comum. Não existe aplicação posterior. Um novo convite tem prazo de 30 dias; convites antigos sem `expiresAt` continuam válidos conforme o estado anterior, preservando os dados existentes.
- Sessão nativa persiste pelo Firebase. O antigo checkbox visual de “lembrar acesso”, que não mudava a persistência, foi substituído por informação clara e botão Sair nas áreas privadas.

## 1. Revisar os documentos antes de receber clientes reais

`lib/presentation_royal_clean/auth/account_ui_royal_clean.dart` contém as telas dos documentos, explicitamente marcados como minutas. Ainda faltam razão social/CNPJ do responsável, contato de privacidade/atendimento e política real de retenção. Não trate esses textos como uma política jurídica final.

Dados de responsável/contato podem ser informados na compilação com `--dart-define=ROYAL_LEGAL_ENTITY=...` e `--dart-define=ROYAL_LEGAL_CONTACT=...`. A política definitiva deve substituir a minuta no arquivo. Ao alterar a versão, sincronize `legalVersionRoyalClean` no serviço Dart e `LEGAL_VERSION` em `functions/validation.js`.

## 2. Authentication

No console do projeto correto:

1. Authentication → Método de login: habilitar **E-mail/senha**.
2. Nas configurações de política de senha: definir mínimo **15**, máximo **128** caracteres e política obrigatória para novos cadastros. O app aceita frases longas; não imponha requisitos de composição contraditórios sem adaptar as instruções da tela. Login de contas antigas continua aceitando a senha existente.
3. Ativar proteção contra enumeração de e-mails quando disponível. As mensagens de recuperação são neutras.
4. Em Templates, ajustar nome Royal Clean, idioma e endereços autorizados dos e-mails de verificação e recuperação. Testar entrega e spam.
5. Proteger as contas que administram o console Google com autenticação em duas etapas e conceder só os acessos necessários. A autenticação multifator de **usuários do app** não foi adicionada neste escopo.

## 3. Google

Em 22/09/2026, o arquivo oficial atualizado de Downloads foi aplicado em `android/app/google-services.json` e na cópia da raiz. Foram conferidos o projeto, o app Android, o cliente OAuth Android com a assinatura SHA-1 de desenvolvimento e o cliente OAuth Web. As opções de `lib/firebase_options.dart` já correspondem ao arquivo novo. O login real com Google ainda precisa ser validado pelo usuário no aparelho; os passos abaixo servem também para futuras atualizações de configuração.

1. Authentication → Método de login → Google: habilitar, definir nome público e e-mail de suporte.
2. Configurações do projeto → Seus apps → Android `com.example.royal_clean`: cadastrar SHA-1 e SHA-256 das assinaturas usadas. Para testar, usar as do debug; para publicar, usar as da assinatura de produção/Play App Signing.
3. Para consultar assinaturas locais, na pasta `android`, executar `./gradlew signingReport` (PowerShell: `.\gradlew.bat signingReport`).
4. Baixar novamente o arquivo oficial `google-services.json` depois da ativação do Google. Substituir **android/app/google-services.json**. A cópia da raiz, se mantida, deve ser a mesma.
5. Fazer uma nova compilação/instalação. Hot reload não atualiza esse arquivo nativo.

O `android/app/build.gradle.kts` atual ainda assina builds release com a chave de debug. A assinatura definitiva precisa ser configurada antes de publicar na loja; cadastre os fingerprints correspondentes ao certificado realmente utilizado.

O SDK solicita autenticação básica, não acesso a contatos, Gmail ou Drive. A colisão com uma conta existente orienta entrar pelo método original; não há vinculação automática por e-mail não verificado.

## 4. Apple

No Android, o botão usa o fluxo OAuth do Firebase com Apple. Não basta ativar visualmente o botão.

1. Configurar Sign in with Apple na conta Apple Developer: App ID primário, Service ID para o fluxo web/Android, Team ID e chave apropriada.
2. Cadastrar o domínio e a URL de retorno mostrados no Firebase. No domínio padrão deste projeto, o retorno é `https://royal-clean-fire.firebaseapp.com/__/auth/handler`; conferir o endereço exibido no console antes de salvar.
3. Authentication → Método de login → Apple: preencher Service ID, Team ID, Key ID e chave privada **diretamente no console**. Não colocar arquivo `.p8`, senha ou chave privada no Dart, Git ou chat.
4. Configurar o serviço de retransmissão privada da Apple para os remetentes usados nos e-mails Firebase, para atender quem escolher ocultar seu e-mail.
5. iOS ainda exige cadastrar o app iOS real no Firebase, gerar a configuração FlutterFire correspondente, adicionar `GoogleService-Info.plist`, configurar bundle ID/capability Sign in with Apple e testar no ambiente Apple. Atualmente `firebase_options.dart` está configurado apenas para Android. O código Dart não torna essas plataformas automaticamente prontas.

## 5. App Check

O app ativa **Debug Provider em debug** e **Play Integrity em release Android**. As três funções exigem App Check (`enforceAppCheck: true`). Não remova essa proteção para fazer um teste passar.

1. Console → App Check → registrar o app Android com Play Integrity e os certificados corretos.
2. Para APKs de desenvolvimento, executar o app e localizar a mensagem de token de depuração do App Check no log local. Cadastrar esse token em App Check → app Android → Gerenciar tokens de depuração. Tratar o token como credencial de teste; não commitar nem publicar.
3. Monitorar as métricas antes de impor App Check a produtos usados por versões antigas. A exigência nas **novas funções** já está no código; a exigência global no Firestore é uma configuração separada e não foi ativada automaticamente.
4. Testar a configuração de Play Integrity com a distribuição e assinatura de produção; um APK debug autorizado não comprova que o release está pronto.

## 6. Publicar backend e regras

Cloud Functions exige um projeto com faturamento habilitado/plano Blaze. Confirmar custos, orçamento e alertas na conta antes de mudar o plano. Esta implementação não habilita faturamento.

Arquivos locais já preparados:

| Arquivo | Ação fora do código local |
| --- | --- |
| `firestore.rules` | Copiar **todo o arquivo** em Firestore Database → Regras → Publicar, ou usar o deploy abaixo. |
| `functions/index.js`, `functions/validation.js`, `functions/package.json`, `functions/package-lock.json` | Publicar como Cloud Functions. **Não** colar no editor de regras. |
| `firebase.json` e `.firebaserc` | Configuração local do deploy; já apontam para Royal Clean. |
| `android/app/google-services.json` | Substituir pelo download oficial atualizado com OAuth. |
| Configuração Apple/Google/App Check | Preencher nos consoles dos provedores; não se resolve copiando código Dart. |

Na raiz do repositório, com Node.js **22**, Firebase CLI instalado e uma conta autorizada:

```powershell
cd C:\royal_clean\functions
npm ci
cd C:\royal_clean
firebase login
firebase use royal-clean-fire
firebase deploy --only functions:royal-clean-accounts,firestore:rules --project royal-clean-fire
```

Se usar o CLI já instalado para os testes, substituir `firebase` por `.\security-tests\node_modules\.bin\firebase.cmd` a partir da raiz. O deploy usa o codebase `royal-clean-accounts` para separar essas funções de outros backends. Região: **southamerica-east1**, igual no aplicativo. A localização do Firestore existente não é alterada.

Funções: `registerAccount`, `updateMyData`, `setUserRole`. Não armazenam senhas nos documentos. Auth e Firestore são serviços separados: cadastro interrompido não concede acesso e pode ser retomado. O consumo do convite e a criação do perfil no Firestore são atômicos. As funções limitam tentativas por UID; o Firebase também aplica seus próprios controles de autenticação.

Não há uma migração ou script de exclusão. As coleções existentes de administradores, convites, produtos e notícias são mantidas. Dados novos:

| Coleção | Uso e acesso |
| --- | --- |
| `users/{uid}` | Perfil, estado, referência de convite e aceite. Leitura do próprio usuário verificado e do admin ativo; gravação só pelo backend. |
| `personal_data/{uid}` | Nome, documento opcional e preferência; leitura só do titular autorizado; gravação só pelo backend. Não aparece na listagem administrativa. |
| `account_audit/{id}` | Auditoria de alterações de perfil; sem acesso direto pelos clientes. |
| `account_rate_limits/{uid_operacao}` | Contagem de tentativas; sem acesso direto pelos clientes. |

Admin atual continua sendo reconhecido por `admin/{uid}` com `eAdministrador: true`, `ativo: true` e e-mail correspondente. A tela de usuários não promove ninguém a admin. Os perfis não são lidos de parâmetros da navegação ou campos editáveis pelo próprio usuário.

## 7. Verificação após ativação

1. Abrir sem sessão: prévia pública e Login. Voltar à prévia continua disponível mesmo com erro de conexão.
2. Criar conta comum, verificar e-mail, aceitar termos, concluir e abrir área do consumidor. Conferir ofertas desmarcadas.
3. Repetir com convite válido: referência registrada e convite utilizado. Tentar reaproveitar, usar expirado e inválido; remover e concluir sem convite.
4. Conta já concluída não pode anexar convite posteriormente, nem fazendo chamada direta.
5. Entrar como admin, abrir Usuários e perfis, atribuir colaborador/promotor e observar atualização da área. Desativar o perfil deve retirar o acesso.
6. Editar Meus dados, testar CPF/CNPJ válido e inválido, remover documento e alterar ofertas. Outra conta não pode ler esses dados.
7. Testar Google e Apple reais, cancelamento dos fluxos, e-mail privado Apple, recuperação de senha e logout.

Testes locais:

```powershell
flutter analyze --no-pub
flutter test
cd functions
npm test
cd ..\security-tests
npm test
```

O último comando usa exclusivamente os emuladores de Auth (`127.0.0.1:9199`) e Firestore (`127.0.0.1:8185`) no projeto fictício `demo-royal-clean`. Testa regras, transações concorrentes, resgate de convite, separação de dados e autorização das funções. Os handlers de backend são invocados localmente; esses testes não substituem validar App Check/OAuth no dispositivo e nos consoles reais.

Referências oficiais: [Firebase Auth Flutter](https://firebase.google.com/docs/auth/flutter/federated-auth), [Google Sign-In](https://pub.dev/packages/google_sign_in), [App Check Flutter](https://firebase.google.com/docs/app-check/flutter/default-providers), [Callable Functions](https://firebase.google.com/docs/functions/callable), [CNPJ alfanumérico — Receita Federal](https://www.gov.br/receitafederal/pt-br/centrais-de-conteudo/publicacoes/documentos-tecnicos/cnpj).
