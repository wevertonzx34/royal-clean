import {invoiceMetricKeys} from './bling-invoice-list.js';
// Aggregate sanitized private records; never infer complete ERP coverage.
const groups=['products','sales','invoices','contacts'];
const periods=['daily','weekly','monthly','quarterly','halfYear','yearly'];
export function validDashboardQuery(input) {
  return groups.includes(input.group)&&periods.includes(input.period)&&
    (input.refreshSince===undefined || (typeof input.refreshSince==='string' && Number.isFinite(Date.parse(input.refreshSince)) && Math.abs(Date.now()-Date.parse(input.refreshSince))<=86400000))&&
    [undefined,'all','customer','supplier','unclassified'].includes(input.contactRole)&&
    [undefined,'all','incoming','outgoing','overdue','canceled','returns'].includes(input.salesFilter);
}
function calendarDate(value) {
  const date=typeof value==='string'?value.slice(0,10):'';
  if(!/^\d{4}-\d{2}-\d{2}$/.test(date))return null;
  const parsed=new Date(`${date}T00:00:00Z`);
  return Number.isFinite(+parsed)&&parsed.toISOString().slice(0,10)===date?parsed:null;
}
const iso=date=>date.toISOString().slice(0,10);
function todayAt(now) {
  const p=Object.fromEntries(new Intl.DateTimeFormat('en',{timeZone:'America/Sao_Paulo',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(now).map(p=>[p.type,p.value]));
  return new Date(Date.UTC(+p.year,+p.month-1,+p.day));
}
function intervals(period,today) {
  const y=today.getUTCFullYear(),m=today.getUTCMonth(),stop=new Date(+today+86400000);
  let start;
  if(period==='daily') start=new Date(+today-((today.getUTCDay()+6)%7)*86400000);
  else if(period==='weekly')start=new Date(Date.UTC(y,m,1));
  else if(period==='monthly')start=new Date(Date.UTC(y,Math.floor(m/3)*3,1));
  else if(period==='quarterly')start=new Date(Date.UTC(y,Math.floor(m/6)*6,1));
  else start=new Date(Date.UTC(y,0,1));
  const bins=[];
  for(let from=start;from<stop;) {
    let until,label;
    if(period==='daily'){until=new Date(+from+86400000);label=iso(from).slice(8)+'/'+iso(from).slice(5,7);}
    else if(period==='weekly'){until=new Date(+from+(7-(from.getUTCDay()+6)%7)*86400000);label=iso(from).slice(8)+'/'+iso(from).slice(5,7);}
    else {
      const months={monthly:1,quarterly:3,halfYear:6,yearly:12}[period];
      until=new Date(Date.UTC(from.getUTCFullYear(),from.getUTCMonth()+months,1));
      label=months===1?`${String(from.getUTCMonth()+1).padStart(2,'0')}/${String(y).slice(2)}`:months===12?String(y):`${Math.floor(from.getUTCMonth()/months)+1}${months===3?'T':'S'}/${String(y).slice(2)}`;
    }
    const end=new Date(Math.min(+until,+stop));
    bins.push({start:from,end,label,detail:`${iso(from)} a ${iso(new Date(+end-86400000))}`});from=until;
  }
  return bins;
}
const finite=n=>typeof n==='number'&&Number.isFinite(n);
export function aggregateDashboard(group,period,records,now=new Date(),filters={}) {
  const today=todayAt(now),tomorrow=new Date(+today+86400000);
  const position=group==='products'||group==='contacts';
  const baseCount=records.length;
  const missingStatuses=group==='sales'?records.filter(r=>!r.statusLabel).length:0;
  const unclassified=group==='contacts'?records.filter(r=>!Array.isArray(r.roles)||r.roles.length===0).length:
    group==='sales'?records.filter(r=>!r.flow).length:0;
  if(group==='contacts'&&filters.contactRole&&filters.contactRole!=='all') records=records.filter(r=>filters.contactRole==='unclassified'?!r.roles?.length:r.roles?.includes(filters.contactRole));
  if(group==='sales'&&filters.salesFilter&&filters.salesFilter!=='all') records=records.filter(r=>filters.salesFilter==='overdue'?
    r.flow==='incoming'&&calendarDate(r.plannedDate)&&calendarDate(r.plannedDate)<today:r.flow===filters.salesFilter);
  let ranges=[],labels,details,metrics,invalidDates=0,missingAmounts=0,summary=null;
  if(position) {
    const states=group==='products'?['A','I','?']:['A','I','S','E','?'];
    const names={A:'Ativos',I:'Inativos',S:'Sem mov.',E:'Excluídos','?':'Outros'};
    labels=states.map(s=>names[s]);details=labels;
    metrics=[{label:'Cadastros',unit:'registros',money:false,values:states.map(s=>records.filter(r=>s==='?'?!states.includes(r.status):r.status===s).length)}];
  } else {
    const bins=intervals(period,today);
    labels=bins.map(b=>b.label);details=bins.map(b=>b.detail);
    ranges=bins.map(b=>({start:iso(b.start),endExclusive:iso(b.end)}));
    if(period==='yearly') ranges.push({start:iso(tomorrow),endExclusive:null});
    if(period==='yearly'){labels.push('Futuro');details.push(`Datas posteriores a ${iso(today)} • já registradas, sem projeção`);}
    metrics=[{label:'Quantidade',unit:group==='sales'?'pedidos':'notas',money:false},{label:'Valor',unit:'',money:true}];
    if(group==='invoices')metrics.push({label:'Autorizadas',unit:'notas',money:false},{label:'Canceladas',unit:'notas',money:false},
      {label:'Entregues',unit:'notas',money:false},{label:'Pagas',unit:'notas',money:false,unavailable:'Pagamento ainda não conciliado. É necessário sincronizar as contas a receber vinculadas a cada nota; autorização fiscal não comprova pagamento.'},
      {label:'Pendentes',unit:'notas',money:false});
    metrics=metrics.map(m=>({...m,values:labels.map(()=>0)}));
    let valueCents=0,count=0,financialCount=0,futureCents=0,futureCount=0,futureMissing=0;
    for(const record of records) {
      const date=calendarDate(record.date);if(!date){invalidDates++;continue;}
      const future=date>=tomorrow;
      let i=bins.findIndex(b=>date>=b.start&&date<b.end);
      if(future&&period==='yearly')i=labels.length-1;
      if(i<0)continue;
      metrics[0].values[i]++;
      if(future)futureCount++;else count++;
      const membership=group==='invoices'?invoiceMetricKeys(record):[];
      const eligible=group!=='invoices'||membership.includes('Faturamento');
      if(eligible&&!future)financialCount++;
      if(eligible&&finite(record.total)) {
        const cents=Math.round(record.total*100);metrics[1].values[i]+=cents;
        if(future)futureCents+=cents;else valueCents+=cents;
      } else if(eligible) {if(future)futureMissing++;else missingAmounts++;}
      if(group==='invoices') {
        if(membership.includes('Autorizadas'))metrics[2].values[i]++;
        if(membership.includes('Canceladas'))metrics[3].values[i]++;
        if(membership.includes('Entregues'))metrics[4].values[i]++;
        if(membership.includes('Pendentes'))metrics[6].values[i]++;
      }
    }
    metrics[1].values=metrics[1].values.map(v=>v/100);
    if(group==='invoices') {metrics[1].label='Faturamento';metrics=[metrics[1],metrics[0],...metrics.slice(2)];}
    const name={daily:'semanal',weekly:'mensal',monthly:'trimestral',quarterly:'semestral',halfYear:'anual',yearly:'anual'}[period];
    summary={label:`Valor ${name}`,value:valueCents/100,count,financialCount,missingAmounts,
      start:iso(bins[0].start),end:iso(today),futureValue:futureCents/100,futureCount,futureMissing};
  }
  return {group,period,position,labels,details,ranges,metrics,invalidDates,missingAmounts,summary,unclassified,missingStatuses,
    records:records.length,baseRecords:baseCount,partial:true,source:'Bling • base consultada'};
}
export async function readDashboard(db,input) {
  let catalogPending=false;
  if(input.group==='products') {
    const catalog=(await db.doc('integrations_private/bling_product_catalog').get()).data();
    catalogPending=catalog?.phase==='running';
    if(catalog?.complete) {
      const counts=catalog.complete.counts;
      const result=aggregateDashboard('products',input.period,[]);
      result.metrics[0].values=['A','I','?'].map(status=>counts[status]??0);
      result.records=result.metrics[0].values.reduce((a,b)=>a+b,0);
      return {...result,baseRecords:result.records,partial:false,excluded:counts.E??0,catalogRun:catalog.complete.runId,
        source:'Bling • catálogo completo',checkedAt:catalog.complete.checkedAt,oldestAt:catalog.complete.checkedAt,
        catalogPending:catalog.phase==='running',truncated:false};
    }
  }
  const fields=['status','checkedAt','roles','date','total','plannedDate','flow','statusLabel'];
  if(['contacts','invoices'].includes(input.group)) {
    const catalog=(await db.doc(`integrations_private/bling_${input.group}_catalog`).get()).data();
    catalogPending=catalog?.phase==='running';
    if(catalog?.complete) {
      const snapshot=await db.collection(`bling_catalog_snapshots/${catalog.complete.slot}/${input.group}`)
        .where('catalogRun','==',catalog.complete.runId).select(...fields).get();
      return {...aggregateDashboard(input.group,input.period,snapshot.docs.map(doc=>doc.data()),new Date(),input),
        partial:false,truncated:false,catalogRun:catalog.complete.runId,source:'Bling • base completa',checkedAt:catalog.complete.checkedAt,
        oldestAt:catalog.complete.checkedAt,catalogPending:catalog.phase==='running'};
    }
  }
  const snapshot=await db.collection(`bling_private_${input.group}`).select(...fields).limit(5001).get();
  const records=snapshot.docs.slice(0,5000).map(doc=>doc.data());
  const times=records.map(r=>r.checkedAt).filter(t=>typeof t==='string'&&Number.isFinite(Date.parse(t))).sort();
  return {...aggregateDashboard(input.group,input.period,records,new Date(),input),catalogPending,truncated:snapshot.size>5000,
    oldestAt:times[0]??null,checkedAt:times.at(-1)??null};
}
