# Avisos privados do Bling

O catálogo completo de produtos, notas de saída e contatos é sincronizado no servidor a cada 60 minutos. A atualização manual também produz eventos ao concluir o catálogo. A geração anterior permanece disponível enquanto a próxima é carregada. O celular acompanha as revisões concluídas e invalida os resumos em segundo plano.

`blingCatalogNotifications` compara cada geração completa com uma referência persistente por ID do Bling. A primeira geração é silenciosa. Produtos e contatos novos geram um evento por ID; notas geram um evento quando passam a autorizadas/emitidas (situações 5/6). Reprocessamento, alteração de preço e nova sincronização não duplicam avisos. Registros criados e removidos inteiramente entre duas consultas não são observáveis por esta estratégia; não há webhook do Bling configurado por esta alteração.

Os eventos ficam em `admin_bling_events`, separados do Interfone público. Regras permitem leitura somente por administradores ativos com e-mail verificado; toda escrita é exclusiva do servidor. A interface consulta os 200 avisos mais recentes, com validade de 90 dias, e lembra a leitura por usuário no dispositivo. A sessão bloqueada por biometria não mostra o conteúdo privado.

`registerAdminNotifications` cadastra o token Android após autorização administrativa. Tokens ficam em `admin_notification_devices`, sem acesso pelo cliente. `blingPushNotification` verifica novamente o administrador antes do envio. O push contém apenas UID e ID do evento; os dados fiscais são buscados por sessão autorizada no dispositivo. Logout remove o token local e os avisos exibidos. Tokens inválidos e de contas sem autorização são eliminados pelo remetente.

A notificação Android usa a imagem `royal-dados` como recurso `royal_dados`. O ícone pequeno é tratado como máscara pelo Android; a imagem também aparece como ícone grande. Há canal próprio, permissão Android 13+, conteúdo privado na tela bloqueada e acesso protegido ao tocar. O Android pode atrasar ou impedir alertas por falta de conexão, permissão, otimização de bateria ou encerramento forçado; o evento permanece no painel do aplicativo.

Data/hora de emissão vêm da nota. Quando a API não informa a criação de produto/contato, o texto informa essa ausência e identifica separadamente a data/hora da detecção; nunca substitui a data original silenciosamente.

Para reduzir a latência futuramente, configurar webhooks autenticados do Bling para produtos/notas, mantendo a consulta periódica como reconciliação e alternativa para contatos. Nesta versão o prazo é o próximo ciclo horário concluído, não entrega instantânea.

## Validação em 28/09/2026

- Referência inicial sem disparos: 539 produtos, 724 notas e 110 contatos já sincronizados.
- Agendamento de 60 minutos confirmado como `ENABLED` no Cloud Scheduler.
- Análise Flutter sem ocorrências; 92 testes Flutter aprovados; 39 testes unitários de backend aprovados. Suíte local de regras/integração: 79 aprovados, mais teste específico de registro push aprovado.
- Moto G32: permissão Android concedida; aviso técnico recebido no mundinho com contador; recebimento nativo com app em segundo plano e ícones da coroa; toque no aviso abriu a página protegida de notificações. Avisos técnicos removidos após o teste. Nenhum produto, contato ou documento fiscal real foi criado no Bling para testar.
