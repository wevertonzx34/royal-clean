import {test} from 'node:test';
import assert from 'node:assert/strict';
import {notificationFact,issuedInvoice,reconcileNotifications,sendAdminEvent} from '../bling-notifications.js';

test('Facts preserve NF-e fields and never invent provider registration dates',()=>{
 const note=notificationFact('invoices',{code:'123',recipientName:'Empresa',recipientDocument:'12345678000100',date:'2026-09-28 13:42:00'});
 for(const part of ['123','Empresa','12345678000100','2026-09-28 13:42:00'])assert.ok(note.body.includes(part));
 const product=notificationFact('products',{name:'Papel',code:'SKU1',price:12.5},new Date('2026-09-28T15:00:00Z'));
 assert.ok(product.body.includes('12,50'));assert.ok(product.body.includes('data não informada'));assert.ok(product.body.includes('Identificado em'));
 assert.equal(issuedInvoice({status:'1'}),false);assert.equal(issuedInvoice({status:'5'}),true);assert.equal(issuedInvoice({status:'2'}),false);
});

function memoryDb() {
 const records=new Map();let rows=[];
 const ref=path=>({path,get:async()=>({data:()=>records.get(path)}),set:async value=>records.set(path,value)});
 return {records,setRows:value=>rows=value,doc:ref,
 collection:()=>({where:()=>({get:async()=>({docs:rows.map(row=>({id:row.id,data:()=>row}))})})}),
 runTransaction:async fn=>fn({getAll:async(...refs)=>refs.map(ref=>({data:()=>records.get(ref.path)})),
 set:(ref,value)=>records.set(ref.path,value),create:(ref,value)=>{assert.ok(!records.has(ref.path),'duplicate event');records.set(ref.path,value);}})};
}
test('Baseline is silent, new records notified once, pending invoice notified only after authorization',async()=>{
 const db=memoryDb(),run=n=>({runId:`run${n}`,slot:'a',checkedAt:'2026-09-28T00:00:00Z'});
 db.setRows([{id:'1',status:'5'},{id:'2',status:'1'}]);
 await reconcileNotifications(db,'invoices',run(1));
 assert.equal([...db.records.keys()].filter(k=>k.startsWith('admin_bling_events')).length,0);
 db.setRows([{id:'1',status:'5'},{id:'2',status:'5'},{id:'3',status:'5'}]);
 await reconcileNotifications(db,'invoices',run(2));
 await reconcileNotifications(db,'invoices',run(2));
 await reconcileNotifications(db,'invoices',run(3));
 assert.equal([...db.records.keys()].filter(k=>k.startsWith('admin_bling_events')).length,2);
});
test('Push excludes inactive/non-admin/unverified users and contains no personal facts',async()=>{
 const sent=[],deleted=[];
 const devices=['ok','inactive','consumer','unverified'].map(uid=>({id:uid,data:()=>({uid,token:`token-${uid}`}),ref:{delete:async()=>deleted.push(uid)}}));
 const db={collection:()=>({get:async()=>({docs:devices})}),doc:path=>({get:async()=>({data:()=>({ativo:!path.endsWith('inactive'),eAdministrador:!path.endsWith('consumer'),email:'admin@example.test'})})})};
 await sendAdminEvent({db,auth:{getUser:async uid=>({email:'admin@example.test',emailVerified:uid!=='unverified',disabled:false})},messaging:{send:async value=>sent.push(value)},eventId:'products_123'});
 assert.equal(sent.length,1);assert.deepEqual(sent[0].data,{type:'bling',eventId:'products_123',uid:'ok'});assert.equal(deleted.length,3);
});
