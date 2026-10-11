# Royal Clean Web — preparação e publicação

> Histórico do plano anterior. O plano vigente, solicitado posteriormente pelo
> proprietário, usa institucional em `/` e Flutter em `/app/`, no mesmo domínio.
> Consulte [web-mesmo-dominio.md](web-mesmo-dominio.md).

Auditoria em 06/10/2026. Projeto Firebase: `royal-clean-fire`. A troca do domínio
principal continua dependendo da autorização específica do proprietário.

## Diagnóstico e escopo

- A configuração original do Firebase rejeitava Web. Foi cadastrado o aplicativo
  `Royal Clean Web`, ID `1:589116886810:web:727e7e73d00f16d45ba6a3`, no mesmo projeto.
  A configuração Android foi mantida.
- Firebase Auth, Firestore, Storage, Functions, image_picker, url_launcher e
  shared_preferences possuem implementações Web nos pacotes instalados. Não foram
  encontrados imports `dart:io`, `dart:ffi`, `Image.file` ou `putFile` em `lib`.
- Google e Apple já usam popup na Web. O login por e-mail e a preferência de
  persistência já têm suporte Web. Provedores OAuth e domínios autorizados ainda
  precisam de validação no console e em uma sessão de teste autorizada.
- A confirmação de telefone usa `verifyPhoneNumber`; a versão instalada de
  firebase_auth_web implementa esse método com reCAPTCHA. Não foram enviados SMS.
- Uploads de perfil e catálogo usam bytes/`putData`. O acesso real às imagens
  remotas e CORS do bucket precisa ser validado no domínio de teste com App Check.
- Biometria e armazenamento de seu vínculo são limitados a Android/iOS.
  Notificações locais e push administrativo são limitados a Android. A Web
  conserva o painel de notificações existente; não foi criado push Web fictício.
- A apresentação existente usa restrições de largura e LayoutBuilder. Os valores
  de layout aprovados e os IDs existentes foram mantidos.
- Foram preservadas as alterações que já existiam no diretório, inclusive
  catálogo, estoque, functions, regras e testes de outros módulos.

## Arquivos da implementação Web

- `lib/firebase_options.dart`: opção Web obtida do Firebase; Android preservado.
- `lib/main.dart`: App Check Enterprise para Web antes dos serviços online;
  provedores nativos preservados; aviso explícito na prévia visual.
- `lib/core_royal_clean/services/web_configuration_royal_clean.dart`: configuração
  pública de compilação, bloqueio de inicialização sem App Check e URL institucional.
- `lib/presentation_royal_clean/shared/institutional_link_royal_clean.dart` e uma
  inserção no rodapé de `preview_page_royal_clean.dart`: atalho apenas na Web,
  com ID estável `web.institutional_link`. Fica oculto até confirmar o institucional.
- `firebase.json`: Hosting exclusivamente de `build/web`, fallback SPA, cabeçalhos
  de segurança e cache revalidável. Não publica fontes, Functions ou regras.
- `web/index.html`, `web/manifest.json`, favicon e ícones: idioma, cores e marca
  Royal Clean. Os ícones foram gerados do logo existente com configuração só Web
  em `tool/web_icons.yaml`, sem regenerar recursos Android.
- `tool/build_web.ps1` e `tool/deploy_web_preview.ps1`: compilação e publicação
  temporária, com inspeção de segredos dos artefatos e conferência do hash do bundle.

## Preservação do site atual

O GET HTTP do domínio retornou `generator=Hostinger AI Builder`, cabeçalho
`X-Powered-By: HostingerWebsiteBuilder`, servidor `hcdn` e recursos Zyro/Hostinger.
`www` aponta para `connect.hostinger.com`. Portanto, é um site do Builder,
não uma pasta HTML comprovadamente exportável. Uma cópia do HTML foi guardada
localmente em `.dart_tool/institutional-current.html` como evidência; ela **não é
backup completo** de páginas, assets, formulários ou configuração do Builder.

O caminho preferido é duplicar o site no próprio Builder e conectar a cópia a
`institucional.royalcleandistribuidora.com.br`, mantendo o original publicado.
Primeiro conferir no hPanel as opções do plano, cópia, formulários, integrações e
eventuais custos. Validar páginas, imagens, links, contatos e certificado HTTPS
da cópia antes de ativar o atalho ou trocar o principal.

A documentação da Hostinger indica que cada site do Builder tem um endereço e
que o fluxo de troca de domínio pode redefinir DNS e afetar e-mail. Não executar
esse fluxo no original sem verificar a alternativa de cópia e preservar a zona
e o serviço de e-mail. Nenhum domínio, DNS ou serviço Hostinger foi alterado.

Fontes: [subdomínio no Builder](https://support.hostinger.com/en/articles/6976680-how-to-connect-a-subdomain-to-hostinger-website-builder),
[troca de domínio](https://support.hostinger.com/en/articles/6807580-connecting-a-different-domain-to-your-existing-website).

## App Check e dependências externas

1. No Google Cloud do projeto, criar uma chave Web reCAPTCHA Enterprise baseada
   em pontuação, com verificação de domínio ativa. Não usar chave falsa ou debug
   em produção. Cadastrar os domínios de teste e de produção realmente usados.
2. Registrar essa chave no App Check do aplicativo Web cadastrado. Manter os
   provedores Android e a aplicação das proteções atuais.
3. Disponibilizar localmente a chave pública na variável
   `ROYAL_WEB_APP_CHECK_SITE_KEY`; não é um segredo de backend.
4. Validar obtenção de token sem registrar seu conteúdo, leituras permitidas,
   negativas de acesso, sessão, login e uploads. Não recriar dados reais.

O modo `-VisualPreview` não inicializa Firebase: exibe a interface existente com
aviso de serviços indisponíveis. Não comprova autenticação, dados ou uploads.
A chave OpenAI e o Secret Manager não foram alterados.

Fonte: [App Check Enterprise](https://firebase.google.com/docs/app-check/flutter/recaptcha-enterprise-provider).

## Compilar e publicar a prévia

Executar no diretório do projeto, com Flutter disponível. O script também
reconhece o SDK instalado em `C:\dev\flutter`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_web.ps1 -VisualPreview
powershell -NoProfile -ExecutionPolicy Bypass -File tool/deploy_web_preview.ps1
```

Para a versão funcional, executar o build sem `-VisualPreview`, após configurar
a chave pública. Adicionar `-InstitutionalVerified` somente quando o endereço
institucional estiver efetivamente preservado e validado em HTTPS. As variáveis
`ROYAL_LEGAL_ENTITY` e `ROYAL_LEGAL_CONTACT` passam ao build se já configuradas;
o texto original ainda contém atendimento pendente quando elas não são definidas.

O canal temporário expira em sete dias e usa `--no-authorized-domains`, evitando
alterações automáticas no Auth durante a prévia visual. Para testar OAuth na
versão funcional, cadastrar explicitamente o hostname exato desse canal no Auth
e na chave Enterprise. Não usar `deploy` geral nem clonar para `live` nesta etapa.

## DNS e troca final

`docs/web-dns-before.json` registra uma consulta pública parcial da zona atual,
incluindo MX Hostinger, SPF, DMARC, NS e www. Não substitui exportação do hPanel;
seletores DKIM e CAA ainda precisam ser conferidos. IPs do CDN podem variar.

Ainda não foram obtidos registros de migração gerados pelo Firebase. Nenhum IP,
TXT de propriedade ou desafio de certificado foi inventado. Com acesso ao console:

1. Abrir Hosting do site `royal-clean-fire`, cadastrar o domínio principal pelo
   fluxo de migração avançada e registrar exatamente os valores apresentados.
2. Preparar `www` como domínio de redirecionamento para o principal no Hosting;
   não usar rewrite SPA como substituto de redirecionamento entre hostnames.
3. Separar registros de verificação dos registros de tráfego, preservar MX,
   SPF, DKIM e DMARC, e revisar A/AAAA/CAA conforme o assistente do Firebase.
4. Apresentar ao proprietário a prévia funcional validada, o institucional
   preservado e a tabela exata de mudanças antes da autorização da troca.
5. Só então publicar Hosting live e aplicar a mudança de tráfego autorizada;
   validar HTTPS, www, navegação, login e imagens; conservar plano de retorno.

Fonte: [domínio personalizado no Firebase Hosting](https://firebase.google.com/docs/hosting/custom-domain).

## Validação realizada

- Compilação `flutter build web --release` concluída; dry run Wasm aprovado.
- Análise dos arquivos Dart centrais alterados: sem problemas.
- 19 testes existentes de navegação pública, sessão e biometria passaram;
  incluem renderização em 320 e 1200 pixels sem overflow.
- O build de produção sem chave Enterprise foi bloqueado como esperado.
- Teste adicional do layout em 768 × 1024, junto de 320 × 640 e 1200 × 900:
  aprovado. A cobertura existente de layout recebeu essa dimensão de tablet.
- A suíte em Chrome ficou presa no carregamento, sem executar testes, e foi
  interrompida. Não é aprovação nem diagnóstico de falha do app. A validação
  interativa do release no navegador ainda está pendente.
- 72 arquivos de build inspecionados: nenhum segredo encontrado. O Hosting
  publicou 71 arquivos, respeitando a lista de exclusões.
- Prévia visual publicada em
  [Royal Clean Web — revisão](https://royal-clean-fire--royal-web-review-9eij7ads.web.app),
  com expiração em 13/10/2026. Canal `royal-web-review`; não substituiu `live`.
- Validação HTTPS: HTML, bootstrap, JavaScript, manifest, ícone e logo com HTTP
  200 e MIME apropriado; bundle remoto idêntico ao local; rotas com fallback SPA;
  cache e cabeçalhos conforme configuração. As URLs de fontes `lib`, `functions`
  e `.git` retornam somente o HTML da SPA, não os arquivos do repositório.
  Evidências em `docs/web-preview-http-validation.json`.
- A consulta posterior de canais confirmou que `live` conserva a publicação de
  21/09/2026. Nenhum DNS foi alterado. O domínio institucional ainda não está
  preservado em outro endereço e seu botão permanece oculto.
- HTTPS da página atual sofreu reset de conexão neste ambiente. Sua identificação
  veio da resposta HTTP pública; seu HTTPS precisa ser revalidado no navegador,
  sem ignorar erros de certificado.

## Pendências para liberar o domínio

Acesso ao hPanel do site Builder e ao console Firebase/Google Cloud em sessão
autenticada; chave e registro App Check Web; cópia institucional em HTTPS;
validação funcional no canal temporário; registros DNS exatos do assistente;
autorização final específica. Não enviar senhas, tokens ou secrets pelo chat.
