# Categorias da vitrine

A faixa contém sete categorias de produto, independentes dos nichos comerciais,
logo abaixo da pesquisa e de Nichos. Ao chegar ao topo durante a rolagem,
fica fixa abaixo do menu principal.
Tocar novamente na categoria selecionada remove o filtro. Categoria, nicho e pesquisa
são combinados. A lista continua acessível ao rolar a página.

Os identificadores e os grupos de referência estão em `product_categories_royal_clean.dart`.
Cada produto tem `generalCategory`, `name`, `code`, `tags` e `niches`.
Sacos de lixo pertencem a `limpeza-profissional`; o exemplo `DEMO-SAC-100`
pode ser encontrado pelo nome, código ou pelas tags, sem um botão separado.

Os novos produtos são simulações locais, com imagem institucional, sem preços,
disponibilidade ou vínculo com marcas reais. Não são gravados no Firebase ou Bling.
Na integração futura, mapear explicitamente as categorias do Bling para estes IDs,
substituir códigos DEMO pelos códigos reais e revisar as tags de cada produto.
As tags de referência da categoria não devem ser copiadas indiscriminadamente para
todos os produtos: um detergente, por exemplo, não deve corresponder a “sacos de lixo”.
