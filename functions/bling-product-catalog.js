import {randomUUID} from 'node:crypto';
import {HttpsError} from 'firebase-functions/v2/https';

// Two private staging slots keep the previous completed catalog readable while
// the next generation is paginated. Provider failures never publish a partial total.
export async function syncProductCatalog({db,get,sanitize,recheck,force=false,now=new Date()}) {
  const stateRef=db.doc('integrations_private/bling_product_catalog');
  const owner=randomUUID();
  let state;
  const acquired=await db.runTransaction(async tx=>{
    const old=(await tx.get(stateRef)).data()??{};
    if(old.leaseUntil>Date.now()) throw new HttpsError('unavailable','O catálogo já está sendo sincronizado. Aguarde e atualize o resumo.');
    if(!force&&old.phase!=='running'&&Date.parse(old.complete?.checkedAt)>+now-3600000) {state=old;return false;}
    state=old.phase==='running'?old:{...old,phase:'running',runId:randomUUID(),slot:old.complete?.slot==='a'?'b':'a',page:1,counts:{},startedAt:now.toISOString()};
    state={...state,owner,leaseUntil:Date.now()+55000};
    tx.set(stateRef,state);return true;
  });
  if(!acquired) return {remaining:0,catalogPending:false};
  const started=Date.now();
  try {
    do {
      if(state.page>10000) throw new HttpsError('resource-exhausted','Catálogo excedeu o limite de páginas por ciclo. A última versão completa foi preservada.');
      const response=await get(`produtos?pagina=${state.page}&limite=100&criterio=5&tipo=T`);
      if(!response.ok) throw new HttpsError(response.status===403?'permission-denied':'unavailable','Não foi possível concluir todas as páginas de produtos no Bling. A última versão completa foi preservada; tente atualizar novamente.');
      if(!Array.isArray(response.data)||response.data.length>100) throw new HttpsError('data-loss','Página de produtos inválida.');
      const items=[...new Map(response.data.map(value=>{const item=sanitize(value);return [item.id,item];})).values()];
      const refs=items.map(item=>db.doc(`bling_catalog_snapshots/${state.slot}/products/${item.id}`));
      await recheck();
      await db.runTransaction(async tx=>{
        const live=(await tx.get(stateRef)).data();
        if(live?.owner!==owner) throw new HttpsError('aborted','O ciclo de sincronização mudou. Atualize novamente.');
        const existing=refs.length?await tx.getAll(...refs):[];
        const counts={...live.counts};let newIds=0;
        const bucket=status=>['A','I','E'].includes(status)?status:'?';
        const checkedAt=new Date().toISOString();
        items.forEach((item,i)=>{
          const prior=existing[i].data();
          if(prior?.catalogRun===live.runId) counts[bucket(prior.status)]=(counts[bucket(prior.status)]??0)-1;
          else newIds++;
          counts[bucket(item.status)]=(counts[bucket(item.status)]??0)+1;
          const record={...item,checkedAt,detailsCheckedAt:checkedAt,catalogRun:live.runId};
          tx.set(refs[i],record);
          tx.set(db.doc(`bling_private_products/${item.id}`),record,{merge:true});
        });
        if(response.data.length===100&&newIds===0) throw new HttpsError('data-loss','O Bling repetiu uma página sem novos produtos. Sincronização não concluída.');
        const done=response.data.length<100;
        state={...live,counts,page:live.page+1,leaseUntil:Date.now()+55000};
        if(done) state={...state,phase:'complete',complete:{runId:live.runId,slot:live.slot,counts,checkedAt,startedAt:live.startedAt,scope:'criterio=5;tipo=T'}};
        tx.set(stateRef,state);
      });
    } while(state.phase==='running' && Date.now()-started<20000);
    return {remaining:state.phase==='running'?1:0,catalogPending:state.phase==='running',nextPage:state.page,
      warning:state.phase==='running'?'Catálogo em sincronização. A contagem anterior será substituída somente ao concluir todas as páginas.':null};
  } finally {
    await db.runTransaction(async tx=>{const live=(await tx.get(stateRef)).data();if(live?.owner===owner) tx.update(stateRef,{owner:null,leaseUntil:0});});
  }
}