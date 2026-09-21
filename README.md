# Royal Clean

Painel administrativo Royal Clean desenvolvido em Flutter, com Firebase Authentication e Cloud Firestore.

Versão atual: **1.0.3+4**, declarada em `pubspec.yaml`.

## Funcionalidades

- Login administrativo.
- Criação e consulta de convites para Cliente, Colaborador e Promotor.
- Compartilhamento de convites pelo WhatsApp.
- Interface do controle de regras, ainda pendente de implementação.

## Inicialização no Android

A etapa nativa usa fundo azul escuro e ícone transparente até o primeiro quadro do Flutter. Em seguida, a tela com a logo Royal Clean e a mensagem “Inicializando ambiente...” aguarda a inicialização do Firebase e direciona ao login.

O ícone instalado no dispositivo permanece independente da tela de abertura.

## Firebase

Os identificadores técnicos em `firebase.json`, `lib/firebase_options.dart` e `android/app/google-services.json` pertencem ao backend já configurado. Não devem ser renomeados como texto: uma troca de projeto exige configurar os aplicativos Firebase e migrar os dados e a autenticação. Os identificadores de bundle Apple existentes também estão vinculados a essa configuração.