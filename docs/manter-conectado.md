# Preferência de sessão no login

“Manter conectado” fica abaixo de Apple/Google. A preferência é local ao dispositivo e começa marcada para preservar o comportamento anterior.

- Marcada: o Firebase mantém a sessão entre inicializações. Os campos permitem o preenchimento pelo gerenciador do sistema; após login por senha bem-sucedido, o app permite que o sistema ofereça salvar as credenciais.
- Desmarcada: antes de expor qualquer área autenticada na próxima inicialização, o app encerra a sessão anterior. No navegador utiliza também `Persistence.NONE`. Os campos deixam de solicitar autofill e o app não solicita salvar credenciais. Senhas já guardadas pelo gerenciador do sistema não são apagadas pelo aplicativo.
- A preferência vale para e-mail/senha, Google e Apple. A sessão em andamento não é encerrada ao alternar para outro app, abrir OAuth ou verificar e-mail. Para sair imediatamente, usar Sair no perfil.
- Shared preferences armazena somente o booleano da preferência. Com a opção marcada, o último e-mail autenticado é guardado separadamente no armazenamento protegido do dispositivo e preenchido no próximo login, inclusive após Sair. Desmarcar remove esse e-mail lembrado. O aplicativo não guarda a senha nem cópias dos tokens Firebase; o SDK continua responsável pela sessão e o gerenciador do sistema pelo autofill de senha.
- No Android/iOS, Firebase persiste nativamente; a implementação limpa a sessão temporária na inicialização, antes de liberar as rotas. Não promete remover tokens do SDK enquanto o processo está fechado.
- Falha na leitura da preferência impede liberar uma sessão restaurada; falha na gravação impede iniciar um novo login com preferência não confirmada.

A prévia continua sendo a tela inicial pública. Com uma sessão válida ela mostra Perfil; não é necessário preencher o login novamente.

Após encerrar o processo, uma sessão protegida continua mostrando Perfil, e esse botão solicita digital ou PIN, padrão ou senha do aparelho antes de abrir a área privada. Alternar aplicativos não reinicia o bloqueio. O login solicita salvar credenciais válidas no Android depois de fechar o diálogo de autorização da proteção, evitando sobrepor as duas solicitações. Sair encerra efetivamente a sessão, muda o botão para Login e não apaga senhas já salvas pelo usuário no gerenciador Android/iOS. A senha não é pré-preenchida silenciosamente pelo aplicativo: depende do provedor de autofill configurado e autorizado no sistema.

Se o usuário também autorizar acesso por digital após o login, essa autorização permite reter a sessão para desbloqueio biométrico mesmo com a opção desmarcada. A sessão fica bloqueada na próxima inicialização até confirmação da biometria ou novo login. Consulte `acesso-biometrico.md`.

Sem alterações nas Rules ou nas Functions. Referências: https://firebase.google.com/docs/auth/flutter/start e https://pub.dev/packages/shared_preferences.
