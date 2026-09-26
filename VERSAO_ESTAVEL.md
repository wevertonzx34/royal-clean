# Versão de referência — 26/09/2026

Tag Git: `stable-2026-09-26`. Esta referência preserva o código-fonte da
versão aprovada, antes das próximas alterações.

- Prévia com coroa WebP e artes demonstrativas leves, sem flutter_svg.
- Notas de saída do Bling: pressionar e segurar → Produtos, ou usar o menu
  de opções da nota; detalhes consultados pelo backend autenticado.
- Parâmetros partners e partnerAds mantidos no construtor da prévia.
- Três componentes antigos sem referências removidos da lib.
- Regras do Interfone publicadas e conferidas em 26/09/2026: avisos públicos
  legíveis e publicação restrita ao administrador ativo.

As cinco artes SVG provisórias não fazem parte do aplicativo nem deste backup.
Os originais continuam preservados localmente.

## Recuperar o código

Baixe o ZIP da tag stable-2026-09-26 no GitHub ou use uma nova pasta:

```sh
git clone --branch stable-2026-09-26 https://github.com/wevertonzx34/royal-clean.git royal-clean-stable
cd royal-clean-stable
flutter pub get
flutter analyze
flutter run -d <id-do-dispositivo>
```

O ZIP contém código-fonte, não um APK. Para gerar um APK de teste, use
`flutter build apk --debug`. Credenciais de assinatura e tokens de depuração
do App Check dependem do ambiente/dispositivo de teste.

O repositório preserva código, assets utilizados, dependências fixadas,
testes e regras. Não é um backup dos dados do Firestore, dos usuários do
Firebase Authentication ou dos segredos OAuth. Os segredos permanecem no
Secret Manager; não devem ser copiados para o repositório.
