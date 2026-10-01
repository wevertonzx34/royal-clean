import {liveCatalogRows, catalogRevision, catalogCheckedAt} from './bling-live-sync.js';
import {HttpsError} from 'firebase-functions/v2/https';

export function validateContactQuery(input) {
  if(input.kind==='contactDetails') {
    if(typeof input.contactId!=='string'||! /^[1-9]\d{0,15}$/.test(input.contactId)||!Number.isSafeInteger(Number(input.contactId)))
      throw new HttpsError('invalid-argument','Contato inválido.');
    return {kind:input.kind,page:1,path:`contatos/${input.contactId}`};
  }
  if(!['all','customer','supplier','unclassified'].includes(input.contactRole??'all')||
    !Number.isSafeInteger(input.page??1)||(input.page??1)<1||(input.page??1)>10000||
    (input.catalogRun!==undefined&&(typeof input.catalogRun!=='string'||input.catalogRun.length>100)))
    throw new HttpsError('invalid-argument','Filtro de contatos inválido.');
  return {kind:input.kind,page:input.page??1,path:null};
}

export function activeContacts(records, role='all') {
  return records.filter(r=>r.status==='A' && (role==='all'||
    (role==='unclassified'?!r.roles?.length:r.roles?.includes(role))))
    .sort((a,b)=>a.name.localeCompare(b.name,'pt-BR')||a.id.localeCompare(b.id));
}

export async function readActiveContacts(db,input) {
  const catalog=(await db.doc('integrations_private/bling_contacts_catalog').get()).data()?.complete;
  if(!catalog) throw new HttpsError('failed-precondition','Sincronize os contatos na Visão geral antes de consultar a lista.');
  const revision=await catalogRevision(db,'contacts',catalog);
  if(input.catalogRun&&input.catalogRun!==revision)
    throw new HttpsError('aborted','A base foi atualizada. Atualize a lista para continuar.');
  const snapshot=await db.collection(`bling_catalog_snapshots/${catalog.slot}/contacts`)
    .where('catalogRun','==',catalog.runId).select('id','name','code','document','status','roles','detailsCheckedAt').get();
  const rows=activeContacts(await liveCatalogRows(db,'contacts',catalog,snapshot.docs.map(doc=>({...doc.data(),id:doc.id}))),input.contactRole??'all');
  const page=input.page??1,offset=(page-1)*25;
  if(revision!==await catalogRevision(db,'contacts',catalog))throw new HttpsError('aborted','Base atualizada durante a consulta.');
  return {items:rows.slice(offset,offset+25),total:rows.length,page,hasMore:offset+25<rows.length,
    checkedAt:await catalogCheckedAt(db,'contacts',catalog),catalogRun:revision};
}

// Only documented contact fields are exposed, only through the authenticated admin callable.
export function contactDetails(data,id) {
  if(!data||String(data.id)!==id)throw new HttpsError('data-loss','O Bling retornou um contato diferente do solicitado.');
  const value=v=>typeof v==='string'?v.slice(0,4000):typeof v==='number'&&Number.isFinite(v)?String(v):'';
  const fields=(source,spec)=>Object.entries(spec).map(([key,label])=>({label,value:value(source?.[key])}));
  const address={endereco:'Logradouro',numero:'Número',complemento:'Complemento',bairro:'Bairro',municipio:'Município',uf:'UF',cep:'CEP'};
  const sections=[
    {title:'Identificação',fields:fields(data,{id:'ID no Bling',nome:'Nome / razão social',fantasia:'Nome fantasia',codigo:'Código',numeroDocumento:'CPF / CNPJ',situacao:'Situação',tipo:'Tipo de pessoa'})},
    {title:'Canais de contato',fields:fields(data,{telefone:'Telefone',celular:'Celular',email:'E-mail',emailNotaFiscal:'E-mail de notas fiscais'})},
    {title:'Dados fiscais',fields:fields(data,{indicadorIe:'Indicador de IE',ie:'Inscrição estadual',inscricaoMunicipal:'Inscrição municipal',rg:'RG',orgaoEmissor:'Órgão emissor',orgaoPublico:'Órgão público'})},
    {title:'Endereço principal',fields:fields(data.endereco?.geral,address)},
    {title:'Endereço de cobrança',fields:fields(data.endereco?.cobranca,address)},
    {title:'Dados adicionais',fields:[...fields(data.dadosAdicionais,{dataNascimento:'Data de nascimento',sexo:'Sexo',naturalidade:'Naturalidade'}),...fields(data.pais,{nome:'País'})]},
    {title:'Condições comerciais',fields:[...fields(data.financeiro,{limiteCredito:'Limite de crédito (R$)',condicaoPagamento:'Condição de pagamento'}),...fields(data.financeiro?.categoria,{id:'ID da categoria financeira'}),...fields(data.vendedor,{id:'ID do vendedor'})]},
    ...['tiposContato','pessoasContato'].map(key=>({title:key==='tiposContato'?'Tipos de contato':'Pessoas de contato',fields:
      (Array.isArray(data[key])?data[key]:[]).map(row=>({label:value(row.descricao)||'Registro',value:`ID ${value(row.id)}`}))})),
  ];
  const status={A:'Ativo',I:'Inativo',S:'Sem movimentação',E:'Excluído'};
  const type={J:'Pessoa jurídica',F:'Pessoa física',E:'Estrangeiro'};
  sections[0].fields.find(f=>f.label==='Situação').value=status[data.situacao]??value(data.situacao);
  sections[0].fields.find(f=>f.label==='Tipo de pessoa').value=type[data.tipo]??value(data.tipo);
  return {id,name:value(data.nome),sections,checkedAt:new Date().toISOString(),source:'Bling'};
}
