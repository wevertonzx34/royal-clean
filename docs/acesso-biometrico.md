# Acesso por biometria do dispositivo

Após login válido por e-mail/senha, Google ou Apple, um dispositivo Android/iOS com autenticação local disponível oferece “Proteger acesso neste aparelho?”. A escolha é independente de “Manter conectado”. “Agora não” não impede o login válido. O login não tem botão Entrar com digital e não abre o desafio nativo de biometria.

Ao aceitar após um login válido, o app vincula o UID ao dispositivo sem pedir uma segunda autenticação naquele momento. A confirmação nativa fica para o acesso à sessão preservada após encerrar e reabrir o processo. O app guarda o UID no armazenamento protegido do sistema; não captura digitais, PIN, padrão, senha do dispositivo ou cópias dos tokens do Firebase.

## Próximas aberturas

- A prévia continua pública.
- Uma sessão com proteção ativada permanece identificada pelo botão Perfil na prévia, mas a área privada fica bloqueada localmente. Tocar em Perfil abre a autenticação nativa, permitindo digital ou PIN, padrão ou senha do dispositivo. O bloqueio vale mesmo com “Manter conectado” marcada.
- Se “Manter conectado” estiver desmarcada, a autorização biométrica permite reter a sessão Firebase para desbloqueá-la por biometria; ela não concede acesso automático sem confirmação.
- Após a confirmação, o app atualiza a sessão no Firebase; as verificações de usuário ativo e perfil continuam nas rotas e no servidor. Sem conexão ou sessão válida, o desbloqueio pode exigir novo login.
- Sair encerra a sessão Firebase e remove a ativação local. Entrar novamente permite ativar outra vez.
- Não há suporte biométrico no navegador nesta implementação; o login normal permanece disponível.

Trata-se de desbloqueio local de uma sessão Firebase existente, não de MFA ou de uma prova biométrica enviada ao backend. A biometria aceita é a cadastrada no dispositivo, não uma digital cadastrada pela Royal Clean. Use somente um dispositivo pessoal. O bloqueio ocorre em uma nova inicialização do processo, não ao alternar momentaneamente de aplicativo para concluir OAuth/verificação de e-mail.

## Configuração e teste

Android: `USE_BIOMETRIC`, `FlutterFragmentActivity`, tema AppCompat após splash e backup de dados desativado. Textos do diálogo Android em português.

iOS: descrição de uso de Face ID e entitlement de Keychain configurados. Exige configuração e assinatura Apple/Firebase válidas; não foi compilado/testado no Windows.

`path_provider_android` está fixado em 2.2.23: a versão 2.3.x introduz JNI e exige neste ambiente um NDK 28.2 que está incompleto. A versão compatível evita alterar a instalação global do SDK; reavaliar o pin quando o NDK for reparado. A dependência de armazenamento protegido permanece atual.

Os testes automatizados simulam confirmação, recusa, indisponibilidade, vínculo com UID, sessão revogada, bloqueio de widgets privados e consentimento com “Manter conectado” marcada/desmarcada. A confirmação no sensor real exige a participação do titular do aparelho.

Teste manual: entrar com credenciais válidas → Ativar (sem desafio nativo) → autorizar salvar as credenciais no Android → alternar aplicativos e voltar (sem novo desafio) → encerrar e reabrir o app → Perfil → confirmar digital ou selecionar a credencial do aparelho na janela do sistema. Cancelar deve manter a prévia aberta e a área privada bloqueada; a ação PIN do aparelho reabre essa janela com a alternativa nativa de credencial. Nenhum formulário Royal Clean recebe o PIN. Sair encerra a sessão. Com Manter conectado marcada, o e-mail permanece preenchido no próximo login; a senha é oferecida pelo gerenciador do sistema se o titular autorizou seu salvamento.

Não exige novas Rules, Functions, Blaze ou cobrança de autenticação por SMS.

Referências: https://pub.dev/packages/local_auth, https://pub.dev/packages/local_auth_android e https://pub.dev/packages/flutter_secure_storage.
