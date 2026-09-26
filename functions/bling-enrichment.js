const normalize = value => String(value??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').trim().toLowerCase();
export function contactRoles(types, knownTypes=[]) {
  if(!Array.isArray(types)) return null;
  const descriptions=types.map(t=>normalize(t.descricao ?? knownTypes.find(k=>k.id===t.id)?.descricao));
  return [...new Set(descriptions.flatMap(name=>/^clientes?$/.test(name)?['customer']:/^fornecedor(?:es)?$/.test(name)?['supplier']:[]))];
}
export function salesFlow(name) {
  const value=normalize(name);
  if(['em aberto','em andamento','verificado'].includes(value)) return 'incoming';
  if(['atendido','entregue'].includes(value)) return 'outgoing';
  if(['cancelado','cancelada'].includes(value)) return 'canceled';
  if(['devolvido','devolvida','retornado','em devolucao'].includes(value)) return 'returns';
  return null;
}
const amount = value => typeof value==='number'&&Number.isFinite(value)?value:null;
const dateText = value => typeof value==='string'?value.slice(0,30):'';
export function dashboardDetails(group, data, id, {types=[],statusLabel=''}={}) {
  if(!data || String(data.id)!==id) throw new Error('Identificador inesperado no detalhe.');
  if(group==='products') return {status:dateText(data.situacao),price:amount(data.preco),stock:amount(data.estoque?.saldoVirtualTotal)};
  if(group==='invoices') {
    if(data.tipo!==1) throw new Error('A nota não é de saída.');
    return {total:amount(data.valorNota),status:String(data.situacao??''),date:dateText(data.dataEmissao)};
  }
  if(group==='contacts') return {roles:contactRoles(data.tiposContato,types),status:dateText(data.situacao)};
  return {date:dateText(data.data),plannedDate:dateText(data.dataPrevista),departureDate:dateText(data.dataSaida),
    total:amount(data.total),status:String(data.situacao?.id??''),statusLabel:statusLabel.slice(0,100),flow:salesFlow(statusLabel)};
}

// Bounded, throttled enrichment of already-synchronized records only.
export async function enrichDashboard({db,group,get,recheck,now=new Date(),refreshSince=null}) {
  if(!['products','contacts','invoices','sales'].includes(group)) return {remaining:0};
  const snapshot=await db.collection(`bling_private_${group}`).select('detailsCheckedAt').limit(5000).get();
  const cutoff=refreshSince?Date.parse(refreshSince):+now-3600000;
  if(!Number.isFinite(cutoff)||cutoff>+now+60000||cutoff<+now-86400000) throw new Error('Invalid refresh window');
  const stale=snapshot.docs.filter(doc=>!Number.isFinite(Date.parse(doc.data().detailsCheckedAt)) || Date.parse(doc.data().detailsCheckedAt)<cutoff);
  const selected=stale.slice(0,10);
  let updated=0,warning=null,types=[],statuses=new Map(),statusDenied=false;
  const start=Date.now();
  if(group==='contacts'&&selected.length) {
    const result=await get('contatos/tipos');
    if(result.ok&&Array.isArray(result.data)) types=result.data;
  }
  for(const doc of selected) {
    if(Date.now()-start>25000) break;
    if(!/^[1-9]\d{0,15}$/.test(doc.id)) continue;
    const path=group==='products'?'produtos':group==='invoices'?'nfe':group==='contacts'?'contatos':'pedidos/vendas';
    const result=await get(`${path}/${doc.id}`);
    if(!result.ok) {warning=result.status===403?'Permissão insuficiente para consultar detalhes no Bling.': 'Alguns detalhes não puderam ser atualizados. Tente novamente.';break;}
    let statusLabel='';
    if(group==='sales'&&Number.isSafeInteger(result.data?.situacao?.id)) {
      const id=result.data.situacao.id;
      if(!statuses.has(id)&&!statusDenied) {
        const state=await get(`situacoes/${id}`);
        if(state.ok) statuses.set(id,state.data?.nome??'');
        else {statusDenied=true;warning='Habilite a leitura de Situações / Gerenciador de transições no Bling e renove a autorização para classificar os pedidos.';}
      }
      statusLabel=statuses.get(id)??'';
    }
    const details=dashboardDetails(group,result.data,doc.id,{types,statusLabel});
    await recheck();
    await doc.ref.set({...details,detailsCheckedAt:now.toISOString(),checkedAt:now.toISOString()},{merge:true});
    updated++;
  }
  return {remaining:stale.length-updated,warning};
}
