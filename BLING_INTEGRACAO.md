# Royal Clean — integração Bling, etapa 1

## Situação e responsabilidade

Projeto Firebase: `royal-clean-fire`. Região: `southamerica-east1`.
Em 25/09/2026, as três funções foram publicadas. O callback retornou HTTP 200
sem parâmetros e HTTP 400 para um retorno inválido. A tela foi instalada no Moto G32.
Credenciais e autorização real confirmadas em 25/09/2026: consulta de produtos
HTTP 200; pedidos HTTP 403 insufficient_scope até habilitar a nova permissão.
Atualização: consulta administrativa de produtos e pedidos por período via
`blingReadData`. Cada página de até 25 registros atualiza um espelho privado.
Renovação automática dos tokens sob demanda, com exclusão mútua transacional.
Não cria pedidos nem modifica estoque no Bling. Não publica preços na loja.
Atualização contínua por agenda/webhooks, movimentações de estoque, faturamento
fiscal e checkout permanecem nas etapas seguintes.

A empresa e as contas devem continuar sob controle de responsáveis humanos.
Mantenha um proprietário e um substituto com contas individuais, autenticação
em duas etapas e recuperação documentada em um gerenciador de senhas da empresa.
Este arquivo documenta o procedimento, mas não contém senhas nem tokens.

## Código e segurança

- `functions/bling.js`: fluxo OAuth, leitura de credenciais e troca de código.
- `functions/index.js`: três funções novas, sem alterar as funções de cadastro.
- `blingConnectionStatus` e `blingBeginAuthorization`: exigem Firebase Auth,
  e-mail verificado, App Check e administrador ativo confirmado no servidor.
- `blingCallback`: endpoint HTTPS público, necessário para o retorno do Bling;
  valida estado aleatório, prazo de 10 minutos, uso único e cookie do navegador.
- `integrations_private/bling`: tokens acessíveis somente ao backend.
- `bling_oauth_sessions`: estado temporário, sem códigos OAuth persistidos.
- As regras existentes de negação padrão já impedem acesso do app a essas coleções.
  Não é preciso liberar leitura desses documentos no console Firestore.
- Não imprimir tokens/códigos, não copiar chaves para Dart, GitHub ou mensagens.
- Renovar autorização pede confirmação e só substitui a conexão depois do OAuth
  validado. O admin deve autorizar a mesma empresa; não há identificação automática
  da empresa sem o escopo de dados básicos. Não usar para troca de empresa.
- Falha incerta ao renovar tokens exige nova autorização; tokens antigos nunca
  são repetidos após timeout. Se uma execução cair durante a renovação, usar
  Renovar autorização para recuperar o bloqueio, sem reutilizar refresh token.
- Tentativas abandonadas liberam nova autorização após 10 minutos. Registros de
  sessão concluída são apagados. Configure TTL em `bling_oauth_sessions.expiresAt`
  para limpeza física das tentativas abandonadas; a validade é aplicada mesmo sem TTL.

## 1. Publicar apenas as funções Bling

PowerShell em `C:\royal_clean`:

```powershell
.\security-tests\node_modules\.bin\firebase.cmd deploy --only functions:royal-clean-accounts:blingCallback,functions:royal-clean-accounts:blingBeginAuthorization,functions:royal-clean-accounts:blingConnectionStatus --project royal-clean-fire
```

O endpoint é implementado, mas só deve ser considerado disponível depois que o
deploy terminar e uma consulta HTTPS retornar a página Royal Clean com status 200:

```text
https://southamerica-east1-royal-clean-fire.cloudfunctions.net/blingCallback
```

A página sem parâmetros não autoriza nem consulta dados. O fluxo começa somente
pelo botão **Conectar ao Bling** no painel administrativo.

Nesta primeira publicação, o Firebase confirmou a criação das três funções, mas
informou que a política automática de limpeza dos artefatos de build ainda não foi
configurada. Isso não impediu a verificação HTTPS. Definir posteriormente a retenção
das imagens de build no Artifact Registry; não usar `--force` indiscriminadamente.

## 2. Concluir cadastro no Bling

1. Nome: Royal Clean. Categoria: Plataforma de e-commerce.
2. Apagar o texto de exemplo da descrição e inserir a descrição aprovada.
3. Colar a URL acima somente após confirmação do deploy.
4. Adicionar os escopos de consulta de produtos e estoque necessários. Conferir
   os nomes reais na lista antes de selecionar. Não habilitar exclusão, financeiro
   ou escrita em pedidos nesta primeira etapa.
5. Salvar os dados básicos. Abrir **Informações do app** para obter Client ID e
   Client Secret. Não publicar esses valores em capturas de tela ou no Git.

## 3. Gravar as credenciais com segurança

Execute no terminal e informe cada valor apenas quando a ferramenta solicitar:

```powershell
.\security-tests\node_modules\.bin\firebase.cmd functions:secrets:set BLING_CLIENT_ID --project royal-clean-fire
.\security-tests\node_modules\.bin\firebase.cmd functions:secrets:set BLING_CLIENT_SECRET --project royal-clean-fire
```

As credenciais são consultadas sob demanda no Secret Manager, permitindo publicar
o callback antes de obter as chaves do Bling. Não use valores fictícios para avançar.

No Google Cloud, **Secret Manager → cada um dos dois segredos → Permissões**,
conceda **Acessador de segredos do Secret Manager** à conta de serviço de execução
das funções Bling. A permissão deve ser em cada segredo, não em todo o projeto.
Confirme a identidade nas configurações das funções. Se estiver usando a identidade
padrão de segunda geração deste projeto, ela será:

```text
589116886810-compute@developer.gserviceaccount.com
```

Não conceder esse papel aos consumidores ou colaboradores do aplicativo.
Se o console pedir, habilitar a API Secret Manager no projeto `royal-clean-fire`.

## 4. Autorizar no aplicativo

1. Instalar a versão atual do app e entrar como admin com e-mail verificado.
2. Abrir **Painel administrativo → Integração Bling → Atualizar status**.
3. Quando aparecer **Pronto para autorizar**, tocar **Conectar ao Bling**.
4. O navegador abre o Bling. Conferir a empresa Royal Clean e os escopos antes de autorizar.
5. Voltar ao aplicativo e conferir **Autorização registrada**.
6. Não compartilhar a URL temporária de autorização nem abrir o retorno em outro navegador.

Se a autorização for abandonada, aguardar até 10 minutos para iniciar outra.
Se a permissão de admin for revogada durante o processo, a conexão é rejeitada.

## Consultar os dados reais no aplicativo

Painel administrativo → Integração Bling → Ver produtos e movimentações.
Produtos e Pedidos de venda são consultas reais, paginadas, sob demanda.
A soma de pedidos é apenas dos registros da página e não é faturamento fiscal.
Situações de pedidos aparecem pelo código retornado pelo Bling, sem inferir pago,
faturado ou cancelado. Clientes/documentos pessoais não são enviados ao app.
Os gráficos anteriores continuam demonstrativos, identificados como tal.

Para habilitar pedidos: Bling → cadastro Royal Clean → Dados básicos → escopos →
Pedidos de Venda (somente visualização) → salvar. A alteração de escopos revoga a
autorização anterior. No app: Integração Bling → Renovar autorização → autorizar a
mesma empresa no navegador → Atualizar status → Ver produtos e movimentações.
Nenhuma nova liberação das regras Firestore é necessária para as coleções
`bling_private_products` e `bling_private_sales`: acessadas apenas pelo backend,
com validação de admin, e-mail verificado e App Check em cada chamada.

Deploy desta etapa inclui `blingReadData`, `blingBeginAuthorization`,
`blingConnectionStatus` e `blingCallback`, somente no codebase royal-clean-accounts.

Diagnóstico no Moto G32 em 25/09/2026: a consulta estava sendo rejeitada com
“Verifique seu e-mail antes de continuar.” A tela agora oferece envio de verificação
por ação explícita do admin, recarrega o usuário e renova o ID token somente quando
a verificação estava pendente. Não forçar renovação em cada consulta: isso gerava
um ciclo de remontagem da tela protegida. E-mail e autorização já confirmados.

Próximas etapas: estoque por depósito e movimentações, publicação do catálogo
com revisão administrativa e webhooks autenticados.
Definir depósito e tabela de preços antes de publicar estoque/preço para clientes.
Tokens OAuth do Bling não se confundem com os tokens comerciais do Royal Clean.

## NF-e de saída

Em Dados do Bling, a aba Notas de saída consulta GET /nfe com tipo=1 fixo,
dataEmissaoInicial 00:00:00 e dataEmissaoFinal 23:59:59. Paginação de 25 notas.
Filtro padrão Não canceladas: o Bling omite canceladas sem situacao. Para consultar
cancelamentos, selecionar Cancelada (situacao=2). Nunca presumir exclusão por
ausência numa página. Cada consulta atualiza os registros retornados por id em
bling_private_invoices, sem acesso direto pelo cliente.
Exibe número, emissão, data de operação, situação e chave de acesso válida.
O contrato de listagem não contém o valor total; não inferir faturamento a partir
da lista. Não inclui emissão/cancelamento de notas, download XML/DANFE, consulta
de NFC-e/NFS-e ou atualização contínua por webhooks.

Permissão necessária: Bling → aplicativo Royal Clean → Dados básicos → escopos →
Notas Fiscais (visualização). Salvar e renovar autorização no aplicativo, mantendo
os escopos anteriores. Não habilitar edição, emissão ou exclusão.
Consulta real em 25/09/2026 retornou 403 insufficient_scope antes dessa liberação.

Contrato conferido em https://developer.bling.com.br/referencia (GET /nfe,
NotasFiscaisDadosBaseDTO), em 25/09/2026.

Itens da NF-e: pressionar e segurar a nota → Produtos (ou botão de opções).
Consulta GET /nfe/{idNotaFiscal} pelo backend, validando id e tipo=1.
Exibe código, descrição, quantidade, unidade, valor unitário e total originais
de cada item, além do valorNota e frete informados. Não substitui pelos preços
do catálogo nem infere pagamento. Dados pessoais do destinatário, XML e links
externos não são enviados ao cliente. Detalhes consultados sob demanda, sem
persistir o payload completo. Retorno à lista mantém período, filtro e página.
Consulta real confirmada em 25/09/2026: listagem e detalhe HTTP 200 após renovar
a autorização; exemplo NF-e 000847, 1 item, 8 CX, R$ 77 unitário, R$ 616 no item.

## Referências

- https://developer.bling.com.br/aplicativos
- https://developer.bling.com.br/migracao-jwt
- https://firebase.google.com/docs/functions/config-env

## Validação

25/09/2026: quatro funções publicadas; Moto G32 instalado via flutter run.
Lista real validada na tela (produtos, códigos, preços e saldo virtual). Aba de
pedidos confirma falta de escopo e orienta renovação, sem exibir totais fictícios.
66 testes de backend/regras, 7 unitários e 6 Flutter aprovados; análise limpa.
Consulta anônima à nova função retorna HTTP 401. Permissões IAM dos segredos
confirmadas para a identidade real das funções.

Os testes usam emuladores locais e credenciais fictícias. Aprovação desses testes
não significa que a conta real do Bling foi conectada. Essa confirmação depende
das credenciais, permissões do Secret Manager e autorização do proprietário.
