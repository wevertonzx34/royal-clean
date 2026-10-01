import {test} from 'node:test';
import assert from 'node:assert/strict';
import {careTransition,initialLines,sourceFingerprint} from '../order-care.js';
import {sanitizeSalesOrder,validateBlingQuery} from '../bling-data.js';
const source={id:'123',items:[{line:'0',quantity:10},{line:'1',quantity:2}]};
const base=()=>({source,sourceHash:sourceFingerprint(source),lines:initialLines(source),status:'separating',reviewed:false,fiscal:{authorized:true}});
const now=new Date('2026-09-30T12:00:00Z');
const prepared=()=>base().lines.map((l,i)=>({...l,separated:i?2:6,checked:true,reason:'Falta',note:'Comprar externamente',owner:'Admin responsável',due:'2026-10-01T18:00:00Z',agreement:'Cliente aceitou por telefone em 30/09'}));
test('Partial dispatch preserves outstanding balances until actual delivery and resolution',()=>{
 let order=careTransition(base(),{action:'verify',lines:prepared()},now);
 assert.equal(order.status,'pending');assert.equal(order.reviewed,true);
 assert.throws(()=>careTransition(order,{action:'dispatch',lines:order.lines},now),/parcial/);
 order=careTransition(order,{action:'dispatch',lines:order.lines,partialApproved:true},now);
 assert.equal(order.status,'route');assert.equal(order.lines[0].dispatched,6);
 assert.throws(()=>careTransition(order,{action:'close',lines:order.lines},now),/pendentes/);
 order=careTransition(order,{action:'deliver',lines:order.lines.map(l=>({...l,delivered:l.dispatched})),receipt:'Maria recebeu em 30/09'},now);
 assert.equal(order.status,'pending');assert.equal(order.pendingCount,1);
 order=careTransition(order,{action:'save',lines:order.lines.map((l,i)=>({...l,resolved:i?0:4,resolution:'Cliente cancelou saldo; regularização fiscal solicitada'}))},now);
 order=careTransition(order,{action:'close',lines:order.lines},now);assert.equal(order.status,'closed');
 assert.throws(()=>careTransition(order,{action:'save',lines:order.lines},now),/concluído/);
});
test('Missing accountability, deadlines, agreement and acknowledgements block verification',()=>{
 for(const key of ['reason','note','owner','due','agreement']){const lines=prepared();lines[0][key]='';assert.throws(()=>careTransition(base(),{action:'verify',lines},now));}
 const lines=prepared();lines[0].checked=false;assert.throws(()=>careTransition(base(),{action:'verify',lines},now));
 lines[0].checked=true;lines[0].due='2020-01-01';assert.throws(()=>careTransition(base(),{action:'verify',lines},now),/vencido/);
});
test('Cannot dispatch unverified/uninvoiced, invent deliveries, reduce shipped quantities or bypass source changes',()=>{
 let order=base();assert.throws(()=>careTransition(order,{action:'dispatch',lines:prepared(),partialApproved:true},now));
 order=careTransition(order,{action:'verify',lines:prepared()},now);order.fiscal.authorized=false;
 assert.throws(()=>careTransition(order,{action:'dispatch',lines:order.lines,partialApproved:true},now),/NF-e/);
 for(const n of [-1,11,NaN,Infinity]){const lines=prepared();lines[0].separated=n;assert.throws(()=>careTransition(base(),{action:'save',lines},now));}
 const lines=prepared();lines[0].delivered=1;assert.throws(()=>careTransition(base(),{action:'deliver',lines,receipt:'Inventado'},now));
 order={...order,sourceChanged:true,latestSource:source};assert.throws(()=>careTransition(order,{action:'save',lines:order.lines},now),/mudou/);
 order.lines[0].dispatched=1;order.latestSource={...source,items:[source.items[1]]};assert.throws(()=>careTransition(order,{action:'reconcile'},now),/conciliação/);
});
test('Official sales IDs, original product codes, internal notes and invoice links are preserved, arbitrary fields excluded',()=>{
 const row=sanitizeSalesOrder({id:123,numero:42,contato:{nome:'Teste',numeroDocumento:'doc'},notaFiscal:{id:456},observacoesInternas:'Privado',secret:'ignore',itens:[{id:7,codigo:'SKU',produto:{id:9},quantidade:2,descricao:'Item',valor:5}]},'123');
 assert.equal(row.invoiceId,'456');assert.equal(row.items[0].productId,'9');assert.equal(row.items[0].code,'SKU');assert.equal(row.secret,undefined);
 assert.equal(validateBlingQuery({kind:'salesOrder',orderId:'123'}).path,'pedidos/vendas/123');
 assert.throws(()=>validateBlingQuery({kind:'salesOrder',orderId:'../../tokens'}));
 assert.throws(()=>sanitizeSalesOrder({id:321,itens:[]},'123'));
 assert.notEqual(sourceFingerprint({...source,document:'A'}),sourceFingerprint({...source,document:'B'}));
 assert.notEqual(sourceFingerprint({...source,internalNotes:'Entregar terça'}),sourceFingerprint({...source,internalNotes:'Entregar sexta'}));
});
