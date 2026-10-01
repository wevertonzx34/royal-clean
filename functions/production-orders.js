import {createHash,randomUUID} from 'node:crypto';
import {HttpsError} from 'firebase-functions/v2/https';
import {Timestamp} from 'firebase-admin/firestore';

const digest=value=>createHash('sha256').update(JSON.stringify(value)).digest('hex');
const fail=(message,code='failed-precondition')=>{throw new HttpsError(code,message);};
export function productionSource(details) {
  if(!details?.invoice?.id || !Array.isArray(details.items) || !details.items.length || details.items.length>500)fail('A nota não possui uma lista de produtos válida para conferência.');
  const invoice={id:details.invoice.id,code:details.invoice.code??'',date:details.invoice.date??'',status:details.invoice.status??'',
    recipientName:details.invoice.recipientName??'',recipientDocument:details.invoice.recipientDocument??''};
  const items=details.items.map((row,index)=>({line:String(index),code:row.code??'',description:row.description??'',unit:row.unit??'',
    quantity:typeof row.quantity==='number'&&Number.isFinite(row.quantity)?row.quantity:null,unitPrice:row.unitPrice??null,total:row.total??null}));
  return {invoice,items,total:details.total??null,hash:digest({invoice,items,total:details.total??null})};
}
export function validateProductionChecks(items,checks,complete) {
  if(!Array.isArray(checks)||checks.length!==items.length)fail('Confira todas as linhas da ordem.','invalid-argument');
  return items.map((item,index)=>{
    const check=checks[index];
    if(!check||check.line!==item.line||typeof check.checked!=='boolean'||typeof check.quantity!=='number'||!Number.isFinite(check.quantity)||check.quantity<0||check.quantity>1e9||typeof check.observation!=='string'||check.observation.length>1000)fail('Conferência inválida.','invalid-argument');
    const observation=check.observation.trim();
    const unavailable=check.unavailable===true;
    const matches=typeof item.quantity==='number'&&item.quantity>0&&Math.abs(check.quantity-item.quantity)<0.000001;
    if(check.checked&&(!matches||unavailable))fail('Só marque um produto quando a quantidade estiver de acordo com a NF-e.');
    if((unavailable||(!check.checked&&check.quantity>0&&!matches))&&!observation)fail('Informe uma observação para cada falta ou divergência.');
    if(complete&&(!check.checked||!matches))fail('Há faltas ou divergências. Salve a conferência em aberto; a ordem só pode ser verificada com todos os produtos conferidos.');
    return {line:item.line,quantity:check.quantity,checked:check.checked,observation,unavailable};
  });
}

export function createProductionOrders({db,authenticated,requireAdmin,rateLimit,loadInvoice}) {
 return async request=>{
  const user=await authenticated(request);await requireAdmin(user);await rateLimit(user.uid,'production_orders',15);
  const input=request.data??{},id=input.invoiceId;
  if(typeof id!=='string'||! /^[1-9]\d{0,15}$/.test(id)||!Number.isSafeInteger(Number(id))||!['open','save','verify'].includes(input.action))fail('Ordem inválida.','invalid-argument');
  if(input.action!=='open'&&(!Number.isSafeInteger(input.revision)||input.revision<1||typeof input.requestId!=='string'||! /^[a-zA-Z0-9-]{16,80}$/.test(input.requestId)))fail('Identificador de gravação inválido.','invalid-argument');
  // Every save checks the original provider again; client totals/identities are never trusted.
  const source=productionSource(await loadInvoice(request,id));
  if(input.action!=='open'&&!(await db.collection(`order_care_invoice_links/${id}/orders`).limit(1).get()).empty)
    fail('Esta NF-e está vinculada à Central de atendimento. Continue a conferência pelo pedido para manter um único saldo.');
  if(source.invoice.id!==id)fail('A origem da ordem não corresponde à NF-e solicitada.','data-loss');
  await requireAdmin(await authenticated(request));
  const ref=db.doc(`production_orders/${id}`),audit=ref.collection('audit').doc(input.action==='open'?randomUUID():input.requestId);
  const command=digest({action:input.action,checks:input.checks??null,revision:input.revision??null});
  const result=await db.runTransaction(async tx=>{
    const [stored,actionDoc]=await tx.getAll(ref,audit),old=stored.data();
    const now=Timestamp.now();
    if(!old||old.sourceHash!==source.hash){
      const order={invoice:source.invoice,items:source.items,total:source.total,sourceHash:source.hash,status:'open',revision:(old?.revision??0)+1,
        checks:source.items.map(item=>({line:item.line,quantity:0,checked:false,observation:'',unavailable:false})),
        createdAt:old?.createdAt??now,updatedAt:now,updatedBy:user.uid,updatedByName:user.displayName??user.email,
        verifiedAt:null,verifiedBy:null,sourceChanged:!!old};
      tx.set(ref,order);tx.create(ref.collection('audit').doc(randomUUID()),{type:old?'source_changed':'opened',actor:user.uid,actorName:user.displayName??user.email,at:now,revision:order.revision,sourceHash:source.hash,invoice:source.invoice,items:source.items,total:source.total,previousSourceHash:old?.sourceHash??null});
      return {order,sourceChanged:!!old};
    }
    if(actionDoc.exists&&input.action!=='open') {
      if(actionDoc.data().command!==command)fail('Esta gravação já foi usada para outra conferência.','already-exists');
      return {order:old};
    }
    if(input.action==='open')return {order:old};
    if(old.revision!==input.revision)fail('Outro administrador atualizou esta ordem. Reabra a ordem antes de conferir novamente.','aborted');
    if(old.status!=='open')fail('Esta ordem já está verificada. O registro foi preservado.');
    if(!['5','6'].includes(source.invoice.status))fail('A NF-e precisa estar autorizada e não cancelada para salvar a conferência.');
    const checks=validateProductionChecks(source.items,input.checks,input.action==='verify');
    const verified=input.action==='verify';
    const order={...old,checks,status:verified?'verified':'open',revision:old.revision+1,sourceChanged:false,
      updatedAt:now,updatedBy:user.uid,updatedByName:user.displayName??user.email,verifiedAt:verified?now:null,verifiedBy:verified?user.uid:null};
    tx.set(ref,order);tx.create(audit,{type:verified?'verified':'saved',actor:user.uid,actorName:user.displayName??user.email,at:now,
      revision:order.revision,sourceHash:source.hash,checks,command,invoice:source.invoice,items:source.items,total:source.total});
    return {order};
  });
  const order=result.order;
  return {...result,order:{...order,createdAt:order.createdAt.toDate().toISOString(),updatedAt:order.updatedAt.toDate().toISOString(),verifiedAt:order.verifiedAt?.toDate().toISOString()??null}};
 };
}
