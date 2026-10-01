# Conferência interna de OS / NF-e

Acesso: royal-porta → royal-producao. A lista usa as notas de saída sincronizadas do Bling; uma ordem interna é registrada ao abrir a nota pela primeira vez. Não cria uma Ordem de Serviço no ERP, altera estoque, despacha produtos nem substitui XML/DANFE.

- Apenas administrador ativo com e-mail verificado pode consultar e gravar.
- Cada linha original preserva código, descrição, unidade, quantidade e valores. Produtos repetidos continuam em linhas separadas.
- O responsável informa a quantidade fisicamente encontrada e confirma cada linha. Quantidade não é preenchida automaticamente como conferida.
- Falta/indisponibilidade exige observação; divergências não podem ser confirmadas. Salvar em aberto permite retomar o trabalho.
- Verificada exige todas as linhas explicitamente confirmadas com quantidade exata e confirmação final. Não constitui autorização de expedição.
- Aberta é âmbar; Verificada é verde. Em rota (azul) e Entregue (roxo) estão reservadas para uma futura implementação, sem transições disponíveis.
- Toda abertura, gravação, verificação e mudança da origem registra responsável, horário do servidor e revisão, com histórico imutável. O aplicativo exibe os últimos 50 registros.
- Cada operação consulta novamente a nota no Bling. Alterações na origem reabrem a conferência ao consultar ou tentar salvar; a lista pode manter o último estado registrado até essa validação. Notas não autorizadas/canceladas são somente leitura.
- Revisões concorrentes são recusadas. Repetir a mesma operação após falha de rede não duplica a gravação. Dados digitados ficam na tela quando não há confirmação do servidor; voltar avisa sobre alterações não salvas.
- Não existem gravações diretas de clientes no Firestore, nem mesmo para admin; a função productionOrder valida origem, autorização, quantidades e histórico em transação.

Validação física de mercadorias deve ser feita pelo responsável da loja. Testes automatizados usam dados sintéticos e não verificam notas reais.
