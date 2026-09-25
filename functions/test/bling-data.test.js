import {test} from 'node:test';
import assert from 'node:assert/strict';
import {sanitizeBlingRecord, validateBlingQuery} from '../bling-data.js';

test('Bling queries restrict endpoints, pagination and valid calendar ranges', () => {
  assert.match(validateBlingQuery({kind:'sales',start:'2026-09-01',end:'2026-09-25'}).path, /^pedidos\/vendas\?/);
  for (const q of [{kind:'secrets'}, {page:0}, {page:1.5},
    {kind:'sales',start:'2026-02-30',end:'2026-03-01'},
    {kind:'sales',start:'2024-01-01',end:'2026-01-01'}]) assert.throws(() => validateBlingQuery(q));
});
test('Bling records exclude customer data, cost and arbitrary provider fields', () => {
  const result = sanitizeBlingRecord('products', {id:123,nome:'Produto',codigo:'ABC',preco:10,precoCusto:8,secret:'private'});
  assert.deepEqual(result, {id:'123',name:'Produto',code:'ABC',price:10,unit:'',status:'',stock:null});
  const sale = sanitizeBlingRecord('sales', {id:44,numero:8,total:25,contato:{nome:'Private',cpf:'private'},situacao:{id:9}});
  assert.equal(JSON.stringify(sale).includes('Private'), false);
  assert.equal(sale.total,25);
});
