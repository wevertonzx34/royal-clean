import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readProductCatalog} from '../bling-product-list.js';
import {validateBlingQuery,createBlingDataHandler} from '../bling-data.js';
import {readDashboard} from '../bling-dashboard.js';

test('Product list and dashboard share complete snapshot counts in every period, excluding deleted',async()=>{
 const records=Array.from({length:427},(_,i)=>({id:String(i+1),name:`Produto ${i}`,code:`SKU${i}`,status:i===426?'I':'A',price:10}));
 records.push({id:'deleted',status:'E'});
 const complete={slot:'a',runId:'r1',checkedAt:'2026-09-27T03:00:00Z',counts:{A:426,I:1,E:1}};
 const db={doc:()=>({get:async()=>({data:()=>({phase:'running',complete})})}),collection:path=>{
   if(path==='bling_live_records')return {where:()=>({get:async()=>({docs:[]})})};
   assert.equal(path,'bling_catalog_snapshots/a/products');
   return {where:(field,value,run)=>{assert.equal(run,'r1');return {select:()=>({get:async()=>({docs:records.map(r=>({id:r.id,data:()=>r}))})})};}};
 }};
 const pages=[];for(let page=1;page<=5;page++) pages.push(await readProductCatalog(db,{page,catalogRun:'r1'}));
 assert.deepEqual(pages.map(p=>p.items.length),[100,100,100,100,27]);
 assert.equal(pages[4].hasMore,false);
 assert.equal(new Set(pages.flatMap(p=>p.items.map(r=>r.id))).size,427);
 for(const period of ['daily','weekly','monthly','quarterly','halfYear','yearly']) {
   const chart=await readDashboard(db,{group:'products',period});
   assert.equal(chart.catalogRun,'r1');assert.equal(chart.position,true);assert.deepEqual(chart.ranges,[]);
   assert.deepEqual(chart.metrics[0].values,[426,1,0]);assert.equal(chart.records,pages[0].total);
 }
 await assert.rejects(readProductCatalog(db,{catalogRun:'old'}),{code:'aborted'});
 records.pop();records.pop();await assert.rejects(readProductCatalog(db,{}),{code:'data-loss'});
});

test('Product catalog validates input and denies non-admin before any catalog read',async()=>{
 for(const q of [{page:0},{page:1.5},{catalogRun:{}}])assert.throws(()=>validateBlingQuery({kind:'productCatalog',...q}));
 let reads=0;const handler=createBlingDataHandler({db:{doc:()=>{reads++;return {};}},authenticated:async()=>({uid:'normal'}),requireAdmin:async()=>{throw Error('Not admin');},rateLimit:async()=>{}});
 const before=reads;await assert.rejects(handler({data:{kind:'productCatalog'}}),/Not admin/);assert.equal(reads,before);
});