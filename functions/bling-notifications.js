import {createHash} from 'node:crypto';
import {Timestamp} from 'firebase-admin/firestore';

export const catalogGroups = {
  bling_product_catalog: 'products', bling_invoices_catalog: 'invoices', bling_contacts_catalog: 'contacts',
};
const text = value => String(value ?? '').trim().slice(0,250);
export const issuedInvoice = row => ['5','6'].includes(String(row.status));
export function notificationFact(group, row, detectedAt = new Date()) {
  const registered = text(row.createdAtSource);
  const detected = detectedAt.toLocaleString('pt-BR', {timeZone:'America/Sao_Paulo'});
  const registration = registered ? `Registro no Bling: ${registered}` : `Registro: data não informada pelo Bling.\nIdentificado em: ${detected}`;
  if(group === 'invoices') return {
    title:'Notas', body:`NF-e emitida: ${text(row.code) || 'Não informado'}\nRazão social: ${text(row.recipientName) || 'Não informada'}\nCPF/CNPJ: ${text(row.recipientDocument) || 'Não informado'}\nEmissão: ${text(row.date) || 'Não informada pelo Bling'}`,
  };
  if(group === 'products') return {
    title:'Produto', body:`${text(row.name) || 'Produto sem nome'}\nCódigo: ${text(row.code) || 'Não informado'}\nValor cadastrado: ${typeof row.price === 'number' && Number.isFinite(row.price) ? row.price.toLocaleString('pt-BR',{style:'currency',currency:'BRL'}) : 'Não informado'}\n${registration}`,
  };
  if(group === 'contacts') return {title:'Contatos',body:`${text(row.name) || 'Contato sem nome'}\n${registration}`};
  throw new Error('Invalid event group');
}

// Completed catalogs only. First catalog is a silent baseline, never historical spam.
// Each known record and its event are committed atomically; retries cannot duplicate it.
export async function reconcileNotifications(db, group, complete) {
  if(!complete?.runId || !['a','b'].includes(complete.slot)) return;
  const stateRef = db.doc(`bling_notification_state/${group}`);
  const state = (await stateRef.get()).data();
  if(state?.runId === complete.runId) return;
  const rows = await db.collection(`bling_catalog_snapshots/${complete.slot}/${group}`)
    .where('catalogRun','==',complete.runId).get();
  const baseline = !state?.initialized;
  for(let offset=0; offset<rows.docs.length; offset+=150) {
    const chunk=rows.docs.slice(offset,offset+150);
    await db.runTransaction(async tx => {
      const refs=chunk.map(doc=>db.doc(`bling_notification_known/${group}_${doc.id}`));
      const known=await tx.getAll(...refs);
      for(let i=0;i<chunk.length;i++) {
        const doc=chunk[i], row=doc.data(), previous=known[i].data();
        const eligible=group !== 'invoices' || issuedInvoice(row);
        const already=previous?.notified === true;
        if(!baseline && eligible && !already) {
          const now=new Date();
          tx.create(db.doc(`admin_bling_events/${group}_${doc.id}`), {
            ...notificationFact(group,row,now),kind:'Bling • Administrador',group,recordId:doc.id,
            publishedAt:Timestamp.fromDate(now), expiresAt:Timestamp.fromMillis(+now+90*86400000),
            catalogRun:complete.runId,
          });
        }
        if(!previous || previous.notified !== (already || eligible)) {
          tx.set(refs[i],{notified:already || eligible,seenAt:complete.checkedAt});
        }
      }
    });
  }
  await stateRef.set({initialized:true,runId:complete.runId,checkedAt:complete.checkedAt});
  await db.doc(`admin_bling_sync/${group}`).set({runId:complete.runId,checkedAt:complete.checkedAt});
}

export const deviceKey = token => createHash('sha256').update(token).digest('hex');

// Never use public FCM topics or put fiscal/customer data into push payloads.
// The device fetches the event through Firestore rules using its current session.
export async function sendAdminEvent({db,auth,messaging,eventId}) {
  const devices=await db.collection('admin_notification_devices').get();
  const users=new Map();
  for(const device of devices.docs) {
    const data=device.data();
    if(!users.has(data.uid)) {
      let valid=false;
      try {
        const [user,record]=await Promise.all([auth.getUser(data.uid),db.doc(`admin/${data.uid}`).get()]);
        const admin=record.data();
        valid=!user.disabled && user.emailVerified && admin?.ativo===true && admin?.eAdministrador===true &&
          typeof admin.email==='string' && admin.email.toLowerCase()===user.email?.toLowerCase();
      } catch(error) { if(error.code !== 'auth/user-not-found') throw error; }
      users.set(data.uid,valid);
    }
    if(!users.get(data.uid)) { await device.ref.delete(); continue; }
    try {
      await messaging.send({token:data.token,data:{type:'bling',eventId,uid:data.uid},android:{priority:'high',ttl:3600000}});
    } catch(error) {
      if(['messaging/registration-token-not-registered','messaging/invalid-registration-token'].includes(error.code)) await device.ref.delete();
      else throw error;
    }
  }
}
