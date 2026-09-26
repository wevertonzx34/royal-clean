import {test} from 'node:test';
import assert from 'node:assert/strict';
import {aggregateDashboard,validDashboardQuery} from '../bling-dashboard.js';
const now=new Date('2026-09-26T14:00:00Z');
test('Dashboard validates categories and periods, counts positions without fabricated history',()=>{
  assert.equal(validDashboardQuery({group:'secrets',period:'monthly'}),false);
  assert.equal(validDashboardQuery({group:'sales',period:'bad'}),false);
  const products=aggregateDashboard('products','yearly',[{status:'A'},{status:'A'},{status:'I'},{status:'X'}],now);
  assert.deepEqual(products.metrics[0].values,[2,1,1]);
  assert.equal(products.position,true);
  assert.equal(products.partial,true);
  const contacts=aggregateDashboard('contacts','daily',[{status:'E'},{status:'S'},{status:'A',document:'private'}],now);
  assert.deepEqual(contacts.metrics[0].values,[1,0,1,1,0]);
  assert.equal(JSON.stringify(contacts).includes('private'),false);
});
test('All six time periods use original dates and cents, never extrapolate samples',()=>{
  for(const period of ['daily','weekly','monthly','quarterly','halfYear','yearly']) {
    const result=aggregateDashboard('sales',period,[{date:'2026-09-26',total:0.1},{date:'2026-09-26',total:0.2},
      {date:'2026-09-26',total:null},{date:'2026-02-30',total:100},{date:'2026-09-27',total:900}],now);
    assert.equal(result.summary.count,3);
    assert.equal(result.summary.value,0.3);
    assert.equal(result.summary.futureValue,period==='yearly'?900:0);
    assert.equal(result.missingAmounts,1);assert.equal(result.invalidDates,1);
    assert.equal(result.labels.length,result.metrics[0].values.length);
  }
});
test('Invoices split current authorized and canceled statuses by emission date',()=>{
  const result=aggregateDashboard('invoices','monthly',[{date:'2026-08-31 23:00:00',status:'5'},
    {date:'2026-09-01 00:00:00',status:'2'},{date:'0000-00-00',status:'5'}],now);
  assert.deepEqual(result.metrics[1].values,[0,1,1]);
  assert.deepEqual(result.metrics[2].values,[0,1,0]);
  assert.deepEqual(result.metrics[3].values,[0,0,1]);
  assert.equal(result.invalidDates,1);
});
test('Contact roles can overlap; sales filters use confirmed status and overdue delivery date',()=>{
  const contacts=[{roles:['customer','supplier'],status:'A'},{roles:['customer'],status:'I'},{roles:[],status:'A'}];
  assert.equal(aggregateDashboard('contacts','daily',contacts,now,{contactRole:'supplier'}).records,1);
  assert.equal(aggregateDashboard('contacts','daily',contacts,now,{contactRole:'customer'}).records,2);
  assert.equal(aggregateDashboard('contacts','daily',contacts,now,{contactRole:'unclassified'}).records,1);
  const sales=[{date:'2026-09-26',plannedDate:'2026-09-25',flow:'incoming',total:10},
    {date:'2026-09-26',plannedDate:'2026-09-25',flow:'outgoing',total:20},
    {date:'2026-09-26',flow:null,total:30}];
  assert.equal(aggregateDashboard('sales','daily',sales,now,{salesFilter:'overdue'}).summary.value,10);
  assert.equal(aggregateDashboard('sales','daily',sales,now,{salesFilter:'outgoing'}).summary.value,20);
  assert.equal(aggregateDashboard('sales','daily',sales,now,{salesFilter:'returns'}).summary.count,0);
  assert.equal(aggregateDashboard('sales','daily',sales,now).unclassified,1);
});
test('Scope labels and calendar boundaries match the requested parent period',()=>{
  const cases={daily:['Valor semanal','2026-09-21'],weekly:['Valor mensal','2026-09-01'],monthly:['Valor trimestral','2026-07-01'],quarterly:['Valor semestral','2026-07-01'],halfYear:['Valor anual','2026-01-01'],yearly:['Valor anual','2026-01-01']};
  for(const [period,[label,start]] of Object.entries(cases)) {
    const r=aggregateDashboard('invoices',period,[{date:'2026-09-26',total:12.35,status:'5'}],now);
    assert.equal(r.summary.label,label);assert.equal(r.summary.start,start);assert.equal(r.summary.value,12.35);
  }
});
test('Daily cutoff uses Sao Paulo calendar, not the UTC rollover',()=>{
  const result=aggregateDashboard('sales','daily',[{date:'2026-09-26',total:10},{date:'2026-09-27',total:20}],new Date('2026-09-27T01:00:00Z'));
  assert.equal(result.labels.at(-1),'26/09');
  assert.equal(result.metrics[1].values.at(-1),10);
});

test('Invoice metrics distinguish fiscal authorization, transmission and unknown payment',()=>{
  const statuses=['1','2','3','4','5','6','7','8','9','10','11'];
  const r=aggregateDashboard('invoices','daily',statuses.map(status=>({status,date:'2026-09-26',total:10})),now);
  assert.deepEqual(r.metrics.map(m=>m.label),['Faturamento','Quantidade','Autorizadas','Canceladas','Entregues','Pagas','Pendentes']);
  assert.equal(r.summary.value,20);
  assert.equal(r.summary.count,11);
  assert.equal(r.summary.financialCount,2);
  assert.equal(r.metrics[2].values.at(-1),2);
  assert.equal(r.metrics[4].values.at(-1),8);
  assert.equal(r.metrics[6].values.at(-1),1);
  assert.match(r.metrics[5].unavailable,/não conciliado/);
  const missing=aggregateDashboard('invoices','daily',[{date:'2026-09-26',status:'5'},{date:'2026-09-26',status:'2',total:100}],now);
  assert.equal(missing.summary.missingAmounts,1);
  assert.equal(missing.summary.financialCount,1);
});