# Índice público de Atividade — Royal Clean v1

Desempenho no Preview abre uma leitura pública de dados agregados do próprio aplicativo. A base é **100 pontos**, sem dinheiro, investimento ou promessa de valorização. O acesso administrativo anterior permanece separado e protegido. Produtos, Bling, pagamentos e layouts não são modificados.

## Fórmula

- Uma observação por minuto, calculada exclusivamente no servidor; consultas e atualizações de tela não pontuam.
- Elegíveis: perfis ativos, não excluídos, com presença registrada nos últimos 30 dias. Convites sem cadastro não participam.
- Online: heartbeat autenticado em primeiro plano nos últimos 120 segundos. Um UID conta uma vez, independentemente do número de dispositivos. A tolerância permite atrasos de rede; não equivale a presença instantânea garantida.
- `proporção = online / elegíveis`.
- Referência inicial explícita: 5%. Depois, média observada do mesmo dia da semana/horário nas quatro semanas anteriores, exigindo pelo menos três dias com 30 minutos válidos no horário. As 24 referências são fixadas no início de cada dia e não são recalculadas durante o candle.
- `força = (proporção − referência) / max(referência, 1 − referência)`, limitada a −1…+1.
- `variação por minuto = força / 1440`. Portanto, qualquer rede varia no máximo ±1 ponto por dia completo. O tamanho da rede não multiplica a variação.
- Proporção e força são quantizadas a 1 parte por milhão. O servidor acumula um numerador inteiro, sem somar valores monetários nem arredondar repetidamente o saldo. `índice = 100 + somaForçasInteiras / 1.440.000.000`. A interface exibe seis casas decimais; cálculos preservam a precisão do numerador.
- Volume separado: soma de usuários online nas observações / 1440, em **usuários-dia observados**. Dez usuários online por um dia inteiro geram volume 10, mas não dez pontos no índice.

O sinal representa presença acima/abaixo da referência. Não mede lucro, qualidade, satisfação ou crescimento cadastral. A referência inicial não é um benchmark de mercado. A mesma proporção online produz a mesma força independentemente do número de perfis.

## Candles e histórico

Diário: 00h–24h em Brasília. Abertura = fechamento anterior; fechamento = valor mais recente; máxima e mínima = extremos observados. Um candle azul fecha acima/igual à abertura; rosa fecha abaixo. A linha horizontal branca acompanha sempre o fechamento válido mais recente, inclusive durante o candle. Médias móveis de 3 e 7 períodos usam fechamentos reais consecutivos. O histograma mostra volume observado.

Semanas (segunda a domingo), meses, trimestres, semestres e anos agregam os dias. Não há reconstrução de pontos anteriores à implantação. Minutos sem coleta ou sem elegíveis congelam o índice; lacunas são sinalizadas e não penalizam ninguém como offline. Cobertura indica a fração de minutos efetivamente observados; pavios não representam movimentos entre observações nem previsão futura.

Transações deduplicam a mesma janela de minuto e impedem retries atrasados de substituir publicações mais recentes. Reiniciar uma função não reinicia o índice. Dias encerrados são mantidos no Firestore; uma instância do servidor pode cacheá-los durante o dia para reduzir leituras.

## Segurança e operação

- `royalContactPresence`: Authentication, App Check e limitação de frequência. Nenhum cliente escreve diretamente a presença ou pontuação.
- `royalContactActivitySnapshot`: coletor agendado a cada minuto; mantém os registros privados existentes e avança o novo índice.
- `app_activity_index_state`, `app_activity_index_days`, perfis e sessões: somente backend, incluindo para admins.
- `public_activity_index/{period}`: 12 janelas de leitura pública de documento conhecido; listagem e escrita bloqueadas. Contém OHLC, referência agregada, volume e cobertura, sem UID, nomes, contatos, convites, dispositivos ou credenciais.
- A tela recebe snapshots públicos, sinaliza cache/coleta atrasada e nunca usa números fictícios para preencher o gráfico.

Authentication/App Check reduzem sinais não autorizados, mas presença não comprova atenção humana nem impede toda criação abusiva de contas. O índice é informativo. Uma revisão futura da fórmula deve receber versão própria, preservar o histórico e declarar qualquer mudança de metodologia.

Validação: testes unitários de precisão/limites/normalização, histórico e gaps; integração com Firestore emulado; regras de leitura pública e escrita negada; widgets com atualização positiva/negativa e troca de período.

## Resolução por minuto e navegação (12 tempos)

Tempos: `m1`, `m5`, `m15`, `m30`, `h1`, `h4`, `daily`, `weekly`, `monthly`, `quarterly`, `halfYear`, `yearly`. Janelas intradiárias são alinhadas à meia-noite de Brasília; 4 horas: 00h, 04h, 08h, 12h, 16h, 20h. Semana começa na segunda. Trimestres, semestres e anos seguem o calendário.

Cada avanço do índice escreve os seis candles intradiários e os seis calendários na mesma transação que atualiza a pontuação privada. Retry não duplica pontos, volume ou minutos. OHLC e volume das resoluções intradiárias reproduzem exatamente o candle diário quando a coleta cobre o dia completo. A fórmula/base anteriores permanecem; não há reinício do índice.

`public_activity_candles/{period}/candles/{start}` guarda o histórico agregado, sem identidade. Consultas públicas exigem limite explícito de no máximo 256 registros, e toda escrita continua exclusiva do servidor. Os snapshots recentes usam cache de instância limitado a 120 candles por tempo; a navegação lê páginas anteriores por cursor, conforme necessário. A tela mantém os registros carregados enquanto se consulta aquele tempo e os libera ao trocar de período.

A carga inicial busca ao menos um horizonte útil (até 1 dia em 1 minuto, 1 semana em 1 hora, 1 mês no diário), limitada ao histórico realmente existente. Zoom/rolagem e o botão de histórico carregam páginas anteriores. Histórico em 1 minuto começa na atualização que o implantou. Candles diários anteriores são preservados, incluindo suas agregações maiores; não se inventam minutos antigos nem pontos entre amostras.

Dois dedos alteram quantos candles cabem na área de desenho. Arrastar consulta trechos anteriores; reset retorna aos últimos candles. Quando os corpos ficam menores que três pixels, o desenho se condensa em uma linha de fechamentos reais, sem conectar lacunas conhecidas. Não se cria um bitmap gigante proporcional ao histórico. O eixo permanece à direita e o marcador usa o último fechamento do índice; ao consultar trecho antigo, o marcador pode ficar fora da escala visível, como em um gráfico de mercado.

A escala mínima vertical corresponde à variação diária máxima de 1 ponto multiplicada pela duração do candle. Isso impede que um movimento diário de poucas milésimas preencha toda a altura da tela. Variações maiores ampliam a escala automaticamente. Os 100 pontos são uma base de leitura, nunca volume. A duração do período define o fechamento temporal, não limita a altura visual do corpo. Dojis e pavios são resultados reais dos dados, não padrões forçados. No candle de 1 minuto há somente os extremos dos dois valores observados; não existe histórico por segundo.

O índice continua normalizado por proporção, inclusive com 100 mil usuários, e sua variação não se multiplica pela população. Registro e exclusão de contas pertencem a Players/contagens administrativas e não são somados a uma unidade de presença para gerar volatilidade artificial.

## Espaço e câmera do gráfico

A visão inicial reserva 18% da largura útil à direita do último candle. Esse espaço não contém candles, previsões ou valores futuros. Um dedo move a câmera horizontal e verticalmente; dois dedos mantêm o zoom. O eixo de pontos fica fixo à direita, com a escala correspondente à posição vertical escolhida. Os desenhos são recortados dentro da grade para não invadir a coluna de pontos.

Durante o arraste, a escala vertical permanece estável. Atualizações ao vivo e carregamento de histórico preservam a câmera manual; centralizar restaura o acompanhamento do último candle, o espaço livre e a escala automática. A linha pontilhada usa o fechamento atual real e atravessa toda a largura da grade, inclusive a área vazia. Se esse valor estiver fora da janela vertical escolhida, o marcador fica fora da visão até reposicionar ou centralizar.

O reconhecedor de gesto da grade tem prioridade sobre a rolagem vertical da página quando o arraste começa dentro do gráfico. Um dedo desloca ambos os eixos; dois dedos alteram o zoom. Toques breves continuam selecionando candles reais.

O contador `FECHA EM`, abaixo da escala de pontos, usa `end` do candle mais recente do período selecionado e o relógio do dispositivo. Atualiza o próprio rótulo a cada segundo, com dias quando necessário. Ao atingir zero, mostra `Encerrado` até receber um novo candle, sem inventar um novo intervalo se a leitura estiver atrasada. O contador cancela seu timer ao sair da tela; não modifica OHLC, pontuação, presença ou pagamentos.

Dois dedos em contato com a grade ativam o gesto diretamente, sem exigir um arraste anterior com um dedo. A separação horizontal ajusta a largura/quantidade de candles; a vertical ajusta a amplitude da escala de pontos. As distâncias por eixo têm uma regularização de 64 pixels lógicos, evitando divisões por zero e saltos quando os dedos estão alinhados. A translação do centro dos dedos move simultaneamente a câmera na horizontal e vertical. O gesto recalcula sua referência ao entrar ou sair um dedo. Toque duplo na grade ou o botão de centralizar restauram a posição inicial, o espaço livre e a escala automática. O zoom não altera valores reais nem a fórmula do índice. O desenho tem uma camada de pintura separada do contador, para evitar redesenhar candles a cada segundo.

No histograma inferior, azul/rosa indicam a direção do candle, não volume assinado. A presença observada continua não negativa. Períodos com volume positivo muito pequeno usam uma altura visual mínima de 2 pixels lógicos; o detalhe numérico conserva o valor exato. Um período observado de baixa sem usuários online tem volume zero e aparece como traço rosa na base, sem inventar presença nem somar ausências ao volume.
