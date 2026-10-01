# Central de atendimento do pedido

Acesso: royal-porta → royal-producao. Conferências antigas por NF-e continuam acessíveis dentro da central.

## Origem e limites

- Pedidos e itens são lidos do Bling, preservando ID do pedido, ID da linha, ID do produto e código original.
- Consulta inicial: últimos 30 dias, com seleção de até um ano e paginação explícita. A primeira página é consultada silenciosamente a cada minuto enquanto a tela está ativa. Isso não constitui promessa de entrega instantânea de eventos do Bling.
- Atendimentos iniciados são persistidos no Firestore e acompanhados por listener; permanecem visíveis fora do período de busca. Detalhes da origem são revalidados no Bling ao abrir e em toda operação.
- Propostas, aprovação comercial, NF-e e pagamento não são equivalentes. A confirmação comercial é explícita, com registro do administrador. A central não emite notas, não altera estoque, não declara pagamento e não cria OS de serviço no Bling.
- NF-e vinculada usa exclusivamente `notaFiscal.id` informado pelo pedido. Não há associação por nome, número aproximado ou coincidência de produtos. Notas já vinculadas encaminham para o pedido; conferência legada fica bloqueada para novas gravações quando existe atendimento vinculado.
- Se o pedido não traz vínculo de NF-e, a central informa isso. Saída exige nota vinculada autorizada; compras externas e regularização fiscal continuam sob responsabilidade da operação.

## Operação

1. Abrir pedido, registrar como o cliente confirmou e confirmar atendimento.
2. Informar quantidade separada acumulada por item, incluindo quantidades que já saíram.
3. Em faltas: motivo, observação interna, responsável, prazo e acordo com cliente (quem/quando/canal).
4. Confirmar cada item e concluir conferência. Pode ficar conferido com pendências; não se transforma em entrega completa.
5. Registrar saída: envia somente o saldo separado ainda não enviado. Saída parcial exige confirmação explícita.
6. Registrar entrega: informar quantidade entregue acumulada e recebimento/evidência. Não pode exceder o enviado nem reduzir entregas anteriores.
7. Quantidades resolvidas sem entrega exigem motivo e acordo. Isso não cancela nem corrige documentos fiscais automaticamente.
8. Concluir atendimento somente quando entregue + resolvido atingir todo o solicitado.

## Segurança e rastreabilidade

- Admin ativo com e-mail verificado e App Check. Outros perfis não recebem permissão automática.
- Saldos e auditoria só são escritos pela função `orderCare`; clientes não escrevem diretamente.
- Revisão otimista, idempotência e histórico transacional com responsável, horário, fonte e saldos anteriores.
- Mudança de itens no Bling bloqueia operações até revisão explícita. Conciliação preserva movimentos compatíveis e exige nova conferência. Remoção de item movimentado ou redução abaixo do movimentado é bloqueada, sem apagar histórico.
- Erros de gravação preservam rascunhos na tela; sair exige confirmação. Conflitos entre admins exigem reabertura.
- Eventos internos alimentam a mesma coleção privada de notificações e o push admin. Prazos próximos/vencidos têm lembrete agendado por hora, no máximo um por atendimento/dia. Marcar aviso como lido não resolve itens.
- Não há testes de entrega física com notas reais: testes automatizados usam dados sintéticos em emuladores.
