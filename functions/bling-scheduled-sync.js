import {randomUUID} from 'node:crypto';

export function createScheduledBlingSync({db,read,wait=ms=>new Promise(resolve=>setTimeout(resolve,ms))}) {
  return async()=>{
    const ref=db.doc('integrations_private/bling_scheduled_sync'),owner=randomUUID();
    const acquired=await db.runTransaction(async tx=>{
      if((await tx.get(ref)).data()?.leaseUntil>Date.now())return false;
      tx.set(ref,{owner,leaseUntil:Date.now()+1800000,startedAt:new Date().toISOString(),finishedAt:null,results:{}},{merge:true});return true;
    });
    if(!acquired)return;
    const results={},start=Date.now();
    try {
      const connection=(await db.doc('integrations_private/bling').get()).data();
      if(!connection?.connectedBy)return;
      for(const group of ['products','invoices','contacts']){
        try {
          let pending=true,first=true,transientFailures=0;
          const groupStart=Date.now();
          while(pending&&Date.now()-start<1650000&&Date.now()-groupStart<1400000){
            try {
              const result=await read({auth:{uid:connection.connectedBy},data:{kind:'dashboard',group,period:'yearly',refreshDetails:true,syncLatest:first}});
              first=false;transientFailures=0;pending=result.enrichment?.catalogPending===true;
            }catch(error){
              if(!['unavailable','aborted','resource-exhausted'].includes(error.code)||++transientFailures>12)throw error;
              await wait(5000);
            }
          }
          results[group]=pending?'pending':'complete';
        }catch(error){results[group]=String(error.code??'unavailable').slice(0,80);}
      }
    }finally{
      await db.runTransaction(async tx=>{if((await tx.get(ref)).data()?.owner===owner)tx.update(ref,{owner:null,leaseUntil:0,finishedAt:new Date().toISOString(),results});});
    }
  };
}
