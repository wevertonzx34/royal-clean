import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore, FieldValue, Timestamp} from 'firebase-admin/firestore';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {LEGAL_VERSION, ROLES, validName, validDocument, normalizeDocument, inviteProblem, normalizePhone} from './validation.js';

initializeApp();
const db = getFirestore();
// App Check is required in production. Use registered debug tokens for local APKs.
const options = {region: 'southamerica-east1', enforceAppCheck: true, maxInstances: 10};
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
    if (invite) tx.create(db.doc(`personal_data/${user.uid}`), {name: input.name.trim(),
      phone: normalizePhone(input.phone), phoneVerified: false, documentKind: '', document: '', offers: input.offers, updatedAt: timestamp});
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
  if (typeof input.document !== 'string') fail('Confira o documento informado.');
  const document = normalizeDocument(input.document);
  const documentKind = input.documentKind ?? '';
  if (!validDocument(documentKind, document)) fail('Confira o CPF ou CNPJ informado.');
  await db.runTransaction(async tx => {
    const profileRef = db.doc(`users/${user.uid}`);
    const profile = await tx.get(profileRef);
    const admin = (await tx.get(db.doc(`admin/${user.uid}`))).data();
    const activeAdmin = admin?.eAdministrador === true && admin?.ativo === true &&
      typeof admin.email === 'string' && admin.email.toLowerCase() === user.email.toLowerCase();
    if (admin && !activeAdmin) fail('Acesso administrativo indisponível.', 'permission-denied');
    if (!activeAdmin && (!user.emailVerified || !profile.exists || profile.data().active !== true)) {
      fail('Conta sem acesso. Entre novamente.', 'permission-denied');
    }
    const timestamp = FieldValue.serverTimestamp();
    if (profile.exists) tx.update(profileRef, {name: input.name.trim(), offers: input.offers,
      offersUpdatedAt: timestamp, updatedAt: timestamp});
    tx.set(db.doc(`personal_data/${user.uid}`), {name: input.name.trim(), documentKind,
      document, offers: input.offers, updatedAt: timestamp}, {merge: true});
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
