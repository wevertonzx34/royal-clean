import {test} from 'node:test';
import assert from 'node:assert/strict';
import {aggregateDashboard} from '../bling-dashboard.js';
import {invoiceListingFields,invoiceMetricKeys,readInvoiceCatalog} from '../bling-invoice-list.js';
import {validateBlingQuery,createBlingDataHandler} from '../bling-data.js';
test('Every invoice bar uses the same half-open range and fiscal membership as the list',()=>{
 const now=new Date('2026-09-27T01:00:00Z');
 const records=[];for(const day of ['2026-01-01','2026-03-31','2026-04-01','2026-06-30','2026-07-01','2026-08-01','2026-09-01','2026-09-21','2026-09-26','2026-09-27','2027-01-01'])
 for(const status of ['1','2','3','4','5','6','7','8','9','10','11'])records.push({date:day+' 23:59:59',status,total:10.25});
 for(const period of ['daily','weekly','monthly','quarterly','halfYear','yearly']){
  const d=aggregateDashboard('invoices',period,records,now);
  assert.equal(d.ranges.length,d.labels.length);
  for(const [i,range] of d.ranges.entries())for(const metric of d.metrics){
   if(metric.unavailable)continue;
   const listed=records.filter(r=>r.date.slice(0,10)>=range.start&&(!range.endExclusive||r.date.slice(0,10)<range.endExclusive)&&invoiceMetricKeys(r).includes(metric.label));
   assert.equal(metric.values[i],metric.money?listed.reduce((s,r)=>s+r.total,0):listed.length,`${period} ${metric.label} ${i}`);
  }
 }
});
test('Invoice preview keeps exact provider datetime and recipient whitelist',()=>{
 const p=invoiceListingFields({numero:12,dataEmissao:'2026-09-26 14:23:59',contato:{nome:'Empresa teste',numeroDocumento:'123',email:'hidden'},secret:'hidden'});
 assert.equal(p.date,'2026-09-26 14:23:59');assert.equal(p.recipientName,'Empresa teste');assert.equal(p.recipientDocument,'123');assert.ok(!JSON.stringify(p).includes('hidden'));
});
test('Invoice catalog validates pagination and does not publish missing or mixed recipient generation',async()=>{
 for(const q of [{page:0},{page:1.2},{catalogRun:{}}])assert.throws(()=>validateBlingQuery({kind:'invoiceCatalog',...q}));
 let row={code:'1',date:'2026-09-26 01:00:00',status:'5',listingVersion:1};
 const db={doc:()=>({get:async()=>({data:()=>({complete:{slot:'a',runId:'r1',checkedAt:'now'}})})}),collection:(path)=>path==='bling_live_records'?({where:()=>({get:async()=>({docs:[]})})}):({where:()=>({select:()=>({get:async()=>({docs:[{id:'1',data:()=>row}]})})})})};
 const data=await readInvoiceCatalog(db,{page:1});assert.equal(data.items.length,1);assert.ok(data.items[0].metricKeys.includes('Faturamento'));
 await assert.rejects(readInvoiceCatalog(db,{catalogRun:'old'}),{code:'aborted'});
 row={...row,listingVersion:undefined};await assert.rejects(readInvoiceCatalog(db,{}),{code:'failed-precondition'});
});
test('Invoice recipient list rejects non-admin before reading catalog',async()=>{
 let reads=0;const handler=createBlingDataHandler({db:{doc:()=>{reads++;return {};}},authenticated:async()=>({uid:'normal'}),requireAdmin:async()=>{throw Error('Not admin');},rateLimit:async()=>{}});
 const before=reads;await assert.rejects(handler({data:{kind:'invoiceCatalog'}}),/Not admin/);assert.equal(reads,before);
});
