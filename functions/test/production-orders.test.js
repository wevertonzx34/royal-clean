import {test} from 'node:test';
import assert from 'node:assert/strict';
import {productionSource,validateProductionChecks} from '../production-orders.js';
const items=[{line:'0',quantity:2},{line:'1',quantity:1.5}];
const checks=()=>items.map(i=>({line:i.line,quantity:i.quantity,checked:true,observation:'',unavailable:false}));
test('Verification requires every original line, matching quantities, explicit confirmation and no shortage',()=>{
 assert.equal(validateProductionChecks(items,checks(),true).length,2);
 for(const quantity of [0,1,3,NaN,Infinity,-1]){
  const c=checks();c[0].quantity=quantity;assert.throws(()=>validateProductionChecks(items,c,true));
 }
 const absent=checks();absent[0]={...absent[0],quantity:0,checked:false,unavailable:true,observation:'Sem estoque físico'};
 assert.doesNotThrow(()=>validateProductionChecks(items,absent,false));
 assert.throws(()=>validateProductionChecks(items,absent,true),/faltas ou divergências/);
 absent[0].observation=' ';assert.throws(()=>validateProductionChecks(items,absent,false),/observação/);
 const dishonest=checks();dishonest[0].unavailable=true;assert.throws(()=>validateProductionChecks(items,dishonest,false));
 assert.throws(()=>validateProductionChecks(items,checks().reverse(),true));
 assert.throws(()=>validateProductionChecks(items,checks().slice(0,1),true));
});
test('Unreviewed rows can be saved as draft, never verified; duplicate SKUs remain separate lines',()=>{
 const pending=checks().map(c=>({...c,quantity:0,checked:false}));
 assert.doesNotThrow(()=>validateProductionChecks(items,pending,false));
 assert.throws(()=>validateProductionChecks(items,pending,true));
 const data={invoice:{id:'123',status:'5'},items:[{code:'A',quantity:2},{code:'A',quantity:1}]};
 const source=productionSource(data);assert.deepEqual(source.items.map(i=>i.line),['0','1']);
 const changed=productionSource({...data,items:[{code:'A',quantity:3},{code:'A',quantity:1}]});
 assert.notEqual(changed.hash,source.hash);
 assert.throws(()=>productionSource({...data,items:[]}));
 assert.throws(()=>validateProductionChecks([{line:'0',quantity:null}],[checks()[0]],true));
});
