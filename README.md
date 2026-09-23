# Royal Clean

Painel administrativo Royal Clean desenvolvido em Flutter, com Firebase Authentication e Cloud Firestore.

Versão atual: **1.0.3+4**, declarada em `pubspec.yaml`.

## Funcionalidades

- Login por e-mail/senha, Google e Apple, com configuração dos provedores pendente nos consoles.
- Cadastro com confirmação de e-mail/senha, verificação do e-mail, convite opcional e preferências de ofertas.
- Áreas de consumidor, colaborador, promotor e administrador; gestão de perfis pelo admin.
- Meus dados com CPF/CNPJ opcional, gravado por backend e privado ao titular.
- Página inicial pública com vitrine, categorias e notícias demonstrativas.
- Criação e consulta de convites para Cliente, Colaborador e Promotor.
- Compartilhamento de convites pelo WhatsApp.
- Rotas administrativas protegidas por autenticação e confirmação de permissão ativa no Firestore.

**Ativação do cadastro:** consulte [o guia de Firebase, OAuth, App Check e backend](docs/ativacao-cadastro-firebase.md). Os arquivos locais estão preparados, mas regras e funções precisam ser publicados e os provedores precisam ser configurados. As telas de termos e privacidade contêm minutas para revisão antes da abertura pública dos cadastros.

## Inicialização no Android

A etapa nativa usa fundo azul escuro e ícone transparente até o primeiro quadro do Flutter. Em seguida, a tela com a logo Royal Clean e a mensagem “Inicializando ambiente...” direciona à página inicial pública após três segundos. A prévia não depende de login nem do sucesso da inicialização do Firebase. O botão Login abre a página de autenticação existente.

O ícone instalado no dispositivo permanece independente da tela de abertura.

## Prévia pública

A vitrine usa dados locais em `lib/presentation_royal_clean/preview/preview_content_royal_clean.dart`. Produtos, embalagens e notícias são demonstrações, sem vínculo com o catálogo do Bling e sem publicação administrativa implementada nesta etapa.

As imagens estão em `assets/preview/`; os prompts e a origem estão em `docs/preview-images.md`.

Validação do fluxo, filtros, detalhes e layout: `flutter test test/preview_navigation_test.dart`.

## Firebase

O aplicativo Android está configurado para o projeto **royal-clean-fire**, com o pacote `com.example.royal_clean`. As opções de `lib/firebase_options.dart` e o arquivo `android/app/google-services.json` usam os identificadores oficiais do arquivo baixado do Firebase. O projeto padrão da CLI também está definido em `.firebaserc`.

As outras plataformas ainda precisam ser cadastradas no novo projeto e configuradas pelo FlutterFire antes de serem executadas. Nenhuma plataforma mantém conexão com o Firebase anterior. Os identificadores de bundle Apple legados devem ser revisados ao preparar essas plataformas.

A troca de configuração não migra usuários ou dados. O login administrativo utiliza a conta do Authentication do novo projeto e o documento `admin/{UID}` com `email`, `eAdministrador: true` e `ativo: true`. As regras do Firestore precisam permitir a leitura autorizada desse documento; a configuração do projeto, sozinha, não libera esse acesso.

As regras estão em `firestore.rules`, com instruções de publicação e contratos dos documentos em `docs/firestore-rules.md`. Testes de segurança locais: `cd security-tests`, `npm ci` e `npm test`. A suíte usa exclusivamente um projeto fictício no emulador e não publica regras no Firebase real.

Home, controle de acesso, criação, consulta e detalhes dos convites usam `AdminRouteGuardRoyalClean`. A interface só é construída após confirmação do documento administrativo pelo servidor, sem aceitar apenas cache local. Mudanças de sessão, revogação no documento e falhas de autorização ocultam o conteúdo protegido. O botão Controle de regras e sua rota foram retirados da navegação; sair da conta retorna à prévia pública. As regras publicadas do Firestore continuam sendo necessárias para proteger os dados no servidor.
