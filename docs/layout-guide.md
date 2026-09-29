# Guia de layout — protótipo administrativo

Backup anterior ao guia: commit `372a9a7` (main, GitHub).

Em My propriedade, o admin deve pressionar e segurar o título. No modo de edição:
- Um ou dois dedos arrastam o título.
- Pinça com dois dedos muda o tamanho, entre 10 e 48 unidades lógicas do gabarito.
- Cancelar ou Voltar descartam o rascunho.
- Restaurar recupera o padrão; OK confirma.
- Copiar medidas exporta JSON para a área de transferência.

OK salva apenas neste dispositivo, separado pelo UID do admin. Não altera regras,
permissões, Firestore, dados fiscais nem publica um padrão global. A perda da
permissão administrativa encerra o guia e oculta o ajuste local.

O JSON usa canvas 432 x 768, x/y normalizados e âncora superior central. O fundo
continua em BoxFit.cover; o guia usa a mesma transformação e limita o texto à área
visível. Para oficializar uma escolha no código, o admin copia as medidas e as
fornece na próxima solicitação. A alteração do padrão deve ser revisada, testada
e publicada pelo fluxo normal do projeto. O guia não edita código sozinho.

Primeiro elemento habilitado: título My propriedade. Novos elementos podem
adotar o mesmo fluxo após implementação específica, preservando suas ações.

## Guia dos botões

144 pontos explícitos de criação de controles receberam LayoutButtonRoyalClean.
Botões em listas usam o ajuste do respectivo modelo de controle. Os IDs incluem
um escopo por página para não misturar atalhos compartilhados entre telas.
Office e Produção têm IDs próprios. Gestos de detalhes de notas/contatos e
controles nativos do sistema não são substituídos.

O admin segura o botão, arrasta com um ou dois dedos e usa pinça para redimensionar.
Cancelar descarta; Restaurar + OK retorna ao desenho original. OK salva por UID
em SharedPreferences, preservado em atualizações normais do APK (não em limpeza
de dados/desinstalação). Copiar aprovados exporta todos os ajustes confirmados.

Para converter as aprovações em padrão versionado:
1. Receber o JSON confirmado pelo admin e salvá-lo num arquivo local.
2. Executar `node tool/apply_layout_approvals.cjs caminho/do/export.json`.
3. Revisar `docs/approved-layouts.json` e `layout_defaults_royal_clean.dart`.
4. Executar análise/testes e publicar a atualização pelo fluxo autorizado.

Nenhum código é alterado automaticamente pelo aplicativo. Sem importação,
o ajuste continua local ao admin. Um padrão importado no código será aplicado
às sessões de usuários comuns também, sem lhes conceder acesso ao editor.
