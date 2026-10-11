import {randomBytes,createHash} from 'node:crypto';
import {Timestamp} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
const fail=(message,code='invalid-argument')=>{throw new HttpsError(code,message);};
const day=86400000;
const digest=code=>createHash('sha256').update(code).digest('hex');
export function benefitDates(now,activateDays,benefitDays) {
  if(![activateDays,benefitDays].every(v=>Number.isInteger(v)&&v>=1&&v<=365))fail('Escolha prazos de 1 a 365 dias.');
  return {activateUntil:Timestamp.fromMillis(now+activateDays*day),benefitDays};
}
export function createRoyalPriceBenefits({db,authenticated,requireAdmin,rateLimit}) {
 return async request=>{
  const user=await authenticated(request),input=request.data??{};
  await rateLimit(user.uid,'royal_price_benefit',30);
  if(input.action==='status') {
    const p=(await db.doc(`royal_price_entitlements/${user.uid}`).get()).data();
    const invite=p?.inviteId?(await db.doc(`royal_price_invites/${p.inviteId}`).get()).data():null;
    return {active:!!(p&&invite&&!invite.revoked&&p.until.toMillis()>Date.now()),until:p?.until?.toDate().toISOString()??null};
  }
  if(input.action==='redeem') {
    if(typeof input.code!=='string'||!/^RC-[A-F0-9]{20}$/.test(input.code.toUpperCase().trim()))fail('Código inválido.');
    const code=input.code.toUpperCase().trim(),ref=db.doc(`royal_price_invites/${digest(code)}`),profile=db.doc(`royal_price_entitlements/${user.uid}`);
    const account=(await db.doc(`users/${user.uid}`).get()).data(),admin=(await db.doc(`admin/${user.uid}`).get()).data();
    if(!account?.active&&!admin?.ativo)fail('Seu perfil precisa estar ativo.','permission-denied');
    return db.runTransaction(async tx=>{
      const [snap,current]=await tx.getAll(ref,profile),invite=snap.data();
      if(!invite||invite.revoked||invite.usedBy||invite.activateUntil.toMillis()<=Date.now())fail('Convite indisponível ou vencido.','failed-precondition');
      if(invite.targetUid&&invite.targetUid!==user.uid)fail('Este convite pertence a outro perfil.','permission-denied');
      const previous=current.data();
      const previousInvite=previous?.inviteId?(await tx.get(db.doc(`royal_price_invites/${previous.inviteId}`))).data():null;
      if(previous?.until?.toMillis()>Date.now()&&!previousInvite?.revoked)fail('Você já possui um benefício ativo.','failed-precondition');
      const now=Timestamp.now(),until=Timestamp.fromMillis(now.toMillis()+invite.benefitDays*day);
      tx.update(ref,{usedBy:user.uid,usedAt:now,benefitUntil:until});
      tx.set(profile,{inviteId:ref.id,until,activatedAt:now});
      return {active:true,until:until.toDate().toISOString()};
    });
  }
  await requireAdmin(user);
  if(input.action==='create') {
    const dates=benefitDates(Date.now(),input.activateDays,input.benefitDays);
    const targetUid=input.targetUid||null;
    if(targetUid&&(typeof targetUid!=='string'||!/^[a-zA-Z0-9_-]{1,128}$/.test(targetUid)))fail('ID de perfil inválido.');
    if(targetUid&&!(await db.doc(`users/${targetUid}`).get()).exists&&!(await db.doc(`admin/${targetUid}`).get()).exists)fail('Perfil convidado não encontrado.');
    const code=`RC-${randomBytes(10).toString('hex').toUpperCase()}`;
    const ref=db.doc(`royal_price_invites/${digest(code)}`);
    await ref.create({...dates,targetUid,createdAt:Timestamp.now(),createdBy:user.uid,usedBy:null,revoked:false});
    return {id:ref.id,code,activateUntil:dates.activateUntil.toDate().toISOString()};
  }
  if(input.action==='list') {
    const docs=(await db.collection('royal_price_invites').orderBy('createdAt','desc').limit(100).get()).docs;
    return {items:docs.map(d=>{const p=d.data();return {id:d.id,targetUid:p.targetUid,createdBy:p.createdBy,revoked:p.revoked,usedBy:p.usedBy,benefitDays:p.benefitDays,activateUntil:p.activateUntil.toDate().toISOString(),benefitUntil:p.benefitUntil?.toDate().toISOString()??null};})};
  }
  if(input.action==='revoke'&&typeof input.id==='string'&&/^[a-f0-9]{64}$/.test(input.id)) {
    await db.doc(`royal_price_invites/${input.id}`).update({revoked:true,revokedAt:Timestamp.now(),revokedBy:user.uid});return {revoked:true};
  }
  fail('Operação inválida.');
 };
}
