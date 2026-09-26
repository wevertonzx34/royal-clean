import {test} from 'node:test';
import assert from 'node:assert/strict';
import {contactRoles,salesFlow,dashboardDetails} from '../bling-enrichment.js';
test('Contact types classify exact provider types and do not infer company from document',()=>{
  assert.deepEqual(contactRoles([{id:1},{descricao:'Fornecedor'}],[{id:1,descricao:'Cliente'}]),['customer','supplier']);
  assert.deepEqual(contactRoles([{descricao:'Funcionário'}]),[]);
  assert.equal(contactRoles(undefined),null);
});
test('Details whitelist original invoice amounts and delivery fields without personal payloads',()=>{
  assert.deepEqual(dashboardDetails('invoices',{id:123,tipo:1,situacao:5,valorNota:99.95,dataEmissao:'2026-09-26',contato:{cpf:'secret'}},'123'),{total:99.95,status:'5',date:'2026-09-26'});
  assert.throws(()=>dashboardDetails('invoices',{id:124,tipo:1},'123'));
  assert.throws(()=>dashboardDetails('invoices',{id:123,tipo:0},'123'));
  assert.equal(salesFlow('Atendido'),'outgoing');assert.equal(salesFlow('Customizado'),null);
  assert.equal(salesFlow('Cancelado'),'canceled');assert.equal(salesFlow('Devolvido'),'returns');
  const d=dashboardDetails('sales',{id:123,data:'2026-09-26',total:100,situacao:{id:9},contato:{cpf:'secret'}},'123',{statusLabel:'Em aberto'});
  assert.equal(d.flow,'incoming');assert.equal(JSON.stringify(d).includes('secret'),false);
});
