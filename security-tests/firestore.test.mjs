import { readFileSync } from 'node:fs';
import { before, after, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, collection, getDoc, getDocs, setDoc, updateDoc, deleteDoc,
  writeBatch, runTransaction, query, where, orderBy, serverTimestamp, Timestamp } from 'firebase/firestore';

// Hard stop: these tests must never contact a real Firebase project.
if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8185') {
  throw new Error('Use npm test with the local Firestore emulator at 127.0.0.1:8185.');
}
let env;
let admin;
let visitor;
let member;
let inactive;
let mismatch;
let nonAdmin;
let noEmail;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-royal-clean',
    firestore: { host: '127.0.0.1', port: 8185,
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
  admin = env.authenticatedContext('admin-ok', { email: 'admin@example.test' }).firestore();
  visitor = env.unauthenticatedContext().firestore();
  member = env.authenticatedContext('member', { email: 'member@example.test' }).firestore();
  inactive = env.authenticatedContext('inactive', { email: 'inactive@example.test' }).firestore();
  mismatch = env.authenticatedContext('mismatch', { email: 'different@example.test' }).firestore();
  nonAdmin = env.authenticatedContext('nonadmin', { email: 'nonadmin@example.test' }).firestore();
  noEmail = env.authenticatedContext('noemail').firestore();
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    await Promise.all([
      setDoc(doc(db, 'admin/admin-ok'), {email: 'ADMIN@example.test', eAdministrador: true, ativo: true}),
      setDoc(doc(db, 'admin/inactive'), {email: 'inactive@example.test', eAdministrador: true, ativo: false}),
      setDoc(doc(db, 'admin/mismatch'), {email: 'admin@example.test', eAdministrador: true, ativo: true}),
      setDoc(doc(db, 'admin/nonadmin'), {email: 'nonadmin@example.test', eAdministrador: false, ativo: true}),
      setDoc(doc(db, 'admin/noemail'), {email: 'noemail@example.test', eAdministrador: true, ativo: true}),
    ]);
  });
});

function invite(overrides = {}) {
  return {
    inviteId: 'AAAAAAAAAAAAAAAAAAAA', inviteCode: 'UABCDEFG', fullName: 'Pessoa Teste',
    profile: 'Cliente', collaboratorFunction: null, ddd: '11', phoneNumber: '999998888',
    whatsapp: '5511999998888', countryCode: '55', status: 'processing',
    registrationEnabled: true, isUsed: false, createdAt: serverTimestamp(),
    usedAt: null, usedByUid: null, createdByUid: 'admin-ok', createdByEmail: 'admin@example.test',
    ...overrides,
  };
}
function indexes(data) {
  const code = {
    inviteId: data.inviteId, inviteCode: data.inviteCode, profile: data.profile,
    collaboratorFunction: data.collaboratorFunction, createdAt: data.createdAt,
    createdByUid: data.createdByUid,
  };
  return { code, phone: {...code, whatsapp: data.whatsapp} };
}
function paths(data) {
  return {
    invite: `access_invites/${data.inviteId}`,
    code: `access_invite_code_index/${data.inviteCode}`,
    phone: `access_invite_whatsapp_profile_index/${data.whatsapp}_${data.profile.toLowerCase()}`,
  };
}
async function createInvite(db = admin, data = invite(), { codeOverride = {}, phoneOverride = {}, omit = '' } = {}) {
  const refs = paths(data);
  const values = indexes(data);
  const batch = writeBatch(db);
  if (omit !== 'invite') batch.set(doc(db, refs.invite), data);
  if (omit !== 'code') batch.set(doc(db, refs.code), {...values.code, ...codeOverride});
  if (omit !== 'phone') batch.set(doc(db, refs.phone), {...values.phone, ...phoneOverride});
  return batch.commit();
}

test('Login: authenticated users can get their own admin record, including a missing record', async () => {
  await assertSucceeds(getDoc(doc(admin, 'admin/admin-ok')));
  await assertSucceeds(getDoc(doc(inactive, 'admin/inactive')));
  await assertSucceeds(getDoc(doc(member, 'admin/member')));
});
test('Admin records: outsiders cannot read, list or grant privileges', async () => {
  await assertFails(getDoc(doc(visitor, 'admin/admin-ok')));
  await assertFails(getDoc(doc(member, 'admin/admin-ok')));
  await assertFails(getDocs(collection(admin, 'admin')));
  await assertFails(setDoc(doc(member, 'admin/member'), {email:'member@example.test', eAdministrador:true, ativo:true}));
  await assertFails(updateDoc(doc(admin, 'admin/admin-ok'), {ativo:false}));
  await assertFails(deleteDoc(doc(admin, 'admin/admin-ok')));
});
test('Actual application transaction: two index reads followed by three writes succeeds', async () => {
  const data = invite(); const refs = paths(data); const values = indexes(data);
  await assertSucceeds(runTransaction(admin, async tx => {
    await tx.get(doc(admin, refs.phone));
    await tx.get(doc(admin, refs.code));
    tx.set(doc(admin, refs.invite), data);
    tx.set(doc(admin, refs.phone), values.phone);
    tx.set(doc(admin, refs.code), values.code);
  }));
  await assertSucceeds(getDocs(query(collection(admin, 'access_invites'), orderBy('createdAt', 'desc'))));
});
for (const role of ['VP', 'Speed', 'Base', 'Web']) {
  test(`Colaborador ${role}: consistent invitation accepted`, async () => {
    await assertSucceeds(createInvite(admin, invite({profile:'Colaborador', collaboratorFunction:role, inviteCode:'CABCDEFG'})));
  });
}
test('Promotor: consistent invitation accepted', async () => {
  await assertSucceeds(createInvite(admin, invite({profile:'Promotor', inviteCode:'PABCDEFG'})));
});
for (const [name, getDb] of [
  ['anonymous', () => visitor], ['member', () => member], ['inactive', () => inactive],
  ['email mismatch', () => mismatch], ['non-admin', () => nonAdmin], ['no email', () => noEmail],
]) {
  test(`Invites: ${name} cannot read or write administrative data`, async () => {
    const db = getDb();
    await assertFails(getDocs(collection(db, 'access_invites')));
    await assertFails(getDoc(doc(db, 'access_invite_code_index/UABCDEFG')));
    await assertFails(createInvite(db));
  });
}
for (const [name, overrides] of [
  ['wrong profile', {profile:'Superadmin'}], ['invalid collaborator role', {profile:'Colaborador', collaboratorFunction:'Owner', inviteCode:'CABCDEFG'}],
  ['role on client', {collaboratorFunction:'VP'}], ['wrong code prefix', {inviteCode:'PABCDEFG'}],
  ['invalid code', {inviteCode:'U0000000'}], ['inconsistent phone', {whatsapp:'5511888888888'}],
  ['spoofed author', {createdByUid:'member'}], ['spoofed email', {createdByEmail:'member@example.test'}],
  ['forged timestamp', {createdAt:Timestamp.fromMillis(1000)}], ['already used', {isUsed:true}],
  ['used uid', {usedByUid:'member'}], ['unknown field', {admin:true}], ['disabled on creation', {registrationEnabled:false}],
]) {
  test(`Invite validation denies ${name}`, async () => { await assertFails(createInvite(admin, invite(overrides))); });
}
for (const omit of ['invite', 'phone', 'code']) {
  test(`Atomicity: missing ${omit} is denied`, async () => { await assertFails(createInvite(admin, invite(), {omit})); });
}
test('Indexes cannot diverge from the invitation or add hidden fields', async () => {
  await assertFails(createInvite(admin, invite(), {codeOverride:{inviteId:'BBBBBBBBBBBBBBBBBBBB'}}));
  await assertFails(createInvite(admin, invite(), {phoneOverride:{whatsapp:'5511888888888'}}));
  await assertFails(createInvite(admin, invite(), {codeOverride:{extra:'forbidden'}}));
});
test('Uniqueness: duplicate code and duplicate WhatsApp/profile are denied', async () => {
  await createInvite();
  await assertFails(createInvite(admin, invite({inviteId:'BBBBBBBBBBBBBBBBBBBB', phoneNumber:'999997777', whatsapp:'5511999997777'})));
  await assertFails(createInvite(admin, invite({inviteId:'BBBBBBBBBBBBBBBBBBBB', inviteCode:'UABCDEFH'})));
});
test('Same phone may have different profiles, matching application behavior', async () => {
  await createInvite();
  await assertSucceeds(createInvite(admin, invite({inviteId:'BBBBBBBBBBBBBBBBBBBB', profile:'Promotor', inviteCode:'PABCDEFG'})));
});
test('Existing invites/indexes cannot be changed, deleted, or enumerated via indexes', async () => {
  const refs = paths(invite()); await createInvite();
  for (const path of Object.values(refs)) {
    await assertFails(updateDoc(doc(admin, path), {createdByUid:'member'}));
    await assertFails(deleteDoc(doc(admin, path)));
  }
  await assertFails(getDocs(collection(admin, 'access_invite_code_index')));
  await assertFails(getDocs(collection(admin, 'access_invite_whatsapp_profile_index')));
});
test('A removed index cannot be recreated for an existing invite from a client', async () => {
  const refs = paths(invite()); await createInvite();
  await env.withSecurityRulesDisabled(context => deleteDoc(doc(context.firestore(), refs.code)));
  await assertFails(setDoc(doc(admin, refs.code), indexes(invite()).code));
});

function publication(kind, extra = {}) {
  return {title:'Royal Clean exemplo', category:'Novidades', imageUrl:'https://example.test/image.webp',
    published:false, createdAt:serverTimestamp(), updatedAt:serverTimestamp(),
    ...(kind === 'products' ? {description:'Produto demonstrativo'} : {summary:'Resumo editorial', body:'Conteúdo completo'}), ...extra};
}
for (const kind of ['products', 'news']) {
  test(`${kind}: admin CRUD, public published read, private drafts and filtered queries`, async () => {
    await assertSucceeds(setDoc(doc(admin, `${kind}/draft`), publication(kind)));
    await assertSucceeds(setDoc(doc(admin, `${kind}/public`), publication(kind, {published:true})));
    await assertFails(getDoc(doc(visitor, `${kind}/draft`)));
    await assertFails(getDoc(doc(member, `${kind}/draft`)));
    await assertSucceeds(getDoc(doc(visitor, `${kind}/public`)));
    await assertSucceeds(getDocs(query(collection(visitor, kind), where('published','==',true))));
    await assertFails(getDocs(collection(visitor, kind)));
    await assertSucceeds(getDocs(collection(admin, kind)));
    await assertFails(setDoc(doc(member, `${kind}/unauthorized`), publication(kind)));
    await assertFails(setDoc(doc(inactive, `${kind}/unauthorized`), publication(kind)));
    await assertFails(setDoc(doc(visitor, `${kind}/unauthorized`), publication(kind)));
    await assertFails(updateDoc(doc(admin, `${kind}/draft`), {createdAt:Timestamp.fromMillis(1), updatedAt:serverTimestamp()}));
    await assertSucceeds(updateDoc(doc(admin, `${kind}/draft`), {published:true, updatedAt:serverTimestamp()}));
    await assertSucceeds(getDoc(doc(visitor, `${kind}/draft`)));
    await assertSucceeds(updateDoc(doc(admin, `${kind}/draft`), {published:false, updatedAt:serverTimestamp()}));
    await assertFails(getDoc(doc(visitor, `${kind}/draft`)));
    await assertFails(deleteDoc(doc(member, `${kind}/draft`)));
    await assertSucceeds(deleteDoc(doc(admin, `${kind}/draft`)));
  });
  test(`${kind}: extra fields, invalid types, image URLs and timestamps rejected`, async () => {
    for (const extra of [{cost:100}, {published:'true'}, {imageUrl:'javascript:alert(1)'},
      {createdAt:Timestamp.fromMillis(1)}, {updatedAt:Timestamp.fromMillis(1)}, {title:''}]) {
      await assertFails(setDoc(doc(admin, `${kind}/invalid`), publication(kind, extra)));
    }
  });
}
test('Unknown collections and nested documents remain denied even to admins', async () => {
  for (const path of ['billing/secret','users/member','admin/admin-ok/private/secret','products/example/internal/secret']) {
    await assertFails(setDoc(doc(admin, path), {value:1}));
    await assertFails(getDoc(doc(admin, path)));
  }
});
test('Removing the active admin flag immediately denies subsequent protected server reads', async () => {
  await assertSucceeds(getDocs(collection(admin, 'access_invites')));
  await env.withSecurityRulesDisabled(context => updateDoc(doc(context.firestore(), 'admin/admin-ok'), {ativo:false}));
  await assertFails(getDocs(collection(admin, 'access_invites')));
});
