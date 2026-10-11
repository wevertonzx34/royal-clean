# Royal Clean: institucional e aplicativo no mesmo domínio

Plano atualizado em 06/10/2026, substituindo a proposta de subdomínio institucional.

## Preparação DNS pelo Chrome conectado em 06/10/2026

### Publicação autorizada em 07/10/2026

O proprietário autorizou explicitamente a publicação e a troca da raiz.
O certificado aparece como concluído no Firebase. O canal revisado
`royal-site-review` foi promovido para `live` pelo wrapper seguro com
`hosting:clone royal-clean-fire:royal-site-review royal-clean-fire:live`.
URL permanente: `https://royal-clean-fire.web.app/`.
O destino `199.36.158.100` responde HTTP 200 em HTTPS para o domínio real,
com verificação TLS habilitada, usando curl `--resolve` antes da troca DNS.
O painel Hostinger passou a renderizar em branco; a alteração de DNS
permanece pendente. Nenhum registro de tráfego foi alterado nessa etapa.

- Propriedade confirmada no Firebase: etapa “Preparar o domínio” concluída.
- Adicionado TXT `_acme-challenge` com o valor exato do console
  `sxI-mMsR_jC656iDBJIcCUGUpv1jEg4CijZadKSu4c4`, TTL 300.
- Registro confirmado no servidor autoritativo da Hostinger e no resolvedor Google.
- Exportação completa do painel guardada em `docs/hosting-dns-before-switch.zone`.
  Inclui ALIAS raiz, www, MX, SPF, DKIM, DMARC e NS; preservados.
- Certificado ainda aguardava reconhecimento pelo Firebase na última consulta.
- Console mostra A de destino `199.36.158.100`; a raiz atual usa ALIAS
  `connect.hostinger.com`, que produz os A/AAAA do provedor atual. Na troca final,
  o ALIAS será substituído pelo A indicado, após aprovação específica.
- Hosting live e direcionamento do domínio ainda não alterados.
- QA da prévia HTTPS repetido com sucesso em desktop, tablet e celular.
- `/app/` ainda é prévia visual; App Check Web permanece pendente.

## Endereços finais

Atualização em 07/10/2026: por decisão do proprietário, o domínio voltou ao
site original do Hostinger Website Builder. Removido A raiz `199.36.158.100`
e restaurado ALIAS `@` para `connect.hostinger.com`, TTL 300. CNAME www e
registros de e-mail preservados. HTTP 200 confirmado no servidor hcdn com
`X-Powered-By: HostingerWebsiteBuilder`. Validação HTTPS ainda pendente na
primeira consulta após a troca. A cópia Firebase permanece preservada.

Prévia de revisão publicada e validada em HTTPS:
[institucional](https://royal-clean-fire--royal-site-review-ooreihya.web.app/)
e [aplicativo](https://royal-clean-fire--royal-site-review-ooreihya.web.app/app/).
Expira em 13/10/2026. O domínio principal e o Hosting live continuam sem troca.

| Endereço | Conteúdo |
| --- | --- |
| `https://royalcleandistribuidora.com.br/` | Página institucional HTML |
| `/segmentos`, `/sobre`, `/contato` | Páginas institucionais existentes |
| `/app/` | Aplicativo Flutter Web |
| `www.royalcleandistribuidora.com.br` | Redirecionamento ao domínio principal, a configurar no console |

O botão “Acessar Royal Clean” na navegação institucional aponta para `/app/`.
O aplicativo tem “Site institucional” no rodapé, apontando para `/` na mesma aba.
O domínio permanece registrado e administrado na Hostinger. A hospedagem do
conteúdo passa ao Firebase Hosting do projeto `royal-clean-fire` após a aprovação
da troca. Não é necessário criar um subdomínio para o aplicativo ou institucional.

## Implementação

As páginas do Builder foram convertidas em páginas estáticas em
`web_institutional/`, preservando os textos, cores, fontes, logo e disposição
originais. Imagens, CSS e fontes foram copiados para recursos locais. Os scripts,
telemetria e configuração de execução do Builder foram retirados. O menu móvel
tem implementação local com suporte a teclado e Escape. As animações de entrada
que dependiam do Builder foram retiradas para o conteúdo permanecer visível.

`tool/import_institutional.cjs` permite uma nova captura das quatro páginas
enquanto o original ainda está na Hostinger. **Após a troca de DNS, não executar
esse importador apontando ao mesmo domínio como se ainda fosse a fonte original.**
As fontes públicas capturadas estão em `.dart_tool`, e o inventário dos 30
recursos localizados está em `docs/institutional-import-assets.json`.

O HTML é parte do mesmo repositório do aplicativo. Ele não precisa inicializar
Flutter, Firebase Auth ou App Check para exibir a página de entrada. O aplicativo
continua reutilizando o código Dart original, com configuração específica Web.
Android, Functions e regras de acesso não foram modificados nesta atualização.

O formulário antigo dependia do serviço da Hostinger. Nesta cópia o botão
“Preparar e-mail” abre uma mensagem para revisão e envio no aplicativo de e-mail
do visitante. Não envia por um backend nem mostra confirmação fictícia de envio.
Sem JavaScript, esse botão permanece desativado, e os links de e-mail continuam
disponíveis. O proprietário confirmou o e-mail
`royalcleandistribuidora@outlook.com` e o WhatsApp comercial `(62) 98260-6133`.
Eles substituem os contatos anteriores; os botões WhatsApp usam o número
internacional `5562982606133` no link oficial `wa.me`.

## Compilação e Hosting

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_web.ps1 -VisualPreview
powershell -NoProfile -ExecutionPolicy Bypass -File tool/deploy_web_preview.ps1
```

O Flutter é compilado com `--base-href /app/ --no-web-resources-cdn`.
`tool/assemble_web_site.cjs` reúne o institucional na raiz e os artefatos Flutter
em `build/site/app/`. O diretório público configurado é `build/site`; fontes e
documentação não são publicadas. Compilações anteriores desse diretório gerado
são guardadas sob `build/site-previous-*` para facilitar retorno, sem apagar fontes.

As rotas institucionais usam `cleanUrls`. `/app` e `/app/**` têm fallback SPA ao
HTML Flutter; a base de recursos permanece `/app/`. Os caches são revalidáveis, com
cabeçalhos de segurança. A publicação temporária usa `firebase_safe.cjs`, confere
o hash do bundle e inspeciona os artefatos antes de publicar.

A interface Flutter segue em modo de prévia visual, identificada por aviso.
Login, dados e uploads ainda precisam do cadastro reCAPTCHA Enterprise/App Check
Web. Isso não impede a página institucional estática de ser servida em produção.
O build funcional deve ser feito sem `-VisualPreview`, com a chave pública Web
configurada e o domínio autorizado no Auth e na chave Enterprise.

## Conectar o domínio sem substituir a página antes da revisão

1. Firebase Console → projeto **royal-clean-fire** → **Hosting**, não App Hosting.
   No site `royal-clean-fire`, clicar **Adicionar domínio personalizado**.
2. Informar somente `royalcleandistribuidora.com.br`, sem `http://` ou caminho.
   Não marcar redirecionamento para esse domínio principal. Avançar.
3. Se o assistente mostrar verificação de propriedade, copiar exatamente os
   registros indicados, incluindo tipo, nome e valor. No hPanel da Hostinger,
   entrar no domínio → DNS/Nameservers → gerenciamento da zona DNS. Adicionar
   o TXT de verificação como **novo registro**, preservando SPF e demais TXT.
   A tabela exata ainda precisa ser fornecida pelo assistente; não há valores
   inventados neste documento.
4. No Firebase, verificar a propriedade depois de o registro propagar.
   Escolher **Configuração avançada** quando aparecer a seleção: o domínio já
   recebe tráfego em outro provedor.
5. Na etapa **Preparar domínio**, escolher o desafio de certificado por **DNS**.
   Copiar nome e valor do TXT ACME apresentado e adicioná-lo na Hostinger.
   Isso evita precisar inserir arquivos de validação no Website Builder.
   Seguir também eventual instrução de CAA exibida pelo Firebase, sem apagar
   registros por suposição. Não mudar A, AAAA ou www nessa preparação.
6. Aguardar a validação e preparação do certificado indicadas no assistente.
   Revisar a cópia institucional e o aplicativo no canal temporário.
   Antes da troca, exportar a zona DNS completa no painel e conferir MX, SPF,
   DKIM e DMARC. O snapshot público anterior não é exportação completa.
7. Apresentar a tabela final de mudanças e obter a autorização específica para
   a troca. Publicar então os artefatos aprovados em Hosting live, usando
   `node tool/firebase_safe.cjs deploy --only hosting --project royal-clean-fire`.
   Não executar deploy geral de Functions, Firestore ou Storage.
8. Na etapa **Direcionar ao Hosting**, aplicar **somente** os registros de tráfego
   exatos fornecidos pelo Firebase. Substituir os A/AAAA/CNAME conflitantes do
   site conforme as instruções, preservando os registros de e-mail e os NS.
   Não cancelar, excluir ou alterar o domínio do site no Builder.
9. Adicionar `www.royalcleandistribuidora.com.br` como outro domínio no mesmo
   site Hosting. Para ele, marcar o redirecionamento ao domínio principal.
   Usar os registros exatos apresentados para www; manter o certificado válido.
10. Conferir HTTP → HTTPS, raiz institucional, /app/, links e www em dispositivos
    e redes diferentes. Conservar a cópia original na Hostinger e a zona anterior
    durante a transição para possibilitar retorno.

O fluxo avançado prepara a propriedade e o certificado antes do direcionamento
do tráfego. Isso reduz o risco de interrupção, mas nenhum serviço pode prometer
disponibilidade absoluta. Fonte: [Firebase Hosting — domínio personalizado](https://firebase.google.com/docs/hosting/custom-domain).

## Testes

- Release Flutter em `/app/` compilado com dry run Wasm aprovado.
- Arquivos Dart de configuração e atalho analisados sem problemas.
- Browser QA isolado em Chrome: 1440 × 1000, 768 × 1024 e 375 × 812; conteúdo
  visível, sem overflow horizontal, imagens carregadas e nenhuma dependência
  de rede externa para os recursos institucionais.
- Menu móvel abre e fecha com Escape; “Acessar Royal Clean” navega ao mesmo
  origin em `/app/`, e o Flutter renderiza nas três dimensões.
- Páginas Segmentos, Sobre e Contato abrem com HTTP 200 e acesso ao aplicativo.
- O formulário valida campos obrigatórios e explicita o preparo de e-mail.
  Não foi enviada mensagem nem SMS, nem alterado dado real.
- 111 arquivos preparados foram inspecionados sem encontrar segredos;
  o Hosting exclui os artefatos definidos na lista de ignore.
- Capturas de revisão e relatório em `docs/web-qa/`.
- A mesma suíte passou no endereço HTTPS publicado nas três dimensões. `/app`
  e `/app/` retornam 200, sem ciclo de redirecionamento. Os contatos confirmados
  foram conferidos no HTML servido. Evidências de rotas e MIME estão em
  `docs/web-qa/hosting-http-report.json`.

O Chrome de testes usa perfil isolado. Não houve acesso às abas autenticadas do
proprietário: a ferramenta de controle não disponibilizou navegadores conectados.
Por isso, as etapas do console são conduzidas pelo proprietário, com auxílio
baseado nos registros e mensagens realmente apresentados.
