import {createHash,randomUUID} from 'node:crypto';
import {HttpsError} from 'firebase-functions/v2/https';
import {Timestamp} from 'firebase-admin/firestore';

const fail=(message,code='failed-precondition')=>{throw new HttpsError(code,message);};
const hash=value=>createHash('sha256').update(JSON.stringify(value)).digest('hex');
const text=(value,max=1000)=>typeof value==='string'?value.trim().slice(0,max):'';
const quantity=value=>typeof value==='number'&&Number.isFinite(value)&&value>=0&&value<=1e9;
const eq=(a,b)=>Math.abs(a-b)<0.000001;
export const sourceFingerprint=source=>hash({id:source.id,name:source.name??'',document:source.document??'',
  notes:source.notes??'',internalNotes:source.internalNotes??'',promisedDate:source.promisedDate??'',items:source.items});
const actionLabel={confirm:'Pedido confirmado',save:'Conferência salva',verify:'Conferência concluída',dispatch:'Saída registrada',deliver:'Entrega registrada',close:'Atendimento concluído',reconcile:'Origem conciliada'};
export const initialLines=source=>source.items.map(item=>({line:item.line,separated:0,dispatched:0,delivered:0,resolved:0,
  checked:false,reason:'',note:'',owner:'',due:'',agreement:'',resolution:''}));

export function careTransition(old,input,now=new Date()) {
  const action=input.action;
  if(!['confirm','save','verify','dispatch','deliver','close','reconcile'].includes(action))fail('Operação inválida.','invalid-argument');
  if(old.status==='closed')fail('Atendimento concluído. O histórico foi preservado.');
  if(old.sourceChanged&&action!=='reconcile')fail('O pedido mudou no Bling. Revise e aceite a nova origem antes de continuar.');
  if(action==='reconcile') {
    if(!old.sourceChanged)fail('Não há mudança de origem para revisar.');
    const latest=old.latestSource;
    const identity=item=>item.sourceLineId?`id:${item.sourceLineId}`:`line:${item.line}:${item.code??''}`;
    const previous=new Map(old.source.items.map((item,i)=>[identity(item),{item,line:old.lines[i]}]));
    if(previous.size!==old.lines.length||new Set(latest.items.map(identity)).size!==latest.items.length)fail('Linhas ambíguas. A origem exige conciliação administrativa.');
    const lines=initialLines(latest).map((blank,i)=>{
      const item=latest.items[i],entry=previous.get(identity(item));
      if(!entry)return blank;
      previous.delete(identity(item));
      if(entry.item.code!==item.code&&(entry.line.dispatched>0||entry.line.resolved>0))fail('Produto alterado após movimentação. A origem exige conciliação administrativa.');
      if(!quantity(item.quantity)||entry.line.dispatched+entry.line.resolved>item.quantity+1e-6)fail('A nova quantidade é menor que a já movimentada. Nenhum saldo foi apagado.');
      return {...entry.line,line:item.line,separated:Math.min(entry.line.separated,item.quantity-entry.line.resolved),checked:false};
    });
    if([...previous.values()].some(e=>e.line.dispatched>0||e.line.delivered>0||e.line.resolved>0))fail('Item movimentado removido no Bling. A origem exige conciliação administrativa; nenhum saldo foi apagado.');
    return {...old,source:old.latestSource,sourceHash:sourceFingerprint(old.latestSource),sourceChanged:false,latestSource:null,
      lines,status:'separating',reviewed:false,pendingCount:lines.filter((l,i)=>l.delivered+l.resolved<latest.items[i].quantity-1e-6).length};
  }
  if(action==='confirm') {
    if(old.status!=='new')fail('Pedido já confirmado.');
    if(!text(input.confirmation))fail('Registre a confirmação comercial do cliente.');
    return {...old,status:'separating',confirmation:text(input.confirmation)};
  }
  if(old.status==='new')fail('Confirme o pedido antes de separar os produtos.');
  if(!Array.isArray(input.lines)||input.lines.length!==old.source.items.length)fail('Confira todas as linhas.','invalid-argument');
  const lines=input.lines.map((raw,i)=>{
    const item=old.source.items[i],previous=old.lines[i];
    if(raw.line!==item.line||typeof raw.checked!=='boolean'||!quantity(item.quantity)||item.quantity===0||
      !['separated','delivered','resolved'].every(k=>quantity(raw[k])))fail('Quantidades ou linhas inválidas.','invalid-argument');
    const line={line:item.line,separated:raw.separated,delivered:raw.delivered,resolved:raw.resolved,
      dispatched:previous.dispatched,checked:raw.checked,reason:text(raw.reason,80),note:text(raw.note),owner:text(raw.owner,120),
      due:text(raw.due,40),agreement:text(raw.agreement),resolution:text(raw.resolution)};
    if(line.separated+line.resolved>item.quantity+1e-6||line.separated<previous.dispatched||line.delivered>previous.dispatched+1e-6||
      line.delivered<previous.delivered||line.resolved<previous.resolved)fail('Os saldos não podem exceder o pedido ou apagar saídas, entregas e resoluções.');
    if(action!=='deliver'&&!eq(line.delivered,previous.delivered))fail('Use Registrar entrega para confirmar as quantidades entregues.');
    if(line.resolved>previous.resolved&&(!line.resolution||!line.agreement))fail('Resolver sem entrega exige motivo e acordo com o cliente. Isso não altera a NF-e.');
    const shortage=line.separated+line.resolved<item.quantity-1e-6;
    const deadline=line.due?Date.parse(line.due):NaN;
    if(line.due&&!Number.isFinite(deadline))fail('Prazo inválido.');
    if(['verify','dispatch'].includes(action)) {
      if(!line.checked)fail('Confirme a conferência de cada produto, inclusive os itens com falta.');
      if(shortage&&(!line.reason||!line.note||!line.owner||!Number.isFinite(deadline)||!line.agreement))fail('Cada falta exige motivo, observação, responsável, prazo e acordo com o cliente.');
      if(shortage&&deadline<+now)fail('Atualize o prazo vencido antes de liberar a conferência.');
    }
    return line;
  });
  const remaining=lines.some((l,i)=>l.delivered+l.resolved<old.source.items[i].quantity-1e-6);
  const shortage=lines.some((l,i)=>l.separated+l.resolved<old.source.items[i].quantity-1e-6);
  let status=old.status,reviewed=old.reviewed;
  if(action==='save') {reviewed=false;status=lines.some(l=>l.dispatched>l.delivered)?'route':shortage?'pending':'separating';}
  if(action==='verify') {reviewed=true;status=shortage?'pending':'verified';}
  if(action==='dispatch') {
    if(!old.reviewed||hash(lines)!==hash(old.lines))fail('Salve e confira os dados antes de registrar a saída.');
    if(!old.fiscal?.authorized)fail('A saída requer NF-e vinculada e autorizada no Bling.');
    if(!lines.some(l=>l.separated>l.dispatched))fail('Não há nova quantidade separada para sair.');
    if(shortage&&input.partialApproved!==true)fail('Confirme explicitamente a saída parcial.');
    for(const line of lines)line.dispatched=line.separated;
    status='route';
  }
  if(action==='deliver') {
    if(!lines.some((l,i)=>l.delivered>old.lines[i].delivered))fail('Informe a nova quantidade entregue.');
    if(!text(input.receipt))fail('Registre quem recebeu, quando e a evidência da entrega.');
    reviewed=false;status=remaining?'pending':'delivered';
  }
  if(action==='close') {
    if(remaining)fail('Ainda existem quantidades pendentes. Registre entrega ou resolução por item.');
    status='closed';reviewed=false;
  }
  return {...old,lines,status,reviewed,pendingCount:lines.filter((l,i)=>l.delivered+l.resolved<old.source.items[i].quantity-1e-6).length,
    dueAt:lines.filter((l,i)=>l.delivered+l.resolved<old.source.items[i].quantity-1e-6&&l.due).map(l=>l.due).sort()[0]??null};
}

export function createOrderCare({db,authenticated,requireAdmin,rateLimit,loadOrder,loadInvoice}) {
 return async request=>{
  const user=await authenticated(request);await requireAdmin(user);await rateLimit(user.uid,'order_care',20);
  const input=request.data??{},id=input.orderId;
  if(typeof id!=='string'||! /^[1-9]\d{0,15}$/.test(id)||!Number.isSafeInteger(Number(id)))fail('Pedido inválido.','invalid-argument');
  const actions=['open','confirm','save','verify','dispatch','deliver','close','reconcile'];
  if(!actions.includes(input.action))fail('Ação inválida.','invalid-argument');
  if(input.action!=='open'&&(!Number.isSafeInteger(input.revision)||input.revision<1||! /^[a-zA-Z0-9-]{16,80}$/.test(input.requestId??'')))fail('Revisão ou operação inválida.','invalid-argument');
  const source=await loadOrder(request,id);
  if(Buffer.byteLength(JSON.stringify(source))+Buffer.byteLength(JSON.stringify(input))>350000)fail('Pedido muito grande para uma única conferência. Solicite revisão administrativa.','resource-exhausted');
  if(source.id!==id||!source.items?.length)fail('Origem do pedido inválida.','data-loss');
  let fiscal={id:source.invoiceId,authorized:false,number:'',status:'Sem NF-e vinculada'};
  if(source.invoiceId) {
    const invoice=await loadInvoice(request,source.invoiceId);
    fiscal={id:source.invoiceId,authorized:['5','6'].includes(invoice.invoice.status),number:invoice.invoice.code,status:invoice.invoice.statusLabel};
  }
  await requireAdmin(await authenticated(request));
  const ref=db.doc(`order_care/${id}`),requestId=input.action==='open'?randomUUID():input.requestId;
  const audit=ref.collection('audit').doc(requestId),command=hash(input);
  return db.runTransaction(async tx=>{
    const [stored,operation]=await tx.getAll(ref,audit);
    const now=Timestamp.now(),prior=stored.data(),sourceHash=sourceFingerprint(source);
    if(operation.exists) {
      if(operation.data().command!==command)fail('Operação já usada com outros dados.','already-exists');
      return {order:prior};
    }
    let order=prior??{id,source,sourceHash,lines:initialLines(source),status:'new',reviewed:false,revision:0,createdAt:now.toDate().toISOString(),pendingCount:source.items.length};
    if(input.action!=='open'&&order.revision!==input.revision)fail('Outro administrador atualizou este atendimento. Reabra antes de continuar.','aborted');
    const changed=order.sourceHash!==sourceHash;
    order={...order,fiscal,sourceChanged:changed,latestSource:changed?source:null};
    if(!changed)order.source=source;
    if(input.action!=='open')order=careTransition(order,input,now.toDate());
    order={...order,revision:order.revision+1,updatedAt:now.toDate().toISOString(),updatedBy:user.uid,updatedByName:user.displayName??user.email};
    tx.set(ref,order);
    if(source.invoiceId)tx.set(db.doc(`order_care_invoice_links/${source.invoiceId}/orders/${id}`),{orderId:id,linkedAt:now});
    tx.create(audit,{action:input.action,command,actor:user.uid,actorName:user.displayName??user.email,at:now,
      revision:order.revision,sourceHash,lines:order.lines,previousLines:prior?.lines??null,source:order.source,
      status:order.status,confirmation:text(input.confirmation),receipt:text(input.receipt),partialApproved:input.partialApproved===true});
    if(input.action!=='open')tx.create(db.doc(`admin_bling_events/care_${id}_${requestId}`),{
      title:'Atendimento do pedido',body:`Pedido ${source.code} • ${source.name}\n${actionLabel[input.action]}\nProdutos pendentes: ${order.pendingCount}\nResponsável: ${user.displayName??user.email}`,
      kind:'Bling • Administrador',group:'orderCare',recordId:id,publishedAt:now,expiresAt:Timestamp.fromMillis(now.toMillis()+90*86400000)});
    return {order};
  });
 };
}

// One reminder per case/day. Reading a notification never modifies the case.
export async function remindOrderCare(db) {
  const day=new Date().toISOString().slice(0,10);
  const cases=await db.collection('order_care').where('dueAt','<=',new Date(Date.now()+24*3600000).toISOString()).get();
  for(const doc of cases.docs) {
    await db.runTransaction(async tx=>{
      const event=db.doc(`admin_bling_events/care_due_${doc.id}_${day}`);
      const [current,sent]=await tx.getAll(doc.ref,event);const order=current.data();
      if(sent.exists||!order?.dueAt||order.status==='closed'||!order.pendingCount)return;
      const now=Timestamp.now();
      tx.create(event,{title:'Prazo de atendimento',body:`Pedido ${order.source.code} • ${order.source.name}\nHá ${order.pendingCount} produto(s) pendente(s).\nPrazo: ${order.dueAt}\nAbra a central para resolver.`,
        kind:'Bling • Administrador',group:'orderCare',recordId:doc.id,publishedAt:now,expiresAt:Timestamp.fromMillis(now.toMillis()+90*86400000)});
    });
  }
}
