import {test, before, after} from 'node:test';
import assert from 'node:assert/strict';

if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8185' || process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9199') {
  throw new Error('Backend integration tests require both LOCAL emulators; refusing production access.');
}
process.env.GCLOUD_PROJECT = 'demo-royal-clean';
const {registerAccount, updateMyData, setUserRole} = await import('../index.js');
const {getFirestore, Timestamp} = await import('firebase-admin/firestore');
const {getAuth} = await import('firebase-admin/auth');
const {getApp, deleteApp} = await import('firebase-admin/app');
const db = getFirestore();
const auth = getAuth();
const data = (extra={}) => ({name:'João da Silva', acceptTerms:true, legalVersion:'2026-09-22', offers:false, inviteCode:'', ...extra});
const request = (uid, input = {}) => ({auth:{uid}, data:input});

before(async () => {
  for (const uid of ['new-one','new-two','new-three','unverified','role-admin','intruder','expired','admin-disabled']) {
    await auth.createUser({uid, email:`${uid}@example.test`, emailVerified:uid !== 'unverified'});
  }
  await db.doc('admin/role-admin').set({email:'role-admin@example.test', ativo:true, eAdministrador:true});
  await db.doc('admin/admin-disabled').set({email:'admin-disabled@example.test', ativo:false, eAdministrador:true});
});
after(async () => { await deleteApp(getApp()); });

test('backend: unauthenticated and unverified registration rejected', async () => {
  await assert.rejects(registerAccount.run({data:data()}), {code:'unauthenticated'});
  await assert.rejects(registerAccount.run(request('unverified',data())), {code:'failed-precondition'});
  assert.equal((await db.doc('users/unverified').get()).exists,false);
});
test('backend: common registration stores immutable consent and ignores injected role/email', async () => {
  await registerAccount.run(request('new-one',data({role:'admin', email:'forged@example.test'})));
  const profile = (await db.doc('users/new-one').get()).data();
  assert.equal(profile.role,'consumer');
  assert.equal(profile.email,'new-one@example.test');
  assert.equal(profile.offers,false);
  assert.equal(profile.referral,null);
  assert.ok(profile.termsAcceptedAt instanceof Timestamp);
  await assert.rejects(registerAccount.run(request('new-one',data({inviteCode:'MABCDEFH'}))), {code:'failed-precondition'});
});
test('backend: Mestre invitation matches verified email and phone, is atomic and retry-safe', async () => {
  const id = 'BBBBBBBBBBBBBBBBBBBB';
  const ref = db.doc(`access_invites/${id}`);
  await ref.set({inviteId:id,inviteCode:'MABCDEFG',isUsed:false,registrationEnabled:true,
    status:'processing',profile:'Mestre',email:'NEW-TWO@example.test',whatsapp:'5511999998888',
    expiresAt:Timestamp.fromMillis(Date.now()+86400000),createdByUid:'role-admin'});
  await db.doc('access_invite_code_index/MABCDEFG').set({inviteId:id});
  const input = data({inviteCode:'MABCDEFG',phone:'(11) 99999-8888'});
  await assert.rejects(registerAccount.run(request('new-three',{...input,email:'new-two@example.test'})),{code:'invalid-argument'});
  await assert.rejects(registerAccount.run(request('new-two',{...input,phone:'11988887777'})),{code:'invalid-argument'});
  await assert.rejects(registerAccount.run(request('new-two',{...input,phone:''})),{code:'invalid-argument'});
  assert.equal((await ref.get()).data().isUsed,false);
  assert.equal((await db.doc('users/new-two').get()).exists,false);
  await Promise.all([1,2].map(()=>registerAccount.run(request('new-two',input))));
  const profile = (await db.doc('users/new-two').get()).data();
  assert.equal(profile.role,'master');
  assert.equal(profile.referral.profileReference,'Mestre');
  assert.equal((await ref.get()).data().usedByUid,'new-two');
  assert.equal((await ref.get()).data().registrationEnabled,false);
  assert.equal((await db.doc('personal_data/new-two').get()).data().phone,'5511999998888');
  await assert.rejects(registerAccount.run(request('new-three',input)),{code:'invalid-argument'});
  await registerAccount.run(request('new-three',data()));
  assert.equal((await db.doc('users/new-three').get()).data().role,'consumer');
});
test('backend: invalid/expired invitation does not create a profile and can be removed', async () => {
  await assert.rejects(registerAccount.run(request('expired',data({inviteCode:'UZZZZZZZ'}))),{code:'invalid-argument'});
  const id = 'CCCCCCCCCCCCCCCCCCCC';
  await db.doc(`access_invites/${id}`).set({inviteCode:'MABCDEFH',isUsed:false,registrationEnabled:true,
    status:'processing',expiresAt:Timestamp.fromMillis(1)});
  await db.doc('access_invite_code_index/MABCDEFH').set({inviteId:id});
  await assert.rejects(registerAccount.run(request('expired',data({inviteCode:'MABCDEFH'}))),{code:'invalid-argument'});
  assert.equal((await db.doc('users/expired').get()).exists,false);
  assert.equal((await db.doc(`access_invites/${id}`).get()).data().isUsed,false);
  await registerAccount.run(request('expired',data()));
});
test('backend: only active admin assigns limited roles; changes are audited', async () => {
  const change = {uid:'new-one',role:'collaborator',active:true};
  await assert.rejects(setUserRole.run(request('intruder',change)),{code:'permission-denied'});
  await assert.rejects(setUserRole.run(request('admin-disabled',change)),{code:'permission-denied'});
  await assert.rejects(setUserRole.run(request('role-admin',{...change,role:'admin'})),{code:'invalid-argument'});
  await assert.rejects(setUserRole.run(request('role-admin',{...change,role:'master'})),{code:'failed-precondition'});
  await setUserRole.run(request('role-admin',change));
  assert.equal((await db.doc('users/new-one').get()).data().role,'collaborator');
  const audits = await db.collection('account_audit').where('targetUid','==','new-one').get();
  assert.equal(audits.size,1);
});
test('backend: personal document validation, owner targeting and revocation', async () => {
  const input = {name:'João Atualizado',offers:true,documentKind:'cpf',document:'529.982.247-25',uid:'new-two',role:'admin'};
  await updateMyData.run(request('new-one',input));
  assert.equal((await db.doc('personal_data/new-one').get()).data().document,'52998224725');
  assert.equal((await db.doc('personal_data/new-two').get()).data().document,'');
  assert.equal((await db.doc('users/new-one').get()).data().role,'collaborator');
  await assert.rejects(updateMyData.run(request('new-one',{...input,document:'11111111111'})),{code:'invalid-argument'});
  await updateMyData.run(request('new-one',{...input,documentKind:'',document:''}));
  assert.equal((await db.doc('personal_data/new-one').get()).data().document,'');
  await setUserRole.run(request('role-admin',{uid:'new-one',role:'promoter',active:false}));
  await assert.rejects(updateMyData.run(request('new-one',input)),{code:'permission-denied'});
  await db.doc('users/admin-disabled').set({active:true, role:'consumer'});
  await assert.rejects(updateMyData.run(request('admin-disabled',input)),{code:'permission-denied'});
});
test('backend: missing consent, obsolete terms and brute force are rejected', async () => {
  await assert.rejects(registerAccount.run(request('intruder',data({acceptTerms:false}))),{code:'invalid-argument'});
  await assert.rejects(registerAccount.run(request('intruder',data({legalVersion:'old'}))),{code:'invalid-argument'});
  for (let i=0;i<8;i++) await assert.rejects(registerAccount.run(request('intruder',data({inviteCode:'wrong'}))),{code:'invalid-argument'});
  await assert.rejects(registerAccount.run(request('intruder',data())),{code:'resource-exhausted'});
});
