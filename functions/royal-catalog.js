import {createHash} from 'node:crypto';
import {FieldPath, Timestamp} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
import {readProductCatalog} from './bling-product-list.js';

const fail=(message,code='invalid-argument',details)=>{throw new HttpsError(code,message,details);};
const idPattern=/^[a-zA-Z0-9_-]{1,100}$/;
const categories=['papeis-higiene','limpeza-profissional','cuidados-pessoais','descartaveis-alimentacao','embalagens-conservacao','dispensers-acessorios','protecao-profissional'];
const niches=['Lançamentos','Ofertas','Dia a dia','Kits','Básicos'];
const text=(value,min,max,label)=>{if(typeof value!=='string'||value.trim().length<min||value.length>max)fail(`Confira ${label}.`);return value.trim();};
const integer=(value,min=0,max=1000000000)=>{if(!Number.isSafeInteger(value)||value<min||value>max)fail('Informe uma quantidade ou valor válido.');return value;};
const stamp=value=>value?.toDate?.().toISOString()??null;
async function sourceRecord(db,id) {
  const [mirror,live]=await db.getAll(db.doc(`bling_private_products/${id}`),db.doc(`bling_live_records/products_${id}`));
  const old=mirror.data(),recent=live.data();
  if(recent&&(!old||Date.parse(recent.observedAt)>Date.parse(old.detailsCheckedAt??old.checkedAt??'1970-01-01')))
    return {...old,...recent,...(recent.deleted?{status:'E'}:{})};
  return old??null;
}
export const stockTotal=stock=>stock.boxes*stock.unitsPerBox+stock.loose;
export function convertedUnits(quantity,factor) {
  integer(quantity,0);integer(factor,1);
  if(quantity%factor!==0)fail('A referência não corresponde a unidades inteiras. Confira a NF-e.','failed-precondition');
  return quantity/factor;
}
export function validateCatalog(data,publish=false) {
  if(!data||typeof data!=='object'||Array.isArray(data))fail('Cadastro inválido.');
  const value={code:text(data.code,1,100,'a identificação'),title:text(data.title,3,120,'o título'),
    description:text(data.description??'',publish?1:0,5000,'a descrição'),measure:text(data.measure,1,120,'a medida'),
    unit:text(data.unit,1,30,'a unidade'),referenceCents:integer(data.referenceCents),factorMilli:integer(data.factorMilli,1,100000000),
    unitsPerBox:integer(data.unitsPerBox,1,1000000),threshold:integer(data.threshold),
    categories:Array.isArray(data.categories)?[...new Set(data.categories)]:[],niches:Array.isArray(data.niches)?[...new Set(data.niches)]:[]};
  if(value.categories.some(v=>!categories.includes(v))||value.niches.some(v=>!niches.includes(v)))fail('Escolha categorias e nichos existentes.');
  if(publish&&(!value.categories.length||!value.niches.length))fail('Escolha ao menos uma categoria e um nicho.');
  if(!Array.isArray(data.presentations)||!data.presentations.length||data.presentations.length>2)fail('Informe as apresentações do produto.');
  const keys=new Set();
  value.presentations=data.presentations.map(p=>{
    if(!p||typeof p!=='object')fail('Apresentação inválida.');
    if(!['unit','box'].includes(p.kind)||keys.has(p.kind))fail('Apresentação duplicada ou inválida.');keys.add(p.kind);
    const imageUrl=text(p.imageUrl??'',0,2048,'a foto');
    if(imageUrl&&!/^https:\/\//.test(imageUrl))fail('Use uma foto enviada ou um endereço HTTPS.');
    if(publish&&!imageUrl)fail('Cada apresentação precisa de uma foto principal.');
    const result={kind:p.kind,imageUrl,costCents:integer(p.costCents),pfCents:integer(p.pfCents),pjCents:integer(p.pjCents),minCents:integer(p.minCents)};
    if(publish&&Object.entries(result).some(([k,v])=>k.endsWith('Cents')&&v<=0))fail('Preencha custo e todos os preços de cada apresentação.');
    if(result.minCents>result.pfCents||result.minCents>result.pjCents)fail('O mínimo de negociação não pode superar os preços de venda.');
    return result;
  });
  return value;
}
export function moveStock(old,input) {
  const s={...old};const boxes=integer(input.boxes??0),loose=integer(input.loose??0);
  const quantity=boxes*s.unitsPerBox+loose;
  if(!['entry','exit','open','return','release','loss','adjust'].includes(input.type))fail('Movimentação inválida.');
  if(input.type!=='adjust'&&!quantity)fail('Informe a quantidade movimentada.');
  if(input.type==='open') {
    if(!boxes||loose||boxes>s.boxes)fail('Confira as caixas fechadas disponíveis.');
    s.boxes-=boxes;s.loose+=boxes*s.unitsPerBox;
  } else if(input.type==='return') s.held=(s.held??0)+quantity;
  else if(input.type==='release') {
    if(quantity>(s.held??0))fail('Confira as unidades aguardando conferência.');
    s.held-=quantity;s.boxes+=boxes;s.loose+=loose;
  } else if(input.type==='entry') {s.boxes+=boxes;s.loose+=loose;}
  else if(input.type==='adjust') {s.boxes=boxes;s.loose=loose;}
  else {
    if(boxes>s.boxes||loose>s.loose)fail('Saldo insuficiente. Confirme a abertura de caixas antes de retirar unidades.','failed-precondition');
    s.boxes-=boxes;s.loose-=loose;
  }
  integer(s.boxes);integer(s.loose);integer(s.held??0);integer(stockTotal(s));
  return s;
}
export function catalogProjection(product,p) {
  const available=p.kind==='box'?product.stock.boxes>0:stockTotal(product.stock)>0;
  return {royalCatalog:true,productId:product.id,presentation:p.kind,title:product.title,
    description:product.description,imageUrl:p.imageUrl,category:product.categories[0],categories:product.categories,niches:product.niches,
    code:product.code,measure:product.measure,unit:product.unit,unitsPerBox:p.kind==='box'?product.unitsPerBox:1,
    published:product.status==='published',quoteOnly:!available,
    pfCents:available?p.pfCents:null,pjCents:available?p.pjCents:null};
}
const response=p=>({...p,updatedAt:stamp(p.updatedAt),createdAt:stamp(p.createdAt)});
export function createRoyalCatalog({db,authenticated,requireAdmin,rateLimit}) {
 return async request=>{
  const user=await authenticated(request);await requireAdmin(user);await rateLimit(user.uid,'royal_catalog',120);
  const input=request.data??{};
  if(input.action==='list') {
    const mode=input.mode==='production'?'production':'products';const filter=input.filter??(mode==='production'?'available':'recipe');
    const source=mode==='production'&&['available','excluded'].includes(filter);
    let query=db.collection(source?'bling_private_products':'royal_catalog_private');
    query=query.orderBy(FieldPath.documentId());
    if(input.cursor){if(!idPattern.test(input.cursor))fail('Página inválida.');if(!input.cursor.startsWith('page_'))query=query.startAfter(input.cursor);}
    let docs,nextCursor;
    if(source&&filter==='available'&&(!input.cursor||input.cursor.startsWith('page_'))) {
      try {
        const page=input.cursor?Number(input.cursor.slice(5)):1;
        if(!Number.isInteger(page)||page<1||page>10000)fail('Página inválida.');
        const result=await readProductCatalog(db,{page});
        docs=result.items.map(p=>({id:p.id,data:()=>p}));nextCursor=result.hasMore?`page_${page+1}`:null;
      }catch(e){if(e.code!=='failed-precondition')throw e;}
    }
    if(!docs){docs=(await query.limit(100).get()).docs;nextCursor=docs.length===100?docs.at(-1).id:null;}
    let rows;
    if(source) {
      const audited=docs.length?await db.getAll(...docs.map(d=>db.doc(`royal_catalog_private/b_${d.id}`))):[];
      const live=docs.length?await db.getAll(...docs.map(doc=>db.doc(`bling_live_records/products_${doc.id}`))):[];
      const origins=docs.map((doc,i)=>{
        const old=doc.data(),recent=live[i]?.data();
        return recent&&Date.parse(recent.observedAt)>Date.parse(old.detailsCheckedAt??old.checkedAt??'1970-01-01')?{...old,...recent,...(recent.deleted?{status:'E'}:{})}:old;
      });
      rows=docs.flatMap((doc,i)=>{const origin=origins[i]??doc.data(),own=audited[i]?.data();
        if(filter==='available'&&(origin.status==='E'||own?.audited))return [];
        if(filter==='excluded'&&origin.status!=='E')return [];
        return [{id:`b_${doc.id}`,sourceId:doc.id,title:origin.name,code:origin.code,sourcePrice:origin.price,originStatus:origin.status,source:origin,revision:own?.revision??0,audited:own?.audited??false}];});
    } else rows=docs.map(d=>response({...d.data(),id:d.id})).filter(p=>mode==='production'?p.audited:
      !p.archived&&(filter==='observation'?p.status==='published'&&stockTotal(p.stock)<=p.threshold:p.status===filter));
    if(mode==='production'&&filter==='available'&&!input.cursor) {
      const drafts=(await db.collection('royal_catalog_drafts').where('by','==',user.uid).limit(100).get()).docs;
      for(const d of drafts) {
        const id=d.id.slice(user.uid.length+1),draft=d.data().draft;
        if(!id.startsWith('n_')||rows.some(r=>r.id===id))continue;
        const product=(await db.doc(`royal_catalog_private/${id}`).get()).data();
        if(!product?.audited)rows.unshift({id,title:draft.product?.title||'Novo produto · rascunho',code:draft.product?.code??'',revision:0,audited:false});
      }
    }
    return {items:rows,cursor:nextCursor};
  }
  if(typeof input.id!=='string'||!idPattern.test(input.id))fail('Produto inválido.');
  const ref=db.doc(`royal_catalog_private/${input.id}`);
  const draftRef=db.doc(`royal_catalog_drafts/${user.uid}_${input.id}`);
  if(input.action==='draft') {
    if(!input.draft||JSON.stringify(input.draft).length>50000)fail('Rascunho inválido.');
    integer(input.draft.revision);text(input.draft.savedAt,10,40,'a data do rascunho');
    await db.runTransaction(async tx=>{
      const [product,stored]=await tx.getAll(ref,draftRef);
      if(input.draft.revision<(product.data()?.revision??0))return;
      if((stored.data()?.draft?.savedAt??'')>input.draft.savedAt)return;
      tx.set(draftRef,{draft:input.draft,updatedAt:Timestamp.now(),by:user.uid});
    });
    return {saved:true};
  }
  if(input.action==='get') {
    const own=(await ref.get()).data();
    const draft=(await draftRef.get()).data()?.draft??null;
    if(own)return {...response({...own,id:input.id}),draft};
    let source=null;
    if(input.id.startsWith('b_'))source=await sourceRecord(db,input.id.slice(2));
    if(input.id.startsWith('b_')&&!source)fail('Referência não encontrada. Atualize a lista.','not-found');
    return {id:input.id,revision:0,source,sourceId:source?input.id.slice(2):null,status:'recipe',audited:false,draft};
  }
  if(input.action==='history') {
    const docs=(await ref.collection('history').orderBy('at','desc').limit(50).get()).docs;
    return {items:docs.map(d=>({...d.data(),id:d.id,at:stamp(d.data().at)}))};
  }
  if(!['save','publish','suspend','archive','restore','stock'].includes(input.action)||!idPattern.test(input.requestId??''))fail('Operação inválida.');
  integer(input.revision);
  const eventRef=ref.collection('history').doc(input.requestId);
  const command=createHash('sha256').update(JSON.stringify(input)).digest('hex');
  const origin=input.id.startsWith('b_')?await sourceRecord(db,input.id.slice(2)):null;
  return db.runTransaction(async tx=>{
    const [snap,event]=await tx.getAll(ref,eventRef);const old=snap.data();
    if(event.exists){if(event.data().command!==command)fail('Identificador já utilizado.');return response({...old,id:input.id});}
    if((old?.revision??0)!==input.revision)fail('Este produto foi atualizado. Revise antes de salvar.','aborted',{updatedAt:stamp(old?.updatedAt),updatedBy:old?.updatedBy??'',revision:old?.revision??0});
    if(old?.archived&&input.action!=='restore')fail('Produto arquivado. Restaure para Receitas antes de editar.','failed-precondition');
    const now=Timestamp.now();let next={...old,id:input.id};let movement=null;
    if(['save','publish'].includes(input.action)) {
      const data=validateCatalog(input.product,input.action==='publish'||old?.status==='published');
      if(old&&(data.unitsPerBox!==old.unitsPerBox||data.factorMilli!==old.factorMilli)&&input.confirmConversion!==true)fail('Confirme a alteração da conversão e da embalagem.','failed-precondition');
      const codeKey=createHash('sha256').update(data.code.toLocaleLowerCase('pt-BR')).digest('hex');
      const codeRef=db.doc(`royal_catalog_codes/${codeKey}`);
      const occupied=(await tx.get(codeRef)).data();
      if(occupied&&occupied.id!==input.id)fail('Esta identificação já pertence a outro produto auditado. Use o cadastro existente ou uma identificação diferente.','already-exists');
      if(old&&data.unitsPerBox!==old.unitsPerBox&&(stockTotal(old.stock)>0||(old.stock.held??0)>0))fail('Confira e zere o saldo antes de alterar unidades por caixa.','failed-precondition');
      if(!old&&input.id.startsWith('b_')&&!origin)fail('Referência de origem indisponível.','not-found');
      const initial=input.product.initialStock;
      const stock=old?.stock?.confirmed?{...old.stock,unitsPerBox:data.unitsPerBox}:
        {boxes:integer(initial?.boxes??0),loose:integer(initial?.loose??0),held:0,unitsPerBox:data.unitsPerBox,confirmed:initial?.confirmed===true};
      if(input.action==='publish'&&!stock.confirmed)fail('Confirme caixas fechadas e unidades avulsas antes de publicar.');
      integer(stockTotal(stock));
      next={...next,...data,stock,audited:true,source:old?.source??origin??null,sourceId:old?.sourceId??(origin?input.id.slice(2):null),
        status:input.action==='publish'?'published':old?.status??'recipe'};
      if(old?.code&&old.code.toLocaleLowerCase('pt-BR')!==data.code.toLocaleLowerCase('pt-BR'))tx.delete(db.doc(`royal_catalog_codes/${createHash('sha256').update(old.code.toLocaleLowerCase('pt-BR')).digest('hex')}`));
      tx.set(codeRef,{id:input.id});
    } else {
      if(!old)fail('Produto não encontrado.','not-found');
      if(input.action==='stock') {
        text(input.reason,3,500,'o motivo');
        if(!old.stock.confirmed)fail('Confirme o estoque inicial na edição.','failed-precondition');
        next.stock=moveStock(old.stock,input);movement={type:input.type,boxes:input.boxes??0,loose:input.loose??0,before:old.stock,after:next.stock};
        if(input.type==='entry'&&input.costCents!==undefined) {
          const cost=integer(input.costCents,1);next.lastCostCents=cost;movement.costCents=cost;
        }
      } else if(input.action==='suspend')next.status='suspended';
      else if(input.action==='restore'){next.archived=false;next.status='recipe';}
      else {next.archived=true;next.status='suspended';}
    }
    next.revision=(old?.revision??0)+1;next.updatedAt=now;next.updatedBy=user.uid;next.createdAt=old?.createdAt??now;
    tx.set(ref,next);
    if(['save','publish','restore'].includes(input.action))tx.delete(draftRef);
    tx.create(eventRef,{command,action:input.action,reason:input.reason??'',movement,at:now,by:user.uid,revision:next.revision,
      prices:next.presentations.map(p=>({kind:p.kind,costCents:p.costCents,pfCents:p.pfCents,pjCents:p.pjCents,minCents:p.minCents}))});
    for(const kind of ['unit','box']) {
      const p=next.presentations.find(v=>v.kind===kind);const pub=db.doc(`products/royal_${input.id}_${kind}`);
      if(p)tx.set(pub,{...catalogProjection(next,p),createdAt:next.createdAt,updatedAt:now});else tx.delete(pub);
    }
    return response(next);
  });
 };
}
