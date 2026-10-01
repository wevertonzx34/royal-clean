import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {verifyBlingSignature,webhookEvent,createBlingWebhook,commitLiveRecord,liveCatalogRows,runLiveSync} from '../bling-live-sync.js';
import {validateBlingQuery,sanitizeBlingRecord} from '../bling-data.js';

function memory() {
 const rows=new Map();
 const snapshot=path=>({exists:rows.has(path),data:()=>rows.get(path)});
 const ref=path=>({path,get:async()=>snapshot(path),set:async(value,options)=>rows.set(path,options?.merge?{...rows.get(path),...value}:value)});
 const db={doc:ref,rows,getAll:async(...refs)=>refs.map(r=>snapshot(r.path)),
  collection:name=>({where:(field,op,value)=>({get:async()=>({docs:[...rows].filter(([p,r])=>p.startsWith(name+'/')&&r[field]===value).map(([p,r])=>({id:p.split('/').at(-1),data:()=>r}))})})}),
  runTransaction:async fn=>fn({get:async r=>snapshot(r.path),getAll:async(...refs)=>refs.map(r=>snapshot(r.path)),
   create:(r,v)=>{assert.ok(!rows.has(r.path));rows.set(r.path,v);},set:(r,v,o)=>rows.set(r.path,o?.merge?{...rows.get(r.path),...v}:v)})};
 return db;
}
const event={eventId:'evt-123',date:'2026-09-29T15:00:00Z',companyId:'company',event:'product.created',data:{id:123}};
test('Webhook authenticates exact raw bytes, validates envelope and deduplicates durable delivery',async()=>{
 const raw=Buffer.from(JSON.stringify(event)),secret='test-secret';
 const signature='sha256='+createHmac('sha256',secret).update(raw).digest('hex');
 assert.equal(verifyBlingSignature(raw,signature,secret),true);
 assert.equal(verifyBlingSignature(Buffer.concat([raw,Buffer.from(' ')]),signature,secret),false);
 assert.equal(verifyBlingSignature(raw,'bad',secret),false);
 assert.equal(webhookEvent({...event,data:{id:'../escape'}}),null);
 assert.equal(webhookEvent({...event,event:'proposal.printed'}),null);
 const db=memory();db.rows.set('integrations_private/bling_live_company',{id:'company'});
 const handler=createBlingWebhook({db,readCredentials:async()=>({clientSecret:secret})});
 const res=()=>({code:null,status(code){this.code=code;return this;},end(){return this;}});
 for(let i=0;i<2;i++){const r=res();await handler({method:'POST',rawBody:raw,body:event,get:()=>signature},r);assert.equal(r.code,204);}
 assert.equal([...db.rows.keys()].filter(p=>p.startsWith('bling_webhook_queue/')).length,1);
 const denied=res();await handler({method:'POST',rawBody:raw,body:event,get:()=>signature.slice(0,-1)+'z'},denied);assert.equal(denied.code,401);
 db.rows.set('integrations_private/bling_live_company',{id:'different'});
 const foreign=res();await handler({method:'POST',rawBody:raw,body:event,get:()=>signature},foreign);assert.equal(foreign.code,403);
});
test('A confirmed live invoice creates the same persistent fact consumed by push, once; older work cannot overwrite it',async()=>{
 const db=memory();db.rows.set('bling_notification_state/invoices',{initialized:true});
 const input={db,group:'invoices',row:{id:'12',code:'77',status:'5',recipientName:'Loja',recipientDocument:'123',date:'2026-09-29 12:00:00'},fingerprint:'v1',observedAt:'2026-09-29T15:00:00Z'};
 await commitLiveRecord(input);await commitLiveRecord(input);
 assert.equal([...db.rows.keys()].filter(p=>p.startsWith('admin_bling_events/')).length,1);
 assert.match(db.rows.get('admin_bling_events/invoices_12').body,/77/);
 await commitLiveRecord({...input,row:{...input.row,status:'1'},fingerprint:'older',observedAt:'2026-09-29T14:00:00Z'});
 assert.equal(db.rows.get('bling_live_records/invoices_12').status,'5');
});
test('Proposal baseline is silent; later save change is identified without claiming printing or an invented save time',async()=>{
 const db=memory(),input={db,group:'proposals',row:{id:'1',code:'100',name:'Cliente',total:10,date:'2026-09-29'},fingerprint:'one',baseline:true};
 await commitLiveRecord(input);
 assert.equal([...db.rows.keys()].filter(p=>p.startsWith('admin_bling_events/')).length,0);
 await commitLiveRecord({...input,baseline:false,fingerprint:'two',row:{...input.row,total:20}});
 await commitLiveRecord({...input,baseline:false,fingerprint:'two',row:{...input.row,total:20}});
 const facts=[...db.rows].filter(([p])=>p.startsWith('admin_bling_events/'));
 assert.equal(facts.length,1);assert.match(facts[0][1].body,/atualizada/);assert.match(facts[0][1].body,/não informa/);
});
test('Live merge preserves complete history, applies confirmed updates/deletions and yields to newer full reconciliation',async()=>{
 const db=memory(),complete={startedAt:'2026-09-29T14:00:00Z',checkedAt:'2026-09-29T16:00:00Z'};
 db.rows.set('bling_live_records/products_1',{id:'1',group:'products',name:'Novo',observedAt:'2026-09-29T15:00:00Z'});
 db.rows.set('bling_live_records/products_3',{id:'3',group:'products',deleted:true,observedAt:'2026-09-29T15:00:00Z'});
 let rows=await liveCatalogRows(db,'products',complete,[{id:'2',name:'Preservado'},{id:'3'}]);
 assert.deepEqual(rows.map(r=>r.id),['2','1']);
 rows=await liveCatalogRows(db,'products',complete,[{id:'1',name:'Mais novo',detailsCheckedAt:'2026-09-29T16:00:00Z'}]);
 assert.equal(rows[0].name,'Mais novo');
});
test('Public callable cannot request the server-only synchronization path',()=>{
 assert.throws(()=>validateBlingQuery({kind:'liveSync',event:webhookEvent(event)}));
});
test('A delayed deletion webhook verifies the current ERP record rather than deleting it blindly',async()=>{
 const db=memory();db.rows.set('bling_notification_state/products',{initialized:true});
 await runLiveSync({db,get:async()=>({ok:true,status:200,data:{id:123,nome:'Ainda existe',situacao:'A',preco:10}}),sanitize:sanitizeBlingRecord,recheck:async()=>{},event:{group:'products',id:'123',action:'deleted'}});
 assert.equal(db.rows.get('bling_live_records/products_123').deleted,false);
 assert.ok(db.rows.has('admin_bling_sync/products'));
});
test('Minute poll establishes a silent proposal baseline, then publishes a changed proposal without reimporting unchanged rows',async()=>{
 const db=memory();let total=10;
 const get=async path=>({ok:true,status:200,data:path==='empresas/me/dados-basicos'?{id:'company'}:
   path.startsWith('propostas-comerciais?')?[{id:1,numero:77,total,data:'2026-09-29',contato:{nome:'Cliente'}}]:[]});
 const options={db,get,sanitize:sanitizeBlingRecord,recheck:async()=>{}};
 await runLiveSync(options);
 assert.equal(db.rows.get('bling_live_cursors/proposals').initialized,true);
 assert.equal([...db.rows.keys()].filter(p=>p.startsWith('admin_bling_events/')).length,0);
 const revision=db.rows.get('admin_bling_sync/proposals').runId;
 await runLiveSync(options);
 assert.equal(db.rows.get('admin_bling_sync/proposals').runId,revision);
 total=20;await runLiveSync(options);
 assert.equal([...db.rows.keys()].filter(p=>p.startsWith('admin_bling_events/')).length,1);
 assert.notEqual(db.rows.get('admin_bling_sync/proposals').runId,revision);
});
