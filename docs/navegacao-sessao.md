# Navegação e sessão

- A prévia continua pública. O botão Perfil confirma o acesso mantendo a prévia visível; apenas o botão indica espera quando necessário. Erros de conexão aparecem na própria prévia.
- A consulta do perfil é compartilhada durante a sessão. Renovar o token da mesma identidade não recria a assinatura nem reinicia a navegação. Trocar de usuário descarta os dados anteriores.
- Permissões exigem resposta do servidor. Cache local, alterações pendentes, revogação e falhas não liberam acesso administrativo.
- Sair encerra o Firebase e a vinculação biométrica e remove as rotas anteriores, abrindo a prévia com Login. A navegação usa o Navigator capturado antes do encerramento, pois o evento de autenticação pode desmontar a página de origem.
- Alternar aplicativos não executa logout, não redefine a rota e não bloqueia novamente uma sessão já desbloqueada. Se o sistema encerrar o processo por falta de memória, desligamento ou encerramento forçado, haverá uma nova inicialização; nessa situação continuam valendo Manter conectado e a proteção biométrica configurada.
- A versão de desenvolvimento usa App Check Debug. A impressão digital SHA-256 do certificado no Play Integrity não substitui o cadastro do token de depuração. Consulte o token da instalação atual nos registros locais do dispositivo e cadastre-o em App Check > Aplicativos > menu do aplicativo Android > Gerenciar tokens de depuração. Não registre esse segredo neste documento ou no Git.

Validação: testes de confirmação pelo servidor, renovação da sessão, revogação, troca de identidade, navegação a partir da prévia, saída após descarte do widget e preservação do formulário de login em pause/resume. Testes reais autenticados dependem do acesso do proprietário e da configuração do App Check no console.

No Moto G32, durante a alternância para Configurações, o Android registrou `LOW_MEMORY` para o processo de depuração (PSS de 432 MB). Isso reinicia o processo independentemente das rotas Flutter. A prévia passou a decodificar o logo e as imagens em resoluções limitadas para reduzir a memória usada. Essa otimização não garante que o sistema nunca encerre o processo; a versão de depuração também tem sobrecarga adicional.
