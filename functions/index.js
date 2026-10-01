import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore, FieldValue, Timestamp} from 'firebase-admin/firestore';
import {onCall, onRequest, HttpsError} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {onDocumentWritten, onDocumentCreated} from 'firebase-functions/v2/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {catalogGroups, reconcileNotifications, deviceKey, sendAdminEvent} from './bling-notifications.js';
import {createScheduledBlingSync} from './bling-scheduled-sync.js';
import {createBlingHandlers} from './bling.js';
import {createBlingWebhook} from './bling-live-sync.js';
import {defineSecret} from 'firebase-functions/params';
import {createBlingDataHandler} from './bling-data.js';
import {LEGAL_VERSION, ROLES, validName, inviteProblem, normalizePhone} from './validation.js';
import {personalData} from './personal-data.js';
import {createProductionOrders} from './production-orders.js';
import {createOrderCare,remindOrderCare} from './order-care.js';

initializeApp();
const db = getFirestore();
// App Check is required in production. Use registered debug tokens for local APKs.
const options = {region: 'southamerica-east1', enforceAppCheck: true, maxInstances: 10};
const bling = createBlingHandlers({db, auth: getAuth(), authenticated, requireAdmin, rateLimit});
const blingOptions = {...options, maxInstances: 2, concurrency: 20, timeoutSeconds: 60};
const liveRead = createBlingDataHandler({db, authenticated, requireAdmin, rateLimit:async()=>{},allowLiveSync:true});
async function syncLive(event) {
  const connection=(await db.doc('integrations_private/bling').get()).data();
  if(!connection?.connectedBy) return;
  return liveRead({auth:{uid:connection.connectedBy},data:{kind:'liveSync',...(event?{event}:{})}});
}
const blingWebhookSecret=defineSecret('BLING_CLIENT_SECRET');
export const blingWebhook = onRequest({region:'southamerica-east1',timeoutSeconds:15,maxInstances:2,invoker:'public',secrets:[blingWebhookSecret]},
  createBlingWebhook({db,readCredentials:async()=>({clientSecret:blingWebhookSecret.value()})}));
export const blingWebhookWorker = onDocumentCreated({region:'southamerica-east1',document:'bling_webhook_queue/{eventId}',
  timeoutSeconds:120,maxInstances:1,concurrency:1,retry:true},async event=>{
    const ref=event.data.ref;
    const data=(await ref.get()).data();
    if(data?.status==='complete')return;
    await syncLive(data);
    await ref.update({status:'complete',processedAt:FieldValue.serverTimestamp()});
  });
export const blingLivePoll = onSchedule({region:'southamerica-east1',schedule:'every 1 minutes',
  timeZone:'America/Sao_Paulo',timeoutSeconds:120,maxInstances:1,retryCount:0},()=>syncLive());
export const blingCatalogNotifications = onDocumentWritten({region:'southamerica-east1',document:'integrations_private/{catalog}',
  timeoutSeconds:540,maxInstances:1,concurrency:1,retry:true}, async event => {
  const group=catalogGroups[event.params.catalog];
  const after=event.data?.after.data()?.complete;
  if(!group || !after || after.runId===event.data?.before.data()?.complete?.runId) return;
  // Ignore obsolete delivery; staging slots can already belong to another run.
  const current=(await db.doc(`integrations_private/${event.params.catalog}`).get()).data()?.complete;
  if(current?.runId!==after.runId) return;
  await reconcileNotifications(db,group,after);
});
export const blingPushNotification = onDocumentCreated({region:'southamerica-east1',document:'admin_bling_events/{eventId}',
  timeoutSeconds:120,maxInstances:1,retry:true},event=>sendAdminEvent({db,auth:getAuth(),messaging:getMessaging(),eventId:event.params.eventId}));
export const registerAdminNotifications = onCall(options,async request=>{
  const user=await authenticated(request);
  const token=request.data?.token;
  if(typeof token!=='string'||token.length<20||token.length>4096) throw new HttpsError('invalid-argument','Dispositivo inválido.');
  const ref=db.doc(`admin_notification_devices/${deviceKey(token)}`);
  if(request.data?.remove===true) {
    await db.runTransaction(async tx=>{if((await tx.get(ref)).data()?.uid===user.uid)tx.delete(ref);});
    return {registered:false};
  }
  await requireAdmin(user);
  await rateLimit(user.uid,'push_registration',30);
  await ref.set({uid:user.uid,token,updatedAt:FieldValue.serverTimestamp()});
  return {registered:true};
});
export const blingConnectionStatus = onCall(blingOptions, bling.status);
export const blingBeginAuthorization = onCall(blingOptions, bling.begin);
export const blingReadData = onCall(blingOptions,
  createBlingDataHandler({db, authenticated, requireAdmin, rateLimit}));
const productionRead=createBlingDataHandler({db,authenticated,requireAdmin,rateLimit:async()=>{}});
export const orderCare=onCall(blingOptions,createOrderCare({db,authenticated,requireAdmin,rateLimit,
  loadOrder:(request,id)=>productionRead({...request,data:{kind:'salesOrder',orderId:id}}),
  loadInvoice:(request,id)=>productionRead({...request,data:{kind:'invoiceItems',invoiceId:id}})}));
export const orderCareReminders=onSchedule({region:'southamerica-east1',schedule:'every 60 minutes',
  timeZone:'America/Sao_Paulo',timeoutSeconds:120,maxInstances:1},()=>remindOrderCare(db));
export const productionOrder=onCall(blingOptions,createProductionOrders({db,authenticated,requireAdmin,rateLimit,
  loadInvoice:async(request,id)=>{
    const details=await productionRead({...request,data:{kind:'invoiceItems',invoiceId:id}});
    const mirror=(await db.doc(`bling_private_invoices/${id}`).get()).data()??{};
    return {...details,invoice:{...details.invoice,recipientName:mirror.recipientName??'',recipientDocument:mirror.recipientDocument??''}};
  }}));
export const blingScheduledSync = onSchedule({region:'southamerica-east1',schedule:'every 6 hours',
  timeZone:'America/Sao_Paulo',timeoutSeconds:1800,maxInstances:1,retryCount:1},
  createScheduledBlingSync({db,read:createBlingDataHandler({db,authenticated,requireAdmin,rateLimit:async()=>{}})}));
export const blingCallback = onRequest({region: 'southamerica-east1', maxInstances: 2,
  concurrency: 20, timeoutSeconds: 60, invoker: 'public'}, bling.callback);
const fail = (message, code = 'invalid-argument') => { throw new HttpsError(code, message); };

async function authenticated(request, verified = true) {
  if (!request.auth) fail('Entre novamente para continuar.', 'unauthenticated');
  const user = await getAuth().getUser(request.auth.uid);
  if (user.disabled || !user.email) fail('Acesso indisponível.', 'permission-denied');
  if (verified && !user.emailVerified) fail('Verifique seu e-mail antes de continuar.', 'failed-precondition');
  return user;
}

async function requireAdmin(user) {
  const data = (await db.doc(`admin/${user.uid}`).get()).data();
  if (!data || data.eAdministrador !== true || data.ativo !== true ||
      typeof data.email !== 'string' || data.email.toLowerCase() !== user.email.toLowerCase()) {
    fail('Apenas administradores ativos podem realizar esta ação.', 'permission-denied');
  }
}

async function rateLimit(uid, operation, limit = 10) {
  const ref = db.doc(`account_rate_limits/${uid}_${operation}`);
  await db.runTransaction(async tx => {
    const data = (await tx.get(ref)).data();
    const now = Date.now();
    const current = data && now - data.startedAt.toMillis() < 60000;
    if (current && data.count >= limit) fail('Muitas tentativas. Aguarde um minuto.', 'resource-exhausted');
    tx.set(ref, {startedAt: current ? data.startedAt : Timestamp.fromMillis(now), count: current ? data.count + 1 : 1});
  });
}

export const registerAccount = onCall(options, async request => {
  const user = await authenticated(request);
  await rateLimit(user.uid, 'registration');
  const input = request.data ?? {};
  if (!validName(input.name)) fail('Informe um nome válido entre 2 e 160 caracteres.');
  if (input.acceptTerms !== true || input.legalVersion !== LEGAL_VERSION || typeof input.offers !== 'boolean') {
    fail('Leia e aceite a versão atual dos termos para concluir.');
  }
  const code = typeof input.inviteCode === 'string' ? input.inviteCode.trim().toUpperCase() : '';
  if (code && !/^M[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{7}$/.test(code)) {
    fail('Código inválido. Confira ou continue sem código.');
  }
  const ref = db.doc(`users/${user.uid}`);
  await db.runTransaction(async tx => {
    const existing = await tx.get(ref);
    if (existing.exists) {
      // Retry after a lost response is safe; adding/changing a referral later is forbidden.
      if (code && existing.data().referral?.code !== code) fail('O convite só pode ser informado no cadastro inicial.', 'failed-precondition');
      return;
    }
    const admin = await tx.get(db.doc(`admin/${user.uid}`));
    if (admin.exists) fail('Esta conta administrativa já está cadastrada.', 'failed-precondition');
    let inviteRef, invite;
    if (code) {
      const index = (await tx.get(db.doc(`access_invite_code_index/${code}`))).data();
      if (!index || typeof index.inviteId !== 'string' || !/^[a-zA-Z0-9]{20}$/.test(index.inviteId)) fail('Código inválido. Confira ou continue sem código.');
      inviteRef = db.doc(`access_invites/${index.inviteId}`);
      invite = (await tx.get(inviteRef)).data();
      const problem = inviteProblem(invite, Date.now());
      if (problem) fail(problem);
      if (invite.inviteCode !== code || invite.profile !== 'Mestre' || !invite.expiresAt) fail('Convite incompatível. Solicite um novo convite ao administrador.');
      const phone = normalizePhone(input.phone);
      if (typeof invite.email !== 'string' || invite.email.trim().toLowerCase() !== user.email.trim().toLowerCase() ||
          !phone || phone !== invite.whatsapp) {
        fail('O e-mail e o telefone devem corresponder aos dados do convite. Confira com o administrador ou remova o código.');
      }
    }
    const timestamp = FieldValue.serverTimestamp();
    tx.create(ref, {
      name: input.name.trim(), email: user.email, role: invite ? 'master' : 'consumer', active: true,
      offers: input.offers, offersUpdatedAt: timestamp,
      legalVersion: LEGAL_VERSION, termsAcceptedAt: timestamp, privacyAcknowledgedAt: timestamp,
      createdAt: timestamp, updatedAt: timestamp,
      referral: invite ? {inviteId: inviteRef.id, code, createdByUid: invite.createdByUid,
        profileReference: invite.profile, collaboratorFunction: invite.collaboratorFunction ?? null} : null,
    });
    tx.create(db.doc(`personal_data/${user.uid}`), {name: input.name.trim(), personType: 'individual',
      phone: invite ? normalizePhone(input.phone) : '', phoneVerified: false,
      cpf: '', cnpj: '', documentKind: '', document: '', offers: input.offers, updatedAt: timestamp});
    if (invite) tx.update(inviteRef, {isUsed: true, registrationEnabled: false,
      status: 'used', usedAt: timestamp, usedByUid: user.uid});
  });
  return {success: true};
});

export const updateMyData = onCall(options, async request => {
  // Existing administrator accounts keep their current verification policy.
  const user = await authenticated(request, false);
  await rateLimit(user.uid, 'data');
  const input = request.data ?? {};
  if (!validName(input.name) || typeof input.offers !== 'boolean') fail('Confira nome e preferência de ofertas.');
  await db.runTransaction(async tx => {
    const profileRef = db.doc(`users/${user.uid}`);
    const profile = await tx.get(profileRef);
    const admin = (await tx.get(db.doc(`admin/${user.uid}`))).data();
    const personalRef = db.doc(`personal_data/${user.uid}`);
    const previous = (await tx.get(personalRef)).data() ?? {};
    const activeAdmin = admin?.eAdministrador === true && admin?.ativo === true &&
      typeof admin.email === 'string' && admin.email.toLowerCase() === user.email.toLowerCase();
    if (admin && !activeAdmin) fail('Acesso administrativo indisponível.', 'permission-denied');
    if (!activeAdmin && (!user.emailVerified || !profile.exists || profile.data().active !== true)) {
      fail('Conta sem acesso. Entre novamente.', 'permission-denied');
    }
    const timestamp = FieldValue.serverTimestamp();
    let editable;
    try { editable = personalData(input, previous, user); }
    catch (error) { fail(error.message); }
    if (profile.exists) tx.update(profileRef, {name: input.name.trim(), offers: input.offers,
      offersUpdatedAt: timestamp, updatedAt: timestamp});
    tx.set(personalRef, {...editable, updatedAt: timestamp}, {merge: true});
  });
  return {success: true};
});

export const setUserRole = onCall(options, async request => {
  const user = await authenticated(request, false);
  await requireAdmin(user);
  await rateLimit(user.uid, 'roles', 30);
  const {uid, role, active} = request.data ?? {};
  if (typeof uid !== 'string' || !/^[a-zA-Z0-9_-]{1,128}$/.test(uid) || !ROLES.includes(role) || typeof active !== 'boolean') {
    fail('Informe usuário, perfil e situação válidos.');
  }
  await db.runTransaction(async tx => {
    // Recheck privileges inside the same transaction as the role change.
    const admin = (await tx.get(db.doc(`admin/${user.uid}`))).data();
    if (admin?.eAdministrador !== true || admin?.ativo !== true ||
        typeof admin.email !== 'string' || admin.email.toLowerCase() !== user.email.toLowerCase()) fail('Acesso revogado.', 'permission-denied');
    const targetAdmin = await tx.get(db.doc(`admin/${uid}`));
    const ref = db.doc(`users/${uid}`);
    const target = await tx.get(ref);
    if (targetAdmin.exists || !target.exists) fail('Usuário indisponível para esta operação.', 'failed-precondition');
    if (role === 'master' && target.data().role !== 'master') fail('O perfil Mestre exige cadastro com convite válido.', 'failed-precondition');
    const timestamp = FieldValue.serverTimestamp();
    tx.update(ref, {role, active, updatedAt: timestamp});
    tx.create(db.collection('account_audit').doc(), {actorUid: user.uid, targetUid: uid,
      previousRole: target.data().role, role, active, createdAt: timestamp});
  });
  return {success: true};
});
