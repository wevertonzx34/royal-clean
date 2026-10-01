import {test} from 'node:test';
import assert from 'node:assert/strict';
import {validateBlingQuery,createBlingDataHandler} from '../bling-data.js';
import {activeContacts,contactDetails,readActiveContacts} from '../bling-contact-details.js';
test('Contact detail IDs cannot change endpoint; filter and pagination are bounded',()=>{
 assert.equal(validateBlingQuery({kind:'contactDetails',contactId:'123'}).path,'contatos/123');
 for(const contactId of ['../produtos','0','1?x=2',123,'9007199254740999'])assert.throws(()=>validateBlingQuery({kind:'contactDetails',contactId}));
 for(const input of [{page:0},{page:1.5},{contactRole:'admin'},{catalogRun:{}}])assert.throws(()=>validateBlingQuery({kind:'activeContacts',...input}));
});
test('Active contact filters match chart roles without duplicates and sort names',()=>{
 const rows=[{id:'1',name:'Zulu',status:'A',roles:['customer','supplier']},{id:'2',name:'Ana',status:'A',roles:[]},{id:'3',name:'Inativo',status:'I',roles:['customer']}];
 assert.deepEqual(activeContacts(rows).map(r=>r.id),['2','1']);
 assert.deepEqual(activeContacts(rows,'supplier').map(r=>r.id),['1']);
 assert.deepEqual(activeContacts(rows,'unclassified').map(r=>r.id),['2']);
});
test('Detail exposes documented administrative fields but excludes arbitrary secrets',()=>{
 const r=contactDetails({id:123,nome:'Loja',situacao:'A',tipo:'J',email:'demo@example.test',endereco:{geral:{municipio:'Goiânia'}},financeiro:{limiteCredito:0,secret:'hidden'},secret:'hidden'},'123');
 assert.equal(r.sections[0].fields.find(f=>f.label==='Situação').value,'Ativo');
 assert.ok(JSON.stringify(r).includes('Goiânia'));
 assert.ok(JSON.stringify(r).includes('demo@example.test'));
 assert.ok(!JSON.stringify(r).includes('hidden'));
 assert.throws(()=>contactDetails({id:124},'123'));
});
test('Complete catalog is paginated, scoped and refuses a changed generation',async()=>{
 const rows=Array.from({length:27},(_,i)=>({id:String(i+1),data:()=>({id:String(i+1),name:`Contato ${String(i).padStart(2,'0')}`,status:'A',roles:[]})}));
 const db={doc:()=>({get:async()=>({data:()=>({complete:{slot:'a',runId:'run1',checkedAt:'2026-09-26'}})})}),collection:(path)=>path==='bling_live_records'?({where:()=>({get:async()=>({docs:[]})})}):({where:()=>({select:()=>({get:async()=>({docs:rows})})})})};
 const one=await readActiveContacts(db,{page:1});const two=await readActiveContacts(db,{page:2,catalogRun:one.catalogRun});
 assert.equal(one.total,27);assert.equal(one.items.length,25);assert.equal(two.items.length,2);assert.equal(two.hasMore,false);
 await assert.rejects(readActiveContacts(db,{page:2,catalogRun:'old'}),{code:'aborted'});
});
test('Contact list and detail require administrator before data access',async()=>{
 let reads=0;
 const handler=createBlingDataHandler({db:{doc:()=>{reads++;return {};}},authenticated:async()=>({uid:'normal'}),requireAdmin:async()=>{throw Error('Not admin');},rateLimit:async()=>{}});
 const initial=reads;
 for(const data of [{kind:'activeContacts'},{kind:'contactDetails',contactId:'123'}])await assert.rejects(handler({data}),/Not admin/);
 assert.equal(reads,initial);
});
