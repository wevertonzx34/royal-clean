import {createHash, createHmac, timingSafeEqual, randomUUID} from 'node:crypto';
import {Timestamp} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
import {dashboardDetails} from './bling-enrichment.js';
import {invoiceListingFields} from './bling-invoice-list.js';
import {notificationFact, issuedInvoice} from './bling-notifications.js';

const hash = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
const text = value => String(value ?? '').slice(0,250);
const paths = {products:'produtos',invoices:'nfe',contacts:'contatos',proposals:'propostas-comerciais'};
export function verifyBlingSignature(raw, signature, secret) {
  if (!Buffer.isBuffer(raw) || raw.length > 1048576 || typeof signature !== 'string' || !/^sha256=[a-f0-9]{64}$/i.test(signature)) return false;
  return timingSafeEqual(Buffer.from(signature.slice(7),'hex'),createHmac('sha256',secret).update(raw).digest());
}
export function webhookEvent(body) {
  const match = /^(product|invoice)\.(created|updated|deleted)$/.exec(body?.event ?? '');
  if (!match || typeof body.eventId !== 'string' || body.eventId.length > 200 || !body.eventId ||
      !Number.isFinite(Date.parse(body.date)) || typeof body.companyId !== 'string' ||
      !/^[1-9]\d{0,15}$/.test(String(body.data?.id)) || !Number.isSafeInteger(Number(body.data.id))) return null;
  return {group:match[1]==='product'?'products':'invoices',action:match[2],id:String(body.data.id),
    eventId:body.eventId,occurredAt:body.date,companyId:body.companyId};
}

// The receiver only authenticates and durably queues. No ERP calls in the 5s acknowledgement path.
export function createBlingWebhook({db, readCredentials}) {
  let credentials, expires = 0;
  return async (req,res) => {
    if (req.method !== 'POST') return res.status(405).end();
    try {
      if (Date.now() > expires) { credentials=await readCredentials(); expires=Date.now()+60000; }
      if (!verifyBlingSignature(req.rawBody,req.get('X-Bling-Signature-256'),credentials.clientSecret)) return res.status(401).end();
      const event=webhookEvent(req.body);
      if (!event) return res.status(400).end();
      const company=(await db.doc('integrations_private/bling_live_company').get()).data()?.id;
      if (!company) return res.status(503).end();
      if (company!==event.companyId) return res.status(403).end();
      const ref=db.doc(`bling_webhook_queue/${hash([event.companyId,event.eventId])}`);
      await db.runTransaction(async tx=>{
        if ((await tx.get(ref)).exists) return;
        tx.create(ref,{...event,receivedAt:Timestamp.now(),status:'pending'});
      });
      return res.status(204).end();
    } catch (_) { return res.status(503).end(); }
  };
}

export function proposalFact(row, updated, now) {
  return {title:'Proposta comercial',body:`Proposta ${text(row.code)} ${updated?'atualizada':'cadastrada'}\nCliente: ${text(row.name)||'Não informado'}\nValor: ${typeof row.total==='number'?row.total.toLocaleString('pt-BR',{style:'currency',currency:'BRL'}):'Não informado'}\nData da proposta: ${text(row.date)||'Não informada'}\nIdentificado em: ${now.toLocaleString('pt-BR',{timeZone:'America/Sao_Paulo'})}\nO Bling não informa o horário de salvamento nem a impressão pela API.`};
}

// One immutable notification source feeds both the in-app inbox and Android push.
export async function commitLiveRecord({db,group,row,fingerprint,baseline=false,deleted=false,occurredAt=null,observedAt=new Date().toISOString()}) {
  const key=`${group}_${row.id}`, ref=db.doc(`bling_live_records/${key}`);
  return db.runTransaction(async tx=>{
    const [priorDoc,knownDoc,stateDoc]=await tx.getAll(ref,db.doc(`bling_notification_known/${key}`),db.doc(`bling_notification_state/${group}`));
    const prior=priorDoc.data(), known=knownDoc.data();
    if (prior?.observedAt > observedAt || (prior?.fingerprint===fingerprint && prior?.deleted===deleted)) return;
    const now=new Date(), revision=randomUUID();
    const notify=group==='proposals' ? !baseline : stateDoc.data()?.initialized===true;
    const eligible=!deleted && (group!=='invoices'||issuedInvoice(row));
    const newFact=group==='proposals' || !known?.notified;
    tx.set(ref,{...row,group,fingerprint,deleted,observedAt,checkedAt:observedAt,occurredAt});
    if (notify && eligible && newFact) {
      const eventId=group==='proposals'?`${key}_${revision.replaceAll('-','')}`:key;
      tx.set(db.doc(`admin_bling_events/${eventId}`),{
        ...(group==='proposals'?proposalFact(row,!!prior,now):notificationFact(group,{...row,createdAtSource:occurredAt??row.createdAtSource},now)),
        kind:'Bling • Administrador',group,recordId:row.id,publishedAt:Timestamp.fromDate(now),
        expiresAt:Timestamp.fromMillis(+now+90*86400000),occurredAt,detectedAt:observedAt,
      });
    }
    if (eligible && group!=='proposals') tx.set(db.doc(`bling_notification_known/${key}`),{notified:true,seenAt:observedAt});
    return true;
  });
}

// Overlay recent confirmed changes without replacing a complete catalog with a partial import.
// Full reconciliation remains the source for records not touched by the live channel.
export async function liveCatalogRows(db,group,complete,baseRows) {
  const snapshot=await db.collection('bling_live_records').where('group','==',group).get();
  const rows=new Map(baseRows.map(row=>[row.id,row]));
  for (const doc of snapshot.docs) {
    const row=doc.data(), old=rows.get(row.id);
    if (Date.parse(row.observedAt)<=Date.parse(old?.detailsCheckedAt??complete.startedAt??complete.checkedAt)) continue;
    if (row.deleted) rows.delete(row.id); else rows.set(row.id,{...old,...row});
  }
  return [...rows.values()];
}

export async function catalogRevision(db,group,complete) {
  const revision=(await db.doc(`admin_bling_sync/${group}`).get()).data()?.runId;
  return revision ? hash([complete.runId,revision]) : complete.runId;
}

export async function catalogCheckedAt(db,group,complete) {
  const live=(await db.doc(`admin_bling_sync/${group}`).get()).data()?.checkedAt;
  return Date.parse(live)>Date.parse(complete.checkedAt)?live:complete.checkedAt;
}

export async function runLiveSync({db,get,sanitize,event=null,recheck}) {
  const changed=new Set();
  const commit=async input=>{if(await commitLiveRecord({db,...input}))changed.add(input.group);};
  const publish=async group=>{
    if(changed.has(group))await db.doc(`admin_bling_sync/${group}`).set({runId:randomUUID(),checkedAt:new Date().toISOString()});
  };
  const read=async path=>{
    const result=await get(path);
    if(!result.ok) throw new HttpsError(result.status===403?'permission-denied':result.status===429?'resource-exhausted':'unavailable',`Bling: consulta indisponível (${result.status}).`);
    return result.data;
  };
  async function record(group,id,{listed=null,baseline=false,action=null,occurredAt=null,known}={}) {
    const observedAt=new Date().toISOString();
    if(action==='deleted') {
      const current=await get(`${paths[group]}/${id}`);
      if(current.status===404) {
        await recheck();
        return commit({group,row:{id},fingerprint:'deleted',deleted:true,occurredAt,observedAt});
      }
      if(!current.ok)throw new HttpsError('unavailable','Não foi possível confirmar a exclusão.');
      // A delayed delete event must not remove a record that currently exists.
    }
    const fingerprint=listed?hash(listed):null;
    const prior=known===undefined?(await db.doc(`bling_live_records/${group}_${id}`).get()).data():known;
    if(fingerprint && prior?.fingerprint===fingerprint && !prior.deleted)return;
    const data=['proposals','products'].includes(group)&&listed?listed:await read(`${paths[group]}/${id}`);
    if(String(data?.id)!==id)throw new Error('Unexpected Bling record');
    if(group==='invoices'&&data.tipo!==1)return;
    let row;
    if(group==='proposals') row={id,code:text(data.numero),date:text(data.data),name:text(data.contato?.nome),total:typeof data.total==='number'?data.total:null,status:text(data.situacao)};
    else {
      row={...sanitize(group,data),...dashboardDetails(group,data,id)};
      if(group==='invoices')Object.assign(row,invoiceListingFields(data));
      if(group==='contacts') {
        // Preserve known classification when the API returns only type IDs.
        const types=await read('contatos/tipos');
        Object.assign(row,dashboardDetails(group,data,id,{types}));
      }
    }
    await recheck();
    await commit({group,row,fingerprint:fingerprint??hash(row),baseline,occurredAt,observedAt});
  }
  if(event) {
    await record(event.group,event.id,{action:event.action,occurredAt:event.action==='created'?event.occurredAt:null});
    await publish(event.group);
    return {processed:true};
  }
  const ref=db.doc('integrations_private/bling_live_poll'),owner=randomUUID();
  const acquired=await db.runTransaction(async tx=>{
    if((await tx.get(ref)).data()?.leaseUntil>Date.now())return false;
    tx.set(ref,{owner,leaseUntil:Date.now()+110000},{merge:true});return true;
  });
  if(!acquired)return {busy:true};
  const results={};
  try {
    try {
      const company=await read('empresas/me/dados-basicos');
      if(typeof company?.id==='string')await db.doc('integrations_private/bling_live_company').set({id:company.id});
    }catch(e){results.company=e.code??'unavailable';}
    // Bounded, rotating pages: no full ERP download on each phone or each minute.
    for(const group of ['proposals','contacts','invoices','products']) {
      const cursorRef=db.doc(`bling_live_cursors/${group}`), cursor=(await cursorRef.get()).data()??{};
      const page=cursor.page??1;
      const today=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Sao_Paulo'}).format(new Date()),start=new Date(Date.now()-31*86400000).toISOString().slice(0,10);
      const filter=group==='products'?'&criterio=5&tipo=T':group==='contacts'?'&criterio=1':group==='invoices'?`&tipo=1&dataEmissaoInicial=${start}%2000:00:00&dataEmissaoFinal=${today}%2023:59:59`:`&dataInicial=${start}&dataFinal=${today}`;
      try {
        const rows=await read(`${paths[group]}?pagina=${page}&limite=100${filter}`);
        if(!Array.isArray(rows)||rows.length>1000)throw new Error('Invalid provider page');
        for(const item of rows)if(!Number.isSafeInteger(item.id)||item.id<=0)throw new Error('Invalid provider ID');
        const known=rows.length?await db.getAll(...rows.map(item=>db.doc(`bling_live_records/${group}_${item.id}`))):[];
        // Resume large changes across ticks, without marking unprocessed pages complete.
        const started=Date.now();let offset=cursor.offset??0;
        for(;offset<rows.length;offset++) {
          const item=rows[offset];
          if(!Number.isSafeInteger(item.id)||item.id<=0)throw new Error('Invalid provider ID');
          await record(group,String(item.id),{listed:item,baseline:!cursor.initialized,known:known[offset].data()??null});
          if(Date.now()-started>12000){offset++;break;}
        }
        const done=offset>=rows.length,end=done&&rows.length<100;
        await cursorRef.set({page:done?(end?1:page+1):page,offset:done?0:offset,initialized:cursor.initialized===true||end,checkedAt:new Date().toISOString()});
        results[group]='ok';
      }catch(e){results[group]=e.code??'unavailable';}
      await publish(group);
    }
    return results;
  }finally {
    await db.runTransaction(async tx=>{if((await tx.get(ref)).data()?.owner===owner)tx.set(ref,{owner:null,leaseUntil:0,checkedAt:new Date().toISOString(),results},{merge:true});});
  }
}
