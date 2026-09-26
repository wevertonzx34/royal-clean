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
const {createBlingHandlers} = await import('../bling.js');
const {createBlingDataHandler} = await import('../bling-data.js');
const db = getFirestore();
const auth = getAuth();
const data = (extra={}) => ({name:'João da Silva', acceptTerms:true, legalVersion:'2026-09-22', offers:false, inviteCode:'', ...extra});
const request = (uid, input = {}) => ({auth:{uid}, data:input});

test('Bling OAuth: admin gate, browser binding, single use and private token storage', async () => {
  await db.doc('integrations_private/bling').delete();
  await db.doc('integrations_private/bling_attempt').delete();
  let exchanges = 0;
  const handlers = createBlingHandlers({db, auth,
    authenticated: async req => { if (!req.auth) throw new Error('No auth'); return auth.getUser(req.auth.uid); },
    requireAdmin: async user => { if (user.uid !== 'role-admin') throw new Error('Not admin'); },
    rateLimit: async () => {}, readCredentials: async () => ({clientId: 'demo-id', clientSecret: 'demo-secret'}),
    exchangeCode: async () => { exchanges++; return {accessToken: 'test-access', refreshToken: 'test-refresh', expiresIn: 3600, scope: ''}; },
  });
  const response = () => ({headers: {}, statusCode: 200, body: '',
    set(name, value) { this.headers[name] = value; return this; },
    status(code) { this.statusCode = code; return this; }, type() { return this; },
    send(body) { this.body = body; return this; }, redirect(code, location) { this.statusCode = code; this.location = location; return this; }});
  await assert.rejects(handlers.begin({}), /No auth/);
  await assert.rejects(handlers.begin(request('intruder')), /Not admin/);
  const started = await handlers.begin(request('role-admin'));
  const state = new URL(started.url).searchParams.get('start');
  await assert.rejects(handlers.begin(request('role-admin')), /andamento/);
  const browser = response();
  await handlers.callback({method: 'GET', query: {start: state}, get: () => ''}, browser);
  assert.equal(browser.statusCode, 303);
  assert.equal(new URL(browser.location).host, 'www.bling.com.br');
  const cookie = browser.headers['Set-Cookie'].split(';')[0];
  const attack = response();
  await handlers.callback({method: 'GET', query: {state, code: 'example'}, get: () => ''}, attack);
  assert.equal(attack.statusCode, 400);
  assert.equal(exchanges, 0);
  const done = response();
  await handlers.callback({method: 'GET', query: {state, code: 'example'}, get: () => cookie}, done);
  assert.equal(done.statusCode, 303);
  assert.equal(exchanges, 1);
  assert.equal((await db.doc('integrations_private/bling').get()).data().refreshToken, 'test-refresh');
  const status = await handlers.status(request('role-admin'));
  assert.equal(status.status, 'authorized');
  assert.equal(JSON.stringify(status).includes('test-refresh'), false);
  const replay = response();
  await handlers.callback({method: 'GET', query: {state, code: 'example'}, get: () => cookie}, replay);
  assert.equal(replay.statusCode, 400);
  assert.equal(exchanges, 1);
  await assert.rejects(handlers.begin(request('role-admin')), /já foi autorizada/);
  const renewed = await handlers.begin(request('role-admin', {reconnect:true}));
  const nextState = new URL(renewed.url).searchParams.get('start');
  const nextBrowser = response();
  await handlers.callback({method:'GET',query:{start:nextState},get:()=>''},nextBrowser);
  const nextCookie = nextBrowser.headers['Set-Cookie'].split(';')[0];
  const nextDone = response();
  await handlers.callback({method:'GET',query:{state:nextState,code:'renewed'},get:()=>nextCookie},nextDone);
  assert.equal(nextDone.statusCode,303);
  assert.equal(exchanges,2);
});

test('Bling OAuth: expired sessions and revoked administrators never exchange codes', async () => {
  const {createHash} = await import('node:crypto');
  const state = 'a'.repeat(64);
  const hash = createHash('sha256').update(state).digest('hex');
  const ref = db.doc(`bling_oauth_sessions/${hash}`);
  let exchanges = 0;
  const handlers = createBlingHandlers({db, auth, authenticated: async () => {}, requireAdmin: async () => {throw new Error('Revoked');},
    rateLimit: async () => {}, readCredentials: async () => ({}), exchangeCode: async () => {exchanges++;}});
  const res = {set() {return this;}, status(code) {this.code = code; return this;}, type() {return this;}, send() {return this;}};
  await ref.set({uid: 'role-admin', expiresAt: Timestamp.fromMillis(Date.now() - 1000), status: 'started'});
  await handlers.callback({method: 'GET', query: {state, code: 'code'}, get: () => ''}, res);
  assert.equal(res.code, 400);
  await ref.update({expiresAt: Timestamp.fromMillis(Date.now() + 60000)});
  await handlers.callback({method: 'GET', query: {state, code: 'code'}, get: () => ''}, res);
  assert.equal(res.code, 400);
  assert.equal(exchanges, 0);
});

before(async () => {
  for (const uid of ['new-one','new-two','new-three','unverified','role-admin','intruder','expired','admin-disabled']) {
    await auth.createUser({uid, email:`${uid}@example.test`, emailVerified:uid !== 'unverified'});
  }
  await db.doc('admin/role-admin').set({email:'role-admin@example.test', ativo:true, eAdministrador:true});
  await db.doc('admin/admin-disabled').set({email:'admin-disabled@example.test', ativo:false, eAdministrador:true});
});
after(async () => { await deleteApp(getApp()); });

test('Bling data: admin-only private sync, scope denial and coordinated renewal', async () => {
  const connection = db.doc('integrations_private/bling');
  await connection.set({accessToken:'old-access-token',refreshToken:'old-refresh-token',expiresAt:Timestamp.fromMillis(1)});
  let refreshes = 0;
  let blocked = false;
  const handler = createBlingDataHandler({db,
    authenticated: async r => { if (!r.auth) throw new Error('No auth'); return {uid:r.auth.uid}; },
    requireAdmin: async user => { if (user.uid !== 'role-admin') throw new Error('Not admin'); },
    rateLimit: async () => {}, readCredentials: async () => ({clientId:'test',clientSecret:'test'}),
    fetchImpl: async (url, options) => {
      if (url.endsWith('/oauth/token')) {
        refreshes++;
        assert.equal(options.body.get('grant_type'),'refresh_token');
        return {ok:true,json:async()=>({access_token:'new-access-token',refresh_token:'new-refresh-token',expires_in:3600,token_type:'Bearer'})};
      }
      assert.equal(options.headers.Authorization,'Bearer new-access-token');
      if (blocked) return {ok:false,status:403};
      return {ok:true,status:200,json:async()=>({data:[{id:123,nome:'Produto real de teste',preco:10,custo:9}]})};
    }});
  await assert.rejects(handler(request('intruder')), /Not admin/);
  const results = await Promise.allSettled([handler(request('role-admin')),handler(request('role-admin'))]);
  assert.ok(results.some(r=>r.status==='fulfilled'));
  assert.equal(refreshes,1);
  assert.equal((await connection.get()).data().refreshToken,'new-refresh-token');
  const product = (await db.doc('bling_private_products/123').get()).data();
  assert.equal(product.price,10);
  assert.equal(product.custo,undefined);
  blocked = true;
  await assert.rejects(handler(request('role-admin',{kind:'sales',start:'2026-09-01',end:'2026-09-25'})), {code:'permission-denied'});
});

test('backend: unauthenticated and unverified registration rejected', async () => {
  await assert.rejects(registerAccount.run({data:data()}), {code:'unauthenticated'});
  await assert.rejects(registerAccount.run(request('unverified',data())), {code:'failed-precondition'});
  assert.equal((await db.doc('users/unverified').get()).exists,false);
});

test('Outgoing invoice sync overwrites status by id and keeps copies private', async () => {
  await db.doc('integrations_private/bling').set({accessToken:'valid-test-token',expiresAt:Timestamp.fromMillis(Date.now()+3600000)});
  let status=5;
  const handler=createBlingDataHandler({db, authenticated:async r=>{if(!r.auth) throw new Error('No auth');return {uid:r.auth.uid};},
    requireAdmin:async u=>{if(u.uid!=='role-admin') throw new Error('Not admin');},rateLimit:async()=>{},
    fetchImpl:async url=>{
      assert.equal(new URL(url).searchParams.get('tipo'),'1');
      return {ok:true,status:200,json:async()=>({data:[{id:987,tipo:1,numero:'10',situacao:status,contato:{nome:'Private'}}]})};
    }});
  const query={kind:'invoices',start:'2026-09-01',end:'2026-09-25',invoiceStatus:5};
  await assert.rejects(handler(request('intruder',query)),/Not admin/);
  await handler(request('role-admin',query));
  status=2;
  const result=await handler(request('role-admin',{...query,invoiceStatus:2}));
  assert.equal(result.items[0].statusLabel,'Cancelada');
  const mirror=(await db.doc('bling_private_invoices/987').get()).data();
  assert.equal(mirror.status,'2');
  assert.equal(mirror.contato,undefined);
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

test('Invoice detail enforces admin and returns only items from the requested outgoing note', async () => {
  await db.doc('integrations_private/bling').set({accessToken:'valid-test-token',expiresAt:Timestamp.fromMillis(Date.now()+3600000)});
  let calls=0;
  const handler=createBlingDataHandler({db, authenticated:async r=>{if(!r.auth) throw new Error('No auth');return {uid:r.auth.uid};},
    requireAdmin:async u=>{if(u.uid!=='role-admin') throw new Error('Not admin');},rateLimit:async()=>{},
    fetchImpl:async url=>{calls++;assert.equal(new URL(url).pathname,'/Api/v3/nfe/123');
      return {ok:true,status:200,json:async()=>({data:{id:123,tipo:1,numero:'10',situacao:5,itens:[{descricao:'Item da NF',quantidade:2,valor:5,valorTotal:10}],contato:{nome:'private'}}})};}});
  const input={kind:'invoiceItems',invoiceId:'123'};
  await assert.rejects(handler(request('intruder',input)),/Not admin/);
  assert.equal(calls,0);
  const result=await handler(request('role-admin',input));
  assert.equal(result.items[0].quantity,2);
  assert.equal(JSON.stringify(result).includes('private'),false);
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
