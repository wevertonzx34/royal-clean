# Regras para novos controles e ajustes de layout

- Botões, ícones clicáveis e botões-imagem devem usar LayoutButtonRoyalClean
  (shared/layout_button_royal_clean.dart) com ID explícito, estável e exclusivo.
- Não renumerar IDs existentes nem regenerá-los após inserir novos botões.
- Componentes compartilhados já envolvidos pelo guia não precisam de wrapper duplo.
- Manter o layout original até confirmação do admin. Preservar onPressed/onTap,
  permissões, semântica e fluxos de navegação. Não capturar long press de registros
  de notas/contatos que já abre detalhes/produtos.
- Não substituir medidas aprovadas em constants/layout_defaults_royal_clean.dart.
- OK no guia grava aprovação local por admin. Não afirmar que isso modificou o
  repositório ou a nuvem. Para oficializar, obter o export aprovado, executar
  node tool/apply_layout_approvals.cjs <arquivo>, revisar diff, analisar e testar.
- Para controles que o usuário declarar fixos, preservar a posição exigida e
  não envolver em guia até nova autorização explícita.
- O ajuste deve conservar a ação clicável no local renderizado, inclusive após
  mover, redimensionar, navegar e reiniciar o aplicativo.
