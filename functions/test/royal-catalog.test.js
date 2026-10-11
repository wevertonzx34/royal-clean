import {test} from 'node:test';
import assert from 'node:assert/strict';
import {validateCatalog,moveStock,stockTotal,convertedUnits,catalogProjection} from '../royal-catalog.js';
import {benefitDates} from '../royal-price-benefits.js';
const product=()=>({code:'BOB20',title:'Bobina 20 x 30',description:'Capacidade até 1,6 kg',measure:'20 x 30 cm',unit:'bobina',referenceCents:2000,factorMilli:1600,unitsPerBox:12,threshold:5,categories:['embalagens-conservacao'],niches:['Dia a dia'],presentations:[{kind:'unit',imageUrl:'https://example.test/bobina.jpg',costCents:1000,pfCents:2000,pjCents:1800,minCents:1500}]});
test('NF-e conversion is exact and rejects fractional bobinas without rounding',()=>{
  assert.equal(convertedUnits(1600,1600),1);assert.equal(convertedUnits(3200,1600),2);
  assert.equal(convertedUnits(4800,2400),2);assert.equal(convertedUnits(5400,2700),2);
  assert.throws(()=>convertedUnits(2000,1600));assert.throws(()=>convertedUnits(1600,0));
});
test('Opening boxes and removing units conserve one shared stock, with explicit verification for returns',()=>{
  const start={boxes:10,loose:0,held:0,unitsPerBox:12,confirmed:true};
  assert.throws(()=>moveStock(start,{type:'exit',loose:1}));
  const open=moveStock(start,{type:'open',boxes:1});assert.equal(stockTotal(open),120);
  const sold=moveStock(open,{type:'exit',loose:1});assert.equal(sold.boxes,9);assert.equal(sold.loose,11);assert.equal(stockTotal(sold),119);
  const returned=moveStock(sold,{type:'return',loose:1});assert.equal(stockTotal(returned),119);assert.equal(returned.held,1);
  const checked=moveStock(returned,{type:'release',loose:1});assert.equal(stockTotal(checked),120);assert.equal(checked.held,0);
  assert.throws(()=>moveStock(checked,{type:'release',loose:1}));assert.throws(()=>moveStock(start,{type:'open',boxes:11}));
  assert.equal(start.boxes,10);assert.equal(start.loose,0);
  const returnedBox=moveStock(start,{type:'return',boxes:1});const checkedBox=moveStock(returnedBox,{type:'release',boxes:1});assert.equal(checkedBox.boxes,11);assert.equal(checkedBox.held,0);
});
test('Publication requires photos, descriptions, real categories and all presentation prices',()=>{
  assert.doesNotThrow(()=>validateCatalog(product(),true));
  for(const field of ['title','code','measure','unit']){assert.throws(()=>validateCatalog({...product(),[field]:''},true));}
  for(const field of ['costCents','pfCents','pjCents','minCents']){const p=product();p.presentations[0][field]=0;assert.throws(()=>validateCatalog(p,true));}
  assert.throws(()=>validateCatalog({...product(),categories:['invented']},true));
  assert.throws(()=>validateCatalog({...product(),niches:[]},true));
  const duplicate=product();duplicate.presentations.push({...duplicate.presentations[0]});assert.throws(()=>validateCatalog(duplicate,true));
  const excessive=product();excessive.presentations[0].minCents=9999;assert.throws(()=>validateCatalog(excessive,true));
});
test('Public projection never exposes stock, costs, minimums, supplier source or administrator identity',()=>{
  const p={...validateCatalog(product(),true),id:'test',status:'published',source:{private:'reference'},updatedBy:'admin',stock:{boxes:0,loose:0,unitsPerBox:12}};
  const view=catalogProjection(p,p.presentations[0]);assert.equal(view.published,true);assert.equal(view.quoteOnly,true);assert.equal(view.pfCents,null);assert.equal(view.pjCents,null);
  for(const key of ['stock','threshold','costCents','minCents','source','updatedBy'])assert.equal(key in view,false);
  p.stock.loose=1;assert.equal(catalogProjection(p,p.presentations[0]).pjCents,1800);
  p.status='suspended';assert.equal(catalogProjection(p,p.presentations[0]).published,false);
  p.status='published';p.stock.loose=12;p.stock.boxes=0;assert.equal(catalogProjection(p,{...p.presentations[0],kind:'box'}).quoteOnly,true);
});
test('Invitations have independent activation and benefit deadlines between 1 and 365 days',()=>{
  const result=benefitDates(1000,30,90);assert.equal(result.activateUntil.toMillis(),1000+30*86400000);assert.equal(result.benefitDays,90);
  for(const value of [0,366,1.5,-1,null])assert.throws(()=>benefitDates(1000,value,90));
});
