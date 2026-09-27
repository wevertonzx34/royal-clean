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

## Clientes e fornecedores

Na tela Dados do Bling, a opção Clientes e fornecedores consulta GET /contatos
com criterio=1 (Todos), pagina e limite=25. A pesquisa usa o parâmetro pesquisa
para nome, CPF/CNPJ, fantasia, e-mail ou código. Não aplica período de emissão.
Próxima/Anterior percorrem os cadastros; Atualizar do Bling consulta a página
atual novamente. Não existe sincronização contínua nesta etapa.

Somente administradores autenticados e verificados consultam essa opção pelo
backend com App Check. Os registros retornados contêm id, nome, código,
situação, documento e telefones; campos extras são descartados. A cópia em
bling_private_contacts é privada e atualizada por id apenas nas páginas lidas.
Nenhum contato cria usuário, valida posse de CNPJ ou publica em public_partners.
A futura publicação de lojas depende do fluxo de cadastro e validação no app.
O retorno de listagem não identifica a classificação cliente/fornecedor;
não inferir essa classificação a partir do documento ou nome.

Escopo necessário: Clientes e Fornecedores — visualização. Em caso de 403,
habilitar esse escopo no aplicativo Bling e renovar a autorização pela tela
Integração Bling. Não são necessárias permissões de edição ou exclusão.

Contrato: https://developer.bling.com.br/referencia, GET /contatos,
ContatosDadosBaseDTO. Os testes usam contatos fictícios.

## Visão geral administrativa

O painel usa `blingReadData` com kind=dashboard, validando administrador e
App Check como as demais consultas. Os cálculos ocorrem no servidor sobre as
coleções privadas, com projeção só dos campos necessários; nenhum documento,
nome de contato ou telefone é retornado nos gráficos.

- Produtos/Contatos: quantidade por situação da última versão consultada de
  cada id. Sem datas históricas de cadastro ou movimentos, mostram posição atual.
- Pedidos: quantidade por data do pedido; valor = soma dos totais disponíveis,
  arredondados em centavos, em todas as situações. Não representa recebimentos
  ou faturamento fiscal. Valores ausentes são sinalizados.
- Notas: quantidade por emissão e faturamento nominal de NF autorizadas (5/6), usando valorNota obtido no
  detalhe da NF-e. Autorizadas (5/6) e canceladas (2) continuam disponíveis.
- Diário: semana atual; semanal: mês atual; mensal: trimestre atual;
  trimestral: semestre atual; semestral: ano atual; anual: ano atual mais
  valores de registros com datas futuras, separados e sem projeções.
  O intervalo atual termina hoje no calendário America/Sao_Paulo.
- Contatos: Clientes e Fornecedores vêm de tiposContato do detalhe, resolvido
  com /contatos/tipos. Ausência de tipo aparece como Sem classificação.
- Pedidos: Entrada = Em aberto, Em andamento ou Verificado; Saída = Atendido
  ou Entregue; Atrasado = Entrada com dataPrevista anterior a hoje;
  Cancelado = situação Cancelado; Retornos = Devolvido, Retornado ou Em devolução.
  Saída não comprova entrega física. Quantidade e valor permanecem juntos.
  Situações personalizadas desconhecidas não são classificadas automaticamente.
- Leitura /situacoes/{id} retornou 403 em 26/09/2026. Liberar leitura de
  Situações / Gerenciador de transições e renovar OAuth para habilitar a
  classificação real dos pedidos. O painel sinaliza essa pendência.

Detalhes são enriquecidos em lotes de até 10, com cache de uma hora,
limite de duração e até 6 lotes por atualização de categoria. Somente campos
necessários são persistidos; nenhum XML, CPF ou payload integral é armazenado
nesse enriquecimento. Valores ausentes são sinalizados e nunca estimados.
A base é sempre identificada como parcial: somente páginas já consultadas.
O espelho substitui cada registro por id, evitando contagem duplicada após
reconsultas. O resumo lê no máximo 5.000 registros por categoria e sinaliza
truncamento se ultrapassado. Não comprova cobertura integral da conta Bling nem
remove registros por ausência numa página. Canceladas entram quando consultadas.
Após uma consulta bem-sucedida no app, o painel recalcula automaticamente a base;
o botão Atualizar resumo também completa detalhes pendentes. Abra Dados do Bling para renovar
dados na origem. A data exibida é a consulta mais recente; os registros podem
ter sido atualizados em momentos diferentes. A tag stable-2026-09-26 continua
preservando a versão anterior e não foi movida.

## Referências da API

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

26/09/2026 — atualização de valores e filtros da Visão geral:
62 testes Flutter, 19 unitários e 71 de backend/regras aprovados; análise sem
problemas. blingReadData publicado e APK instalado/executado no Moto G32.
Validação na tela: 27 notas consultadas, R$ 21.968,24 no trimestre corrente.
Esse total refere-se à base parcial consultada, não a toda a conta do Bling.
Situações dos pedidos ainda dependem da permissão descrita acima.
26/09/2026 — categorias fiscais e posição do resumo:
Notas: Faturamento, Quantidade, Autorizadas, Canceladas, Enviadas, Pagas,
Pendentes. Faturamento soma valorNota apenas nas situações 5/6; não representa
receita líquida nem recebimento. Quantidade considera todas as notas. Autorizadas
inclui DANFE emitida (6). Enviadas representa situações de transmissão SEFAZ
3/4/5/6/8/9/10/11, sem comprovar envio por e-mail. Pendentes é situação fiscal 1.
Pagas é apresentada como indisponível, sem gráfico zero: ainda não há conciliação
implementada por NF. A leitura financeira real retornou HTTP 200, cinco contas
em aberto vinculadas a vendas; isso não prova a quitação de nenhuma NF.
O resumo financeiro foi movido abaixo de Última consulta em Notas/Pedidos,
para todos os períodos e estilos. Base parcial e valores ausentes permanecem
explícitos. A aprovação de testes não atesta cobertura integral da conta Bling.

26/09/2026 — Enviadas renomeada para Entregues por solicitação do usuário.
Os cálculos fiscais anteriores foram preservados. A tela e a ajuda esclarecem
que o indicador ainda representa situações da SEFAZ, sem confirmação logística
de entrega ao cliente. Análise limpa e testes existentes do painel aprovados.

26/09/2026 — controles e atualização horária:
No topo: relógio, estilo e atualizar, nessa ordem. Ajuda permanece junto da
legenda do gráfico. Respostas por categoria/período/filtro são reutilizadas
em memória durante a sessão do painel, sem nova consulta ao trocar de estilo
ou revisitar uma combinação já carregada.
O painel ativo inicia um ciclo automático a cada hora. O mesmo ciclo roda ao
retomar o aplicativo se venceu uma hora; o Android não garante execução com
processo suspenso/encerrado. Não foi criado agendamento em nuvem.
Atualizar resumo inicia imediatamente as quatro categorias em sequência,
preservando a visualização atual. A primeira chamada busca até 100 itens da
listagem (pedidos/notas do ano corrente); os detalhes privados já conhecidos
são atualizados em até seis lotes de 10 por categoria, com duração limitada.
Registros adicionais exigem continuação pelas listas/atualização; a base segue
parcial e pendências são indicadas. O ciclo não exclui documentos por ausência
numa página e não altera registros na conta Bling.
refreshSince define o início do ciclo e ignora a validade de uma hora do cache
para o botão manual, sem repetir o mesmo lote. Produtos também atualizam sua
situação diretamente no Bling. Falhas preservam o snapshot anterior, com aviso.
Testados timer de uma hora, cache, ordem dos controles, atualização manual,
falha preservando os dados, permissões administrativas e espelho privado.
26/09/2026 — catálogo completo de produtos:
Produtos agora usa GET /produtos com criterio=5 (Todos), tipo=T, limite=100 e
pagina crescente até a página final. A lista administrativa também usa Todos,
com situação Ativo/Inativo/Excluído explícita. Pedidos/Notas/Contatos mantêm o
escopo anterior; esta atualização não anuncia cobertura integral desses grupos.
IDs Bling e códigos SKU originais são preservados. Nenhum produto é criado ou
alterado na conta Bling. O espelho privado guarda nome, código, preço, unidade,
situação e saldo disponível na listagem, para futura auditoria autorizada.
Duas áreas privadas bling_catalog_snapshots/a|b/products alternam as gerações.
A referência integrations_private/bling_product_catalog.complete e os contadores
só mudam após terminar todas as páginas. Auditorias futuras devem usar o slot
completo e filtrar catalogRun pelo runId ativo; o espelho legado pode conter
histórico. Excluídos permanecem arquivados, fora do total de catálogo atual.
Cada lote possui lease e conferência de administrador; falhas retomam pela
página persistida, sem duplicar IDs nem publicar total incompleto. Ciclos grandes
continuam em chamadas limitadas por duração; pendência nunca é anunciada como
completa. O total de produtos usa contadores do catálogo, sem corte de 5.000.
Novos cadastros entram na atualização manual/horária já implementada enquanto
o painel está ativo ou na retomada vencida. Não há webhook nem job em nuvem.
Consulta real da API: 6 páginas, 539 IDs únicos — 426 ativos, 1 inativo e 112
excluídos. Catálogo atual: 427; barra Ativos: 426, correspondente ao filtro da
imagem enviada. A comparação entre telas deve considerar os mesmos filtros.
Validação: 73 testes backend/regras, 20 unitários e testes Flutter direcionados
aprovados, incluindo retomada após falha, SKU com zeros iniciais e proteção das
subcoleções contra leitura/escrita direta por qualquer cliente.
26/09/2026 — sincronização automática no servidor e três indicadores:
Visão geral mantém Produtos, Notas e Contatos. Pedidos foi retirado desse painel;
a consulta administrativa e os dados históricos de pedidos foram preservados.
blingScheduledSync usa Cloud Scheduler a cada 60 minutos, com autenticação IAM,
lease contra sobreposição, validação do administrador que conectou o Bling e
renovação OAuth no servidor. Continua funcionando com o aplicativo fechado.
Atualizar resumo continua disponível, sem exigir espera pelo próximo agendamento.
Produtos usa paginação completa; contatos usam criterio=1 e detalhes de tipos;
notas de saída usam todas as páginas sem restrição anual na importação e uma
segunda passagem com situacao=2, pois o Bling omite canceladas por padrão.
Notas e contatos também usam duas gerações privadas, publicadas somente após
a conclusão. Os gráficos leem a geração completa; falhas preservam a anterior.
As novas notas passam a compor quantidade e, quando fiscalmente autorizadas,
o faturamento pelo valorNota original. Pedidos sem NF não entram em Notas.
Cada grupo tem orçamento de execução; catálogos grandes retomam a paginação
persistida no próximo ciclo. Não há promessa de atualização instantânea nem
publicação de resultados incompletos como completos. Pagamento e entrega física
continuam dependendo de integração específica, sem inferência pelo status fiscal.
O processamento de notas e contatos usa páginas de 100, detalhes em lotes de 6,
cursor persistido dentro da página e deduplicação por ID. A API foi observada
retornando 102 linhas em uma página solicitada com limite 100; o cursor tolera
esse comportamento e não confunde linhas repetidas com novos registros.
Chamadas dos gráficos compartilham um reservador privado de cota com intervalos
de 450 ms; falhas temporárias são retomadas pelo job, sem reiniciar o catálogo.
Consulta de referência em produção: 724 notas únicas, incluindo 16 canceladas;
110 contatos. Os valores fiscais continuam sendo obtidos no detalhe de cada NF.
Validação final: ciclo em produção concluído para os três grupos; 427 produtos
atuais (426 A + 1 I), 112 excluídos separados, 724 notas únicas e 110 contatos.
Notas: 16 canceladas e nenhum valor ausente entre as NF elegíveis ao faturamento.
No Moto G32, confirmado “Bling • 724 registros • base completa”.
Abertura/troca de gráfico e atualização horária do cliente apenas leem o resumo
já sincronizado. Somente o botão manual solicita nova importação; o job em nuvem
mantém a importação horária mesmo com o app fechado. Durante uma importação,
a categoria visível consulta o resumo a cada 15 s, sem esconder o gráfico nem
reiniciar a importação. Ao concluir, essa consulta temporária para automaticamente.
Validação: 76 testes de backend/regras, 20 unitários, suíte Flutter completa
anterior com 66 testes e 12 testes direcionados finais das telas aprovados;
flutter analyze sem problemas. APK instalado e executado no Moto G32.

## Validação da instalação de teste e barra de status (26/09/2026)

- AndroidX core-splashscreen atualizado para 1.2.0 para preservar o contraste
  definido pelo Flutter ao sair da tela de abertura. Hora, bateria e notificações
  conferidas no Preview e nas telas escuras do Moto G32.
- Sete testes de barra de status/navegação aprovados; flutter analyze sem problemas.
- A instalação de desenvolvimento do Moto G32 foi autorizada no Firebase App Check.
  Validação aceita e gráficos conferidos no aparelho: 427 produtos, 724 notas e
  110 contatos. A exigência de App Check no servidor permanece ativa.
- Tokens de depuração, credenciais e dados privados não fazem parte deste backup.
  Após desinstalar o APK de desenvolvimento, pode ser necessário cadastrar o novo
  token da instalação no App Check. A configuração fica no Firebase, não no Git.
## Lista de NF-e por barra do gráfico

O resumo de Notas fornece `ranges` com início inclusivo e fim exclusivo por barra,
calculados junto com os indicadores no fuso America/Sao_Paulo. A lista usa esses
limites e a mesma classificação fiscal (`invoiceMetricKeys`). A barra Futuro do
anual começa no dia seguinte ao dia de referência; não é uma projeção.

A sincronização privada das notas (catálogo versão 3) conserva número, razão social
ou nome do destinatário, CPF/CNPJ e data/hora de emissão retornados pelo Bling.
Esses campos só são disponibilizados pela callable administrativa com App Check;
não são publicados na vitrine. Campos ausentes são apresentados como não informados.
O endpoint `invoiceCatalog` só fornece gerações completas com esses campos preparados.

A lista inteira é pré-carregada por páginas, em memória e vinculada ao administrador
confirmado. Atualiza a cada hora, no retorno após expirar e após atualização da base.
Falhas mantêm a última geração completa; logout ou perda de permissão limpa a cópia.
O primeiro carregamento de uma sessão requer conexão. A navegação posterior e as
categorias são filtradas localmente, sem uma nova consulta a cada barra.
Pagas continua indisponível até haver conciliação; Entregues mantém o significado
fiscal existente, sem representar confirmação de entrega física.
### Produtos: abertura pela barra

Cada barra de Produtos abre uma lista privada do catálogo completo da mesma sincronização usada no gráfico. Ativos (A), Inativos (I) e Outros (situações desconhecidas) preservam o código e ID do Bling; excluídos (E) ficam fora do gráfico e das listas. Nome, preço, unidade e saldo virtual são os dados informados pelo Bling.

A base atual é uma posição do catálogo, não um histórico de cadastro/estoque por data. Por isso os seis períodos mantêm a situação atual e a tela identifica a data/hora da sincronização. Nenhuma data de cadastro é inferida. Se uma geração mais recente chegar enquanto o gráfico estiver aberto, a lista informa a diferença.

O administrador recebe pré-carregamento em memória, atualização horária e preservação da última geração completa em caso de falha; os dados são descartados ao sair ou perder acesso administrativo. O endpoint productCatalog não consulta o Bling ao abrir cada barra e valida paginação e integridade da geração.
