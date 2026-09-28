# Cadastro público de consumidores

A conta começa como `consumer` / pessoa física após verificar o e-mail e aceitar os termos. Convite é opcional; o fluxo de Mestre continua validando o convite no servidor. Nenhum campo enviado pelo aplicativo concede acesso administrativo.

`personal_data/{uid}` armazena os dados privados. `updateMyData` aceita somente campos editáveis, valida documentos e conserva as permissões atuais. Pessoa jurídica exige CNPJ e razão social. Formato e dígitos de CPF/CNPJ não comprovam titularidade nem situação fiscal. Nenhum benefício comercial ou publicação na vitrine é automático.

O telefone só é marcado como confirmado quando coincide com o telefone verificado no Firebase Authentication. O aplicativo atualiza o telefone da conta atual usando a credencial SMS, sem criar ou trocar a conta. O usuário deve salvar o formulário após confirmar o telefone.

As imagens são selecionadas na galeria, redimensionadas e convertidas em PNG. Apenas o próprio usuário ativo e com e-mail verificado acessa `profile_media/{uid}/photo.png` e `logo.png`; tamanho máximo de 2 MiB. O aplicativo não publica URLs de download. Remover uma imagem do formulário retira sua referência ao salvar; o objeto privado pode permanecer armazenado até ser substituído ou excluído em um fluxo de exclusão da conta.

## Publicação

- Confirmar o bucket padrão e preservar quaisquer regras de armazenamento já utilizadas antes de publicar `storage.rules`.
- Publicar `registerAccount` e `updateMyData`, além das regras de Storage.
- Ativar o provedor Telefone no Firebase Authentication e permitir SMS para o Brasil. Conferir as assinaturas SHA do Android e a configuração de verificação do aplicativo.
- Testar com usuário comum: cadastro sem convite, verificação de e-mail, edição PF/PJ e tentativa de acessar administração.
- Testar SMS com número de teste configurado no Firebase antes da validação de entrega real.

A política de privacidade existente ainda requer revisão dos dados de contato e retenção antes de abertura pública, conforme já indicado no próprio documento. Os fluxos aqui permitem testes de cadastro e permissões; não estabelecem vantagens ou descontos.

## Validação local

`flutter analyze`, `flutter test`, `node --test functions/test/*.test.js` e `npm --prefix security-tests test`.
A suíte de segurança usa somente Auth, Firestore e Storage locais do projeto fictício `demo-royal-clean`. Em Windows, use o Java 21+ do Android Studio em `JAVA_HOME`.

## Estado publicado em 27/09/2026

- `registerAccount` e `updateMyData` publicados e confirmados como ACTIVE em `southamerica-east1`; chamadas sem autenticação retornaram HTTP 401.
- Bucket `royal-clean-fire.firebasestorage.app` criado em `SOUTHAMERICA-EAST1`, com regras privadas publicadas e comparadas com o arquivo local.
- Permissão de consulta entre Storage Rules e Firestore atribuída exclusivamente ao agente de serviço do Firebase Storage.
- Provedor Telefone ativado e SMS permitido para BR. Assinaturas SHA-1/SHA-256 já cadastradas no app Android.
- Regras Firestore de produção conferidas como idênticas às locais; nenhuma ampliação de acesso ao Bling ou administração.
- 88 testes anteriores do Flutter + 2 testes novos de perfil, 36 testes unitários do backend e 78 de integração/regras aprovados. Análise estática sem problemas.
- Run realizado no Moto G32; conferidas as telas PF/PJ. Entrega real de e-mail/SMS e envio de foto pessoal dependem da validação com os dados do usuário e não foram simulados como concluídos.
