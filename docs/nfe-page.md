# Consulta visual NF-e

Acesso: Perfil → royal-porta → Funções de estoque → royal-office.
O atalho abre uma rota protegida por `AdminRouteGuardRoyalClean`, seguindo as demais páginas administrativas. A tela seleciona a primeira nota do catálogo (ordenado pelo servidor) e permite trocar por número, nome ou CPF/CNPJ.

## Dados

- Reutiliza `InvoiceListSessionRoyalClean`: catálogo completo em memória, associado ao administrador, atualização e invalidação existentes.
- Consulta os itens usando a função existente `blingReadData`, com `kind: invoiceItems` e o ID original do Bling. Não faz gravações, não emite NF-e e não altera regras ou contratos do servidor.
- Destinatário/documento vêm do catálogo; itens, valores e frete vêm da consulta de detalhes. Uma resposta de uma seleção anterior não pode substituir a nota atual.
- A identificação da empresa usa as informações já publicadas no preview do aplicativo; não é uma nova consulta do emitente fiscal.
- A API atual não fornece endereço do destinatário, aprovação, assinatura nem composição de outros valores. Esses campos permanecem explicitamente não informados. Não se usa o endereço atual de um contato para reconstruir uma nota histórica.
- Quantidade de itens e somas só são calculadas com detalhes disponíveis; valores ausentes não viram zero. A soma das quantidades pode reunir unidades diferentes e é rotulada como tal. Frete não é apresentado como a composição inteira de outros valores.

## Layout

`nfe_document_royal_clean.dart` constrói os painéis chanfrados, azul/ciano e os campos em Flutter, inspirados na referência vertical 1080 × 1920. A logo permanece vazia. A altura dos campos se adapta aos textos; a página rola verticalmente e a grade tem rolagem horizontal para manter seis colunas legíveis e vertical para listas extensas. Não há raster com informações fiscais gravadas.

A tela é uma consulta do aplicativo, não substitui XML ou DANFE. Nenhum documento oficial é gerado ou assinado.

## Verificação

`test/nfe_page_test.dart` cobre dados ausentes, formatação, celulares de diferentes larguras, texto ampliado, seleção concorrente, acionamento do atalho e prévia visual. As informações de exemplo existem apenas nos testes.
