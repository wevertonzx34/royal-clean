# Convites Mestre e sessão — 23/09/2026

Backup anterior às alterações: commit `1e996ba`. A tentativa de push desta sessão foi bloqueada pela revisão automática. Uma consulta posterior confirmou `origin/main` no commit `a90b226`, contendo `1e996ba` como ancestral; o backup foi enviado por outro processo e está preservado também no GitHub.

## Comportamento

- Prévia pública preservada. Visitante vê Login; usuário autenticado vê Perfil, com acesso pela verificação de permissões existente.
- Sessão Firebase persistente ao reabrir quando “Manter conectado” estiver marcada no login. Desmarcada, exige novo login na próxima inicialização. Sair é explícito dentro das áreas privadas, inclusive no painel administrativo. Revogação, desativação de conta ou limpeza dos dados do aparelho ainda podem exigir nova autenticação.
- Admin cria convite com nome, telefone brasileiro com DDD, e-mail e perfil Mestre. Código M + 7 caracteres, validade de 30 dias, uso único.
- Novo usuário informa convite e telefone no campo expansível. E-mail verificado no Authentication e telefone normalizado precisam coincidir com o convite. A comparação ocorre na transação do backend; dados de e-mail/perfil enviados pelo cliente não podem substituí-la.
- Convite válido cria perfil `master`; sem convite cria `consumer`. Erro no convite impede concluir com o código, sem consumi-lo. Removê-lo permite cadastro comum. Convite não pode ser adicionado depois.
- Mestre possui área própria, Meus dados, acesso à loja e Sair. Não recebe permissões administrativas nem funcionalidades comerciais futuras.
- Telefone é conferido contra o convite, não verificado por SMS (`phoneVerified: false`). O convite exige controle do e-mail verificado; não prova titularidade da linha telefônica.
- Convites antigos ficam preservados para consulta; não são aceitos no novo cadastro. O índice de telefone/perfil continua impedindo duplicação; reemissão de convite Mestre para o mesmo telefone ainda exige um fluxo específico, não implementado nesta alteração.

## Ativação externa necessária

1. Copiar o arquivo inteiro `firestore.rules` em Cloud Firestore → Regras → Publicar. As regras anteriores não aceitam o novo campo e-mail/perfil Mestre. Nenhum dado precisa ser apagado.
2. Firebase Authentication → Configurações → Política de senha: mínimo **8**, máximo **128**, obrigatório para novos cadastros. Isso não altera senhas existentes. A validação do app não substitui a política do servidor.
3. Após ativar faturamento válido/Blaze, usar Node.js 22 e publicar o backend:

```powershell
cd C:\royal_clean\functions
npm.cmd ci
cd C:\royal_clean
.\security-tests\node_modules\.bin\firebase.cmd deploy --only functions:royal-clean-accounts --project royal-clean-fire
```

4. Testar no aparelho: login admin, voltar à prévia e tocar Perfil; fechar/reabrir e conferir sessão; Sair e conferir Login. Criar convite para uma conta de teste; validar e-mail, testar telefone divergente e depois correto; confirmar área Mestre e impedir novo uso do código.

5. A execução no Moto G32 em 23/09 registrou falha na troca do token de depuração do App Check. Conferir no console se o token da instalação atual está cadastrado no app Android correto. O log local `build/run-mestre.log` contém o token; ele é ignorado pelo Git e não deve ser publicado. Não desabilitar a proteção para contornar essa falha.

Sem a publicação das Functions, o cadastro completo e o resgate do convite continuam indisponíveis em produção. Os testes locais usam apenas emuladores.

Referências: https://firebase.google.com/docs/auth/flutter/start e https://firebase.google.com/docs/auth/android/password-auth
