import {test} from 'node:test';
import assert from 'node:assert/strict';
import {sanitizeBlingRecord, validateBlingQuery, sanitizeInvoiceItems} from '../bling-data.js';

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

test('Outgoing invoices use emission boundaries and explicit cancellation filter', () => {
  const q = validateBlingQuery({kind:'invoices',start:'2026-09-01',end:'2026-09-25',invoiceStatus:2,tipo:0});
  const url = new URL(`https://api.bling.com.br/Api/v3/${q.path}`);
  assert.equal(url.pathname,'/Api/v3/nfe');
  assert.equal(url.searchParams.get('tipo'),'1');
  assert.equal(url.searchParams.get('dataEmissaoInicial'),'2026-09-01 00:00:00');
  assert.equal(url.searchParams.get('dataEmissaoFinal'),'2026-09-25 23:59:59');
  assert.equal(url.searchParams.get('situacao'),'2');
  assert.throws(()=>validateBlingQuery({kind:'invoices',start:'2026-09-01',end:'2026-09-25',invoiceStatus:12}));
  assert.equal(new URL(`https://test/${validateBlingQuery({kind:'invoices',start:'2026-09-01',end:'2026-09-25'}).path}`).searchParams.has('situacao'),false);
});
test('Invoice mirror rejects entries and excludes recipient personal data', () => {
  const note={id:123,tipo:1,numero:'789',situacao:2,dataEmissao:'2026-09-25 10:00:00',contato:{nome:'Private',numeroDocumento:'Private'},chaveAcesso:'1'.repeat(44)};
  const result=sanitizeBlingRecord('invoices',note);
  assert.equal(result.statusLabel,'Cancelada');
  assert.equal(result.accessKey,'1'.repeat(44));
  assert.equal(result.type,'outgoing');
  assert.equal(JSON.stringify(result).includes('Private'),false);
  assert.throws(()=>sanitizeBlingRecord('invoices',{...note,tipo:0}));
  assert.equal(sanitizeBlingRecord('invoices',{...note,chaveAcesso:'bad'}).accessKey,'');
});

test('Invoice detail restricts identifiers and returns original line values without personal data', () => {
  assert.equal(validateBlingQuery({kind:'invoiceItems',invoiceId:'123'}).path,'nfe/123');
  for(const id of ['../produtos','0','123?tipo=0','9007199254740999',123])
    assert.throws(()=>validateBlingQuery({kind:'invoiceItems',invoiceId:id}));
  const note={id:123,tipo:1,numero:'10',situacao:5,valorNota:22,valorFrete:2,contato:{nome:'Private'},
    itens:[{codigo:'A',descricao:'Produto',quantidade:2,valor:10,valorTotal:20,unidade:'UN',impostos:{secret:'Private'}}]};
  const result=sanitizeInvoiceItems(note,'123');
  assert.equal(result.items[0].total,20);
  assert.equal(result.total,22);
  assert.equal(JSON.stringify(result).includes('Private'),false);
  assert.throws(()=>sanitizeInvoiceItems(note,'124'));
  assert.throws(()=>sanitizeInvoiceItems({...note,tipo:0},'123'));
  assert.equal(sanitizeInvoiceItems({...note,itens:[]},'123').items.length,0);
});
