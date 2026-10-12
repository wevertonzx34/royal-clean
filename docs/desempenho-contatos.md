# Desempenho: contatos do Royal Clean

A rota do Preview agora abre o índice público normalizado descrito em [indice-atividade.md](indice-atividade.md), sem consultas ao Bling. O botão administrativo preserva este painel privado de contagens usando `royalContactsOverview`, com Firebase Authentication, App Check e validação de admin no servidor. A Visão geral administrativa original mantém sua fonte e controles.

## Indicadores

- Registrados: cadastros concluídos em `users` e contas administrativas em `admin`, deduplicados pelo UID, pela data original de criação. Para administradores sem `createdAt`, usa-se a data real de criação da conta no Firebase Authentication. Contas ainda não cadastradas no aplicativo não entram nessa contagem.
- Processando: convites criados no período, válidos e ainda não utilizados no fechamento. Convites usados, cancelados ou expirados deixam essa contagem. Um convite antigo não é contado como novo em todos os dias seguintes.
- Deletados: exclusões de perfil e de conta registradas pelos eventos do servidor, sem contar bloqueio como exclusão. Dois eventos para a mesma conta não duplicam a contagem.
- Players: índice comparativo com abertura no total real de contas existentes no início do período. Fechamento azul = abertura + novos registros; fechamento rosa = fechamento azul − exclusões − convites pendentes do período. Não representa o saldo real de contas, pois um convite não é uma conta cadastrada. O próximo período abre pelo total real, e qualquer diferença em relação ao fechamento do índice é indicada como ajuste de base.
- Atividade: perfis ativos, inclusive administradores, com heartbeat em primeiro plano nos últimos 120 segundos, deduplicados entre dispositivos, versus perfis sem sinal recente. Ausente não significa exclusão.

## Tempo e gráfico

O Diário usa 00h–24h de São Paulo, conforme confirmado. Há períodos semanal (segunda a domingo), mensal, trimestral, semestral e anual. Em Players, a barra positiva parte da base real anterior e termina acima; a negativa abre exatamente no fechamento positivo e desce pela quantidade negativa. Registrados, Processando e Deletados continuam mostrando suas contagens isoladas. Zero é um traço, não uma barra de altura fictícia.

As consultas atualizam a cada 30 segundos enquanto a tela está em primeiro plano. Heartbeats são enviados uma vez por minuto. Atividade utiliza candles de presença com abertura, fechamento, máxima e mínima observadas da quantidade online, com coleta no servidor a cada minuto e nas consultas autorizadas. Uma transação atualiza um único documento agregado por dia, preservando máximos/mínimos e evitando sobrescrita por observações atrasadas. Semanas e demais períodos agregam os candles diários. A abertura usa o último fechamento observado do dia anterior quando disponível; caso contrário, a primeira observação real. Sem amostra, o gráfico indica histórico indisponível; períodos iniciados após meia-noite ou com lacunas recebem aviso de cobertura parcial. Oscilações entre amostras não são reconstruídas nem inventadas.

O desenho traz grade, brilho neon leve, médias móveis de fechamento de 3 e 7 períodos e histograma auxiliar. O histograma representa registros + negativos em Players e amplitude observada de presença em Atividade; não representa volume financeiro. As médias só são desenhadas quando há uma sequência completa de observações. A linha branca horizontal pontilhada acompanha o fechamento mais recente, incluindo o período atual. Linha e Área permanecem no seletor aguardando regras próprias no painel privado.

## Histórico e segurança

O backfill reaproveita as datas reais de cadastro e uso dos convites. Exclusões anteriores à implantação e mudanças antigas de convites sem timestamps não podem ser reconstruídas integralmente; a tela avisa essa limitação. Não há reconstrução de presença anterior ao monitoramento.

Os históricos privados usam identificadores SHA-256 e não copiam nomes, e-mails ou telefones. O cliente não pode escrever eventos, presença ou agregados diretamente, nem ler os documentos brutos, inclusive como admin. O backend retorna apenas contagens e períodos após validar a permissão. Nenhuma regra do Firestore precisou ser aberta.

Os eventos de exclusão de Authentication usam o gatilho suportado pela versão instalada. Exclusões em lote por `deleteUsers` do Admin SDK não disparam esse gatilho; futuros fluxos de exclusão em lote devem também registrar a exclusão do perfil, ou acrescentar reconciliação explícita. Não foram adicionados comandos de exclusão nem alterados cadastros comerciais.

Sessões de presença expiram após 120 segundos sem sinal. A tarefa horária remove apenas documentos efêmeros de sessões vencidas, nunca contas, produtos, pedidos ou layouts. Pagamentos, faturamento, gastos, saldo e fundo ficam fora desta entrega, conforme o escopo definido: somente Contatos.
