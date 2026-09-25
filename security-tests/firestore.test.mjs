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

const intercomMessage = () => ({title: 'Aviso Royal Clean', body: 'Mensagem pública de teste.',
  kind: 'Mensagem', publishedAt: serverTimestamp(), expiresAt: Timestamp.fromMillis(Date.now() + 86400000)});

test('Interfone: only active admin publishes, and public messages are readable by guests', async () => {
  for (const db of [visitor, member, inactive, mismatch, nonAdmin, noEmail]) {
    await assertFails(setDoc(doc(db, 'intercom_messages/blocked'), intercomMessage()));
  }
  await assertSucceeds(setDoc(doc(admin, 'intercom_messages/notice'), intercomMessage()));
  await assertSucceeds(getDoc(doc(visitor, 'intercom_messages/notice')));
  await assertSucceeds(getDocs(query(collection(visitor, 'intercom_messages'), orderBy('publishedAt', 'desc'))));
  await assertFails(updateDoc(doc(admin, 'intercom_messages/notice'), {title: 'Alterado'}));
  await assertFails(deleteDoc(doc(member, 'intercom_messages/notice')));
});

test('Interfone: validates length, public schema, type, timestamps and expiration', async () => {
  for (const changes of [{title: 'a'}, {body: ''}, {body: 'x'.repeat(2001)}, {kind: 'invalid'},
    {privateEmail: 'private@example.test'}, {publishedAt: Timestamp.fromMillis(0)},
    {expiresAt: Timestamp.fromMillis(0)}, {expiresAt: Timestamp.fromMillis(Date.now() + 86400000 * 40)}]) {
    await assertFails(setDoc(doc(admin, 'intercom_messages/invalid'), {...intercomMessage(), ...changes}));
  }
});

test('Interfone: reviews remain disabled until the user evaluation workflow is defined', async () => {
  await assertSucceeds(setDoc(doc(admin, 'intercom_messages/notice'), intercomMessage()));
  const review = {reviewedAt: serverTimestamp(), reviewedBy: 'admin-ok'};
  await assertFails(setDoc(doc(admin, 'intercom_reviews/missing'), review));
  await assertFails(setDoc(doc(admin, 'intercom_reviews/notice'), {...review, reviewedBy: 'other'}));
  await assertFails(setDoc(doc(admin, 'intercom_reviews/notice'), review));
  await assertFails(getDocs(collection(admin, 'intercom_reviews')));
  for (const db of [visitor, member, inactive, admin]) {
    await assertFails(getDoc(doc(db, 'intercom_reviews/notice')));
    await assertFails(setDoc(doc(db, 'intercom_reviews/notice'), review));
  }
});
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

test('Accounts: verified owner and active admin can read profiles; strangers and unverified accounts cannot', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/member'), {role:'consumer',active:true,email:'member@example.test'});
  });
  const verified = env.authenticatedContext('member', {email:'member@example.test',email_verified:true}).firestore();
  await assertSucceeds(getDoc(doc(verified,'users/member')));
  await assertSucceeds(getDoc(doc(admin,'users/member')));
  await assertSucceeds(getDocs(collection(admin,'users')));
  await assertFails(getDoc(doc(visitor,'users/member')));
  await assertFails(getDoc(doc(member,'users/member')));
  await assertFails(getDoc(doc(verified,'users/another')));
  await assertFails(getDocs(collection(verified,'users')));
  await assertFails(getDocs(collection(inactive,'users')));
});
test('Accounts: all client profile writes, role escalation and late invites are denied, including admin writes', async () => {
  const verified = env.authenticatedContext('member', {email:'member@example.test',email_verified:true}).firestore();
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/member'), {role:'consumer',active:true});
  });
  for (const db of [verified,admin]) {
    await assertFails(setDoc(doc(db,'users/new-user'), {role:'admin',active:true}));
    await assertFails(updateDoc(doc(db,'users/member'), {role:'collaborator'}));
    await assertFails(updateDoc(doc(db,'users/member'), {referral:{code:'UABCDEFG'}}));
    await assertFails(deleteDoc(doc(db,'users/member')));
  }
});
test('Accounts: personal documents are owner-only and writes are backend-only', async () => {
  const verified = env.authenticatedContext('member', {email:'member@example.test',email_verified:true}).firestore();
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'users/member'), {role:'consumer',active:true});
    await setDoc(doc(context.firestore(), 'personal_data/member'), {document:'52998224725'});
  });
  await assertSucceeds(getDoc(doc(verified,'personal_data/member')));
  for (const db of [visitor,member,admin]) await assertFails(getDoc(doc(db,'personal_data/member')));
  await assertFails(getDocs(collection(verified,'personal_data')));
  await assertFails(setDoc(doc(verified,'personal_data/member'), {document:'other'}));
  await env.withSecurityRulesDisabled(async context => {
    await updateDoc(doc(context.firestore(),'users/member'), {active:false});
  });
  await assertFails(getDoc(doc(verified,'personal_data/member')));
  await assertSucceeds(getDoc(doc(verified,'users/member')));
});
test('Inactive administrator cannot use a leftover consumer profile to read personal data', async () => {
  const account = env.authenticatedContext('inactive',{email:'inactive@example.test',email_verified:true}).firestore();
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(),'users/inactive'), {active:true,role:'consumer'});
    await setDoc(doc(context.firestore(),'personal_data/inactive'), {document:'52998224725'});
  });
  await assertFails(getDoc(doc(account,'personal_data/inactive')));
});
test('Accounts: audit and rate limits are not exposed to clients', async () => {
  for (const name of ['account_audit','account_rate_limits']) {
    await assertFails(getDocs(collection(admin,name)));
    await assertFails(setDoc(doc(member,`${name}/fake`),{count:0}));
  }
});

test('Bling credentials and OAuth sessions are denied to every client, including admins', async () => {
  for (const collectionName of ['integrations_private', 'bling_oauth_sessions']) {
    await env.withSecurityRulesDisabled(async context => {
      await setDoc(doc(context.firestore(), `${collectionName}/test`), {secret: 'test-only'});
    });
    for (const db of [visitor, member, admin]) {
      await assertFails(getDoc(doc(db, `${collectionName}/test`)));
      await assertFails(getDocs(collection(db, collectionName)));
      await assertFails(setDoc(doc(db, `${collectionName}/test`), {secret: 'replacement'}));
    }
  }
});
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
    inviteId: 'AAAAAAAAAAAAAAAAAAAA', inviteCode: 'MABCDEFG', fullName: 'Pessoa Teste', email: 'pessoa@example.test',
    expiresAt: Timestamp.fromMillis(Date.now() + 30 * 86400000),
    profile: 'Mestre', collaboratorFunction: null, ddd: '11', phoneNumber: '999998888',
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

test('New invites may expire within 31 days; past and excessive expiration are rejected', async () => {
  await assertSucceeds(createInvite(admin, invite({expiresAt: Timestamp.fromMillis(Date.now() + 30 * 86400000)})));
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(context => setDoc(doc(context.firestore(), 'admin/admin-ok'),
    {email:'admin@example.test', eAdministrador:true, ativo:true}));
  await assertFails(createInvite(admin, invite({expiresAt: Timestamp.fromMillis(1)})));
  await assertFails(createInvite(admin, invite({expiresAt: Timestamp.fromMillis(Date.now() + 90 * 86400000)})));
});
for (const role of ['VP', 'Speed', 'Base', 'Web']) {
  test(`Colaborador ${role}: legacy invitation creation rejected`, async () => {
    await assertFails(createInvite(admin, invite({profile:'Colaborador', collaboratorFunction:role, inviteCode:'CABCDEFG'})));
  });
}
test('Promotor: legacy invitation creation rejected', async () => {
  await assertFails(createInvite(admin, invite({profile:'Promotor', inviteCode:'PABCDEFG'})));
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
  ['missing recipient email', {email:''}], ['invalid recipient email', {email:'bad'}],
  ['missing expiration', {expiresAt:null}],
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
  await assertFails(createInvite(admin, invite({inviteId:'BBBBBBBBBBBBBBBBBBBB', inviteCode:'MABCDEFH'})));
});
test('New invitations cannot target legacy profiles', async () => {
  await createInvite();
  await assertFails(createInvite(admin, invite({inviteId:'BBBBBBBBBBBBBBBBBBBB', profile:'Promotor', inviteCode:'PABCDEFG'})));
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
for (const kind of ['public_partners', 'partner_ads']) {
  test(`${kind}: only approved public projections; private data and unauthorized writes denied`, async () => {
    const payload = {title:'Parceiro autorizado', description:'Apresentação pública',
      imageUrl:'https://example.test/logo.png', published:true,
      createdAt:serverTimestamp(), updatedAt:serverTimestamp()};
    await assertSucceeds(setDoc(doc(admin, `${kind}/1`), payload));
    await assertSucceeds(getDocs(query(collection(visitor, kind), where('published','==',true))));
    await assertFails(getDocs(collection(visitor, kind)));
    for (const db of [visitor, member, inactive]) {
      await assertFails(setDoc(doc(db, `${kind}/2`), payload));
    }
    for (const extra of [{email:'private@example.test'}, {phone:'123'}, {role:'admin'},
      {imageUrl:'http://example.test/logo.png'}, {description:''}]) {
      await assertFails(setDoc(doc(admin, `${kind}/2`), {...payload,...extra}));
    }
    await assertSucceeds(updateDoc(doc(admin, `${kind}/1`), {published:false,updatedAt:serverTimestamp()}));
    await assertFails(getDoc(doc(visitor, `${kind}/1`)));
    await assertSucceeds(deleteDoc(doc(admin, `${kind}/1`)));
    if (kind === 'partner_ads') {
      await assertFails(setDoc(doc(admin, `${kind}/5`), payload));
    }
  });
}

test('Unknown collections and nested documents remain denied even to admins', async () => {
  for (const path of ['billing/secret','users/member/private/secret','admin/admin-ok/private/secret','products/example/internal/secret']) {
    await assertFails(setDoc(doc(admin, path), {value:1}));
    await assertFails(getDoc(doc(admin, path)));
  }
});
test('Removing the active admin flag immediately denies subsequent protected server reads', async () => {
  await assertSucceeds(getDocs(collection(admin, 'access_invites')));
  await env.withSecurityRulesDisabled(context => updateDoc(doc(context.firestore(), 'admin/admin-ok'), {ativo:false}));
  await assertFails(getDocs(collection(admin, 'access_invites')));
});
