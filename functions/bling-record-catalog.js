import {invoiceListingFields} from './bling-invoice-list.js';
﻿import {randomUUID} from 'node:crypto';
import {HttpsError} from 'firebase-functions/v2/https';
import {dashboardDetails} from './bling-enrichment.js';

// Resume detail batches within each provider page; publish only complete generations.
export async function syncRecordCatalog({db,group,get,sanitize,recheck,force=false}) {
  if(!['contacts','invoices'].includes(group)) throw new Error('Invalid catalog');
  const ref=db.doc(`integrations_private/bling_${group}_catalog`),owner=randomUUID();
  let state;
  const version=group==='invoices'?3:2;
  const acquired=await db.runTransaction(async tx=>{
    const old=(await tx.get(ref)).data()??{};
    if(old.leaseUntil>Date.now())throw new HttpsError('unavailable','Sincronização em andamento. Aguarde.');
    if(!force&&old.version===version&&old.phase!=='running'&&Date.parse(old.complete?.checkedAt)>Date.now()-3600000){state=old;return false;}
    state=old.phase==='running'&&old.version===version?old:{...old,version,phase:'running',startedAt:new Date().toISOString(),runId:randomUUID(),slot:old.complete?.slot==='a'?'b':'a',page:1,pass:0,pending:null,offset:0,newIds:0};
    state={...state,owner,leaseUntil:Date.now()+55000};tx.set(ref,state);return true;
  });
  if(!acquired)return {remaining:0,catalogPending:false};
  const started=Date.now();
  const payload=response=>{
    if(!response.ok)throw new HttpsError(response.status===403?'permission-denied':response.status===429?'resource-exhausted':'unavailable','Não foi possível concluir a sincronização no Bling. O último resultado completo foi preservado.');
    return response.data;
  };
  const read=async path=>payload(await get(path));
  try {
    const types=group==='contacts'?await read('contatos/tipos'):[];
    if(!Array.isArray(types))throw new HttpsError('data-loss','Tipos de contato inválidos.');
    do {
      if(state.page>10000)throw new HttpsError('resource-exhausted','Limite de páginas excedido; resultado anterior preservado.');
      const base=group==='contacts'?'contatos':'nfe';
      if(!state.pending){
        const query=group==='contacts'?'criterio=1':`tipo=1${state.pass===1?'&situacao=2':''}`;
        const list=await read(`${base}?pagina=${state.page}&limite=100&${query}`);
        // Bling may repeat rows and return slightly more than the requested limit.
        if(!Array.isArray(list)||list.length>1000)throw new HttpsError('data-loss','Página inválida.');
        const pending=[...new Map(list.map(row=>{const item=sanitize(row);return [item.id,item];})).values()];
        await recheck();
        await db.runTransaction(async tx=>{
          const live=(await tx.get(ref)).data();
          if(live?.owner!==owner)throw new HttpsError('aborted','O ciclo de sincronização mudou.');
          state={...live,pending,offset:0,newIds:0,endOfPass:list.length<100,leaseUntil:Date.now()+55000};tx.set(ref,state);
        });
      }
      const selected=state.pending.slice(state.offset,state.offset+6);
      const paths=selected.map(item=>`${base}/${item.id}`);
      const responses=get.many?await get.many(paths):await Promise.all(paths.map(get));
      const items=selected.map((item,i)=>({...item,...dashboardDetails(group,payload(responses[i]),item.id,{types}),...(group==='invoices'?invoiceListingFields(payload(responses[i])):{})}));
      await recheck();
      await db.runTransaction(async tx=>{
        const live=(await tx.get(ref)).data();
        if(live?.owner!==owner)throw new HttpsError('aborted','O ciclo de sincronização mudou.');
        const refs=items.map(item=>db.doc(`bling_catalog_snapshots/${live.slot}/${group}/${item.id}`));
        const existing=refs.length?await tx.getAll(...refs):[];
        const newIds=live.newIds+existing.filter(doc=>doc.data()?.catalogRun!==live.runId||doc.data()?.catalogPass!==live.pass).length;
        const checkedAt=new Date().toISOString();
        items.forEach((item,i)=>{
          const record={...item,checkedAt,detailsCheckedAt:checkedAt,catalogRun:live.runId,catalogPass:live.pass};
          tx.set(refs[i],record);tx.set(db.doc(`bling_private_${group}/${item.id}`),record,{merge:true});
        });
        state={...live,newIds,offset:live.offset+items.length,leaseUntil:Date.now()+55000};
        if(state.offset>=live.pending.length){
          if(!live.endOfPass&&newIds===0)throw new HttpsError('data-loss','Página repetida pelo Bling.');
          state={...state,pending:null,offset:0,page:live.page+1,newIds:0};
          if(live.endOfPass){
            // The default invoice list excludes canceled invoices.
            if(group==='invoices'&&live.pass===0)state={...state,page:1,pass:1};
            else state={...state,phase:'complete',complete:{runId:live.runId,slot:live.slot,checkedAt,startedAt:live.startedAt??checkedAt}};
          }
        }
        tx.set(ref,state);
      });
    }while(state.phase==='running'&&Date.now()-started<18000);
    return {remaining:state.phase==='running'?1:0,catalogPending:state.phase==='running',warning:state.phase==='running'?'Sincronização em andamento; o resultado anterior permanece disponível.':null};
  }finally{
    await db.runTransaction(async tx=>{if((await tx.get(ref)).data()?.owner===owner)tx.update(ref,{owner:null,leaseUntil:0});});
  }
}
