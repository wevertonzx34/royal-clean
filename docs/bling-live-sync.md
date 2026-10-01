# Sincronização e notificações do Bling

## Ativação

1. No aplicativo cadastrado no Bling, autorizar visualização de **Propostas Comerciais** e **Visualizar os dados básicos da empresa**, além dos escopos de produtos, notas e contatos já usados. Renovar a autorização OAuth pelo app Royal Clean após alterar escopos.
2. Em **Webhooks**, cadastrar `https://southamerica-east1-royal-clean-fire.cloudfunctions.net/blingWebhook`, versão v1, eventos **product** e **invoice**, ações created/updated/deleted. Salvar/ativar. Não selecionar recursos não suportados por esse receptor.
3. A primeira consulta obtém o identificador da empresa autorizada. Até essa identificação, o receptor responde 503 para que o Bling repita o evento; outra empresa recebe 403.

## Fluxo

- Receptor verifica HMAC SHA256 do corpo bruto com BLING_CLIENT_SECRET, valida a empresa e grava uma fila durável idempotente. Responde sem esperar a consulta ao ERP.
- Worker consulta o registro atual, mantém exclusões seguras contra eventos atrasados e grava alterações privadas. Revisões do Firestore atualizam o app sem apagar gráficos/listas existentes.
- `admin_bling_events` é a única fonte de fatos para histórico, contador e push nativo. Somente administradores ativos e verificados recebem os dados. A mensagem FCM contém apenas IDs; o Android consulta o fato sob regras do Firestore.
- `blingLivePoll`: execução a cada minuto, páginas rotativas e lotes limitados. Produtos/contatos: catálogo completo em ciclos. Notas/propostas: últimos 31 dias. Primeira varredura de propostas estabelece uma base silenciosa. Mudanças observáveis posteriores geram avisos. Registros retroativos fora da janela de propostas não são cobertos por esse monitor.
- `blingScheduledSync`: reconciliação completa a cada 6 horas para conferir histórico e alterações que escapem aos eventos. Não é o relógio principal das notificações.
- O telefone escuta revisões em tempo real; fallback de leitura da base a cada 2 minutos enquanto em uso. As chamadas automáticas do telefone não iniciam novas importações do ERP.
- As alterações incrementais são sobrepostas à última geração completa; não substituem o catálogo por uma página parcial. Paginação rejeita revisões diferentes durante a leitura.

## Limitações e diagnóstico

O Bling documenta webhooks para produtos e notas, mas não para impressão ou propostas comerciais. A API de propostas informa data, situação, valor e contato, sem horário de salvamento ou evento de impressão. Não é possível comprovar o clique em **Imprimir**, nem detectar um salvamento que não altere campos retornados pela API. As mensagens distinguem data da proposta e horário de detecção. FCM, rede, modo de economia e sistema operacional também podem atrasar a entrega; não há garantia de simultaneidade absoluta.

Verificar `integrations_private/bling_live_poll.results` para 403/indisponibilidade; `bling_live_cursors` para andamento; `bling_webhook_queue` para status e horários; `admin_bling_sync` para revisões confirmadas. Nenhum desses registros deve ser liberado publicamente.

Teste de trabalho: após a base inicial e a configuração, salvar uma proposta com alteração real; criar produto de teste autorizado pelo responsável; emitir somente nota fiscal real necessária à operação. Comparar data do fato/detecção, caixa interna e Android. Não emitir notas fictícias para testar.

Referências: https://developer.bling.com.br/webhooks e https://developer.bling.com.br/referencia .
