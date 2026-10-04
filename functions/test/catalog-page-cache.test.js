import {test} from 'node:test';
import assert from 'node:assert/strict';
import {catalogPageRows,catalogPageSize} from '../catalog-page-cache.js';
import {readProductCatalog} from '../bling-product-list.js';
import {createBlingDataHandler} from '../bling-data.js';
import {Timestamp} from 'firebase-admin/firestore';

test('Catalog pages reuse reads, but generation changes and explicit refresh replace data',async()=>{
  let reads=0, revision='r1';
  const records=Array.from({length:501},(_,i)=>({id:String(i+1),name:`Product ${i}`,status:'A'}));
  const db={doc:path=>({get:async()=>({data:()=>path==='admin_bling_sync/products'?null:
    {complete:{slot:'a',runId:revision,checkedAt:'2026-10-03T12:00:00Z',counts:{A:records.length}}}})}),
    collection:path=>path==='bling_live_records'?{where:()=>({get:async()=>({docs:[]})})}:
      {where:()=>({select:()=>({get:async()=>{reads++;return {docs:records.map(row=>({id:row.id,data:()=>row}))};}})})}};
  const first=await readProductCatalog(db,{page:1,pageSize:250});
  const second=await readProductCatalog(db,{page:2,pageSize:250,catalogRun:'r1'});
  const last=await readProductCatalog(db,{page:3,pageSize:250,catalogRun:'r1'});
  assert.equal(reads,1);assert.deepEqual([first.items.length,second.items.length,last.items.length],[250,250,1]);
  assert.equal(new Set([...first.items,...second.items,...last.items].map(r=>r.id)).size,501);
  revision='r2';await assert.rejects(readProductCatalog(db,{page:2,catalogRun:'r1'}),{code:'aborted'});
  await readProductCatalog(db,{page:2,catalogRun:'r2'});assert.equal(reads,2);
  await readProductCatalog(db,{page:1});assert.equal(reads,3);
});

test('Concurrent catalog readers share work; failed loads are retried and databases stay isolated',async()=>{
  const db={},other={};let calls=0;
  const load=async()=>{calls++;return [{id:'1'}];};
  await Promise.all([catalogPageRows(db,'r',load),catalogPageRows(db,'r',load)]);
  assert.equal(calls,1);await catalogPageRows(other,'r',load);assert.equal(calls,2);
  await assert.rejects(catalogPageRows(db,'failed',async()=>{throw Error('offline');}));
  await catalogPageRows(db,'failed',load);assert.equal(calls,3);
  for(const pageSize of [0,24,251,1.5,'250']) assert.equal(catalogPageSize({pageSize},25),null);
});

test('Interrupted refresh requests reauthorization without replaying a possibly rotated token',async()=>{
  for(const age of [1000,121000]) {
    let fetches=0,update;
    const data={expiresAt:Timestamp.fromMillis(0),refreshToken:'old-token',refreshLock:'worker',
      refreshStartedAt:Timestamp.fromMillis(Date.now()-age)};
    const ref={get:async()=>({data:()=>data})};
    const db={doc:()=>ref,runTransaction:async fn=>fn({get:ref.get,update:(_,value)=>{update=value;}})};
    const handler=createBlingDataHandler({db,authenticated:async()=>({uid:'admin'}),requireAdmin:async()=>{},
      rateLimit:async()=>{},readCredentials:async()=>({clientId:'id',clientSecret:'secret'}),
      fetchImpl:async()=>{fetches++;throw Error('must not replay');}});
    await assert.rejects(handler({data:{kind:'products'}}),{code:age>120000?'failed-precondition':'unavailable'});
    assert.equal(fetches,0);
    if(age>120000) assert.equal(update.reauthorizationRequired,true);else assert.equal(update,undefined);
  }
});
