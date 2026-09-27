import {HttpsError} from 'firebase-functions/v2/https';
export function invoiceListingFields(data) {
 const text=v=>typeof v==='string'?v.slice(0,250):'';
 return {recipientName:text(data.contato?.nome),recipientDocument:text(data.contato?.numeroDocumento),
   code:String(data.numero??'').slice(0,100),date:text(data.dataEmissao),listingVersion:1};
}
export function invoiceMetricKeys(record) {
 const keys=['Quantidade'];
 if(['5','6'].includes(record.status)) keys.push('Faturamento','Autorizadas');
 if(record.status==='2')keys.push('Canceladas');
 // This existing indicator represents fiscal transmission, not physical delivery.
 if(['3','4','5','6','8','9','10','11'].includes(record.status))keys.push('Entregues');
 if(record.status==='1')keys.push('Pendentes');
 return keys;
}
export function validateInvoiceCatalog(input) {
 if(!Number.isSafeInteger(input.page??1)||(input.page??1)<1||(input.page??1)>10000||
   (input.catalogRun!==undefined&&(typeof input.catalogRun!=='string'||input.catalogRun.length>100)))
   throw new HttpsError('invalid-argument','Página de notas inválida.');
 return {kind:'invoiceCatalog',page:input.page??1,path:null};
}
export async function readInvoiceCatalog(db,input) {
 const complete=(await db.doc('integrations_private/bling_invoices_catalog').get()).data()?.complete;
 if(!complete)throw new HttpsError('failed-precondition','Aguarde a sincronização completa das notas.');
 if(input.catalogRun&&input.catalogRun!==complete.runId)throw new HttpsError('aborted','A base de notas mudou. Atualize a lista.');
 const snapshot=await db.collection(`bling_catalog_snapshots/${complete.slot}/invoices`)
   .where('catalogRun','==',complete.runId).select('code','date','status','total','recipientName','recipientDocument','listingVersion').get();
 const rows=snapshot.docs.map(doc=>({id:doc.id,...doc.data()}));
 if(rows.some(r=>r.listingVersion!==1))throw new HttpsError('failed-precondition','Preparando os dados dos destinatários. Aguarde a sincronização das notas.');
 rows.sort((a,b)=>(b.date??'').localeCompare(a.date??'')||a.id.localeCompare(b.id));
 const page=input.page??1,offset=(page-1)*100;
 return {items:rows.slice(offset,offset+100).map(r=>({...r,metricKeys:invoiceMetricKeys(r)})),total:rows.length,
   page,hasMore:offset+100<rows.length,catalogRun:complete.runId,checkedAt:complete.checkedAt};
}
