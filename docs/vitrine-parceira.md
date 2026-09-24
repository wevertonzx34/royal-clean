# Nossa parceria

A prévia consulta apenas `public_partners` e `partner_ads` com `published == true`.
Não lê `users`, `personal_data`, telefone, e-mail ou documentos pessoais.
Quando não há parceiros disponíveis, a lista mostra apenas um perfil explicitamente
demonstrativo, usando `coroa-royal.webp`, nome e apresentação ao toque.
São até quatro posições visíveis, com logos de 64 pixels e rolagem horizontal
para parceiros adicionais. Nomes longos usam até duas linhas; o perfil mostra o nome completo.
Nenhum desses exemplos é cadastrado no Firebase. Perfis reais publicados substituem os exemplos.
Na vitrine de anúncios, quatro demonstrações locais identificadas como tal aparecem
quando não há publicações disponíveis (incluindo falha de leitura). Usam a logo RC
existente e uma coroa decorativa, sem representar uma nova marca oficial. Anúncios
reais publicados substituem as demonstrações; nada é gravado no Firebase por isso.

## Ativação no Firebase

Publique o arquivo completo `firestore.rules` em Cloud Firestore > Regras.
As coleções podem ser criadas pelo console, sem alterar os cadastros existentes.
Somente administradores ativos podem publicar pelo SDK; o console usa permissões IAM.
Nunca copie o documento privado inteiro para uma coleção pública.

Cada documento contém somente:

| Campo | Tipo | Conteúdo |
| --- | --- | --- |
| title | string | Nome público ou título do anúncio, até 120 caracteres |
| description | string | Apresentação aprovada para divulgação, até 2.000 caracteres |
| imageUrl | string | URL HTTPS pública da logo ou imagem |
| published | boolean | `true` para exibir; `false` para retirar |
| createdAt | timestamp | Data de criação |
| updatedAt | timestamp | Data de atualização |

Em `public_partners`, use o UID do parceiro como ID para evitar duplicidade.
Em `partner_ads`, use exclusivamente os IDs `1`, `2`, `3` e `4` (posições da vitrine).
No console, preencha os timestamps; futuras gravações pelo SDK devem usar `serverTimestamp()`.
Não publique contatos ou outros dados pessoais na descrição sem autorização.

As alterações aparecem em tempo real. Logos são ordenadas pelo nome público;
anúncios seguem a posição. O carrossel avança a cada 6 segundos, admite gesto manual
e pausa por botão, toque, aplicativo em segundo plano ou outra rota aberta.
Acessibilidade com movimento reduzido/leitor de tela desativa o avanço automático.

O formulário de edição/publicação no perfil ainda não existe. Esta entrega prepara
a leitura pública e o contrato seguro; por enquanto a administração publica pelo
console. Criar uma conta, por si só, não torna informações pessoais públicas.
