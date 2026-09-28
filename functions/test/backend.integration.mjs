import {test, before, after} from 'node:test';
import assert from 'node:assert/strict';

if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8185' || process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9199') {
  throw new Error('Backend integration tests require both LOCAL emulators; refusing production access.');
}
process.env.GCLOUD_PROJECT = 'demo-royal-clean';
const {registerAccount, updateMyData, setUserRole, registerAdminNotifications} = await import('../index.js');
const {getFirestore, Timestamp} = await import('firebase-admin/firestore');
const {getAuth} = await import('firebase-admin/auth');
const {getApp, deleteApp} = await import('firebase-admin/app');
const {createBlingHandlers} = await import('../bling.js');
const {createBlingDataHandler} = await import('../bling-data.js');
const db = getFirestore();
const auth = getAuth();
const data = (extra={}) => ({name:'João da Silva', acceptTerms:true, legalVersion:'2026-09-22', offers:false, inviteCode:'', ...extra});
const request = (uid, input = {}) => ({auth:{uid}, data:input});

test('Admin push registration rejects guests, consumers and unverified accounts',async()=>{
 const input={token:'test-token-that-is-long-enough-for-validation'};
 await assert.rejects(registerAdminNotifications.run({data:input}),{code:'unauthenticated'});
 await assert.rejects(registerAdminNotifications.run(request('unverified',input)),{code:'failed-precondition'});
 await assert.rejects(registerAdminNotifications.run(request('intruder',input)),{code:'permission-denied'});
 await registerAdminNotifications.run(request('role-admin',input));
 const devices=await db.collection('admin_notification_devices').get();
 assert.equal(devices.size,1);assert.equal(devices.docs[0].data().uid,'role-admin');
 await registerAdminNotifications.run(request('intruder',{...input,remove:true}));
 assert.equal((await devices.docs[0].ref.get()).exists,true);
 await registerAdminNotifications.run(request('role-admin',{...input,remove:true}));
 assert.equal((await devices.docs[0].ref.get()).exists,false);
});

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

test('Dashboard enrichment fetches original note value with current admin checks and caches only safe fields',async()=>{
  await db.doc('integrations_private/bling').set({accessToken:'test-token',expiresAt:Timestamp.fromMillis(Date.now()+3600000)});
  await db.doc('bling_private_invoices/456').set({id:'456',date:'2026-09-26',status:'5'});
  let calls=0;
  const handler=createBlingDataHandler({db,authenticated:async r=>({uid:r.auth.uid}),
    requireAdmin:async u=>{if(u.uid!=='role-admin')throw new Error('Not admin');},rateLimit:async()=>{},
    fetchImpl:async url=>{calls++;const u=new URL(url);if(u.pathname==='/Api/v3/nfe')return {ok:true,status:200,json:async()=>({data:u.searchParams.has('situacao')?[]:[{id:456,tipo:1,situacao:5}]})};assert.equal(u.pathname,'/Api/v3/nfe/456');return {ok:true,status:200,json:async()=>({data:{id:456,tipo:1,valorNota:123.45,dataEmissao:'2026-09-26',situacao:5,contato:{cpf:'private-secret'},xml:'private-secret'}})};}});
  const input={kind:'dashboard',group:'invoices',period:'yearly',refreshDetails:true};
  await assert.rejects(handler(request('intruder',input)),/Not admin/);assert.equal(calls,0);
  const result=await handler(request('role-admin',input));
  assert.equal(result.enrichment.remaining,0);
  const record=(await db.doc('bling_private_invoices/456').get()).data();
  assert.equal(record.total,123.45);assert.equal(JSON.stringify(record).includes('private-secret'),false);
  await handler(request('role-admin',input));assert.equal(calls,3);
  await handler(request('role-admin',{...input,syncLatest:true,refreshSince:new Date().toISOString()}));assert.equal(calls,6);
  await db.doc('integrations_private/bling_invoices_catalog').delete();
  await db.doc('bling_private_invoices/456').delete();
});

test('Dashboard rechecks admin, reads private mirror once per id and never returns personal data', async () => {
  const handler=createBlingDataHandler({db,
    authenticated:async r=>{if(!r.auth) throw new Error('No auth');return {uid:r.auth.uid};},
    requireAdmin:async u=>{if(u.uid!=='role-admin') throw new Error('Not admin');},rateLimit:async()=>{},
    fetchImpl:async()=>{throw new Error('Dashboard must not call provider');}});
  const input={kind:'dashboard',group:'contacts',period:'monthly'};
  await assert.rejects(handler(request('intruder',input)),/Not admin/);
  await db.doc('bling_private_contacts/dashboard-test').set({status:'I',document:'secret-personal',checkedAt:'2026-09-26T12:00:00Z'});
  await db.doc('bling_private_contacts/dashboard-test').set({status:'A',document:'secret-personal',checkedAt:'2026-09-26T13:00:00Z'});
  const result=await handler(request('role-admin',input));
  assert.equal(result.records,1);assert.equal(result.metrics[0].values[0],1);
  assert.equal(result.checkedAt,'2026-09-26T13:00:00Z');
  assert.equal(JSON.stringify(result).includes('secret-personal'),false);
  await db.doc('bling_private_contacts/dashboard-test').delete();
});

test('Contacts require admin, remain private, update by id and explain missing scope', async () => {
  await db.doc('integrations_private/bling').set({accessToken:'test-token',expiresAt:Timestamp.fromMillis(Date.now()+3600000)});
  let name='Contato de teste'; let blocked=false; let calls=0;
  const handler=createBlingDataHandler({db,
    authenticated:async r=>{if(!r.auth) throw new Error('No auth');return {uid:r.auth.uid};},
    requireAdmin:async u=>{if(u.uid!=='role-admin') throw new Error('Not admin');},rateLimit:async()=>{},
    fetchImpl:async url=>{calls++;assert.equal(new URL(url).pathname,'/Api/v3/contatos');
      if(blocked) return {ok:false,status:403};
      return {ok:true,status:200,json:async()=>({data:[{id:246,nome:name,situacao:'A',numeroDocumento:'00000000000100',financeiro:{secret:'hidden'}}]})};}});
  await assert.rejects(handler(request('intruder',{kind:'contacts'})),/Not admin/);
  assert.equal(calls,0);
  await handler(request('role-admin',{kind:'contacts'}));
  name='Contato atualizado';
  await handler(request('role-admin',{kind:'contacts'}));
  const mirror=(await db.doc('bling_private_contacts/246').get()).data();
  assert.equal(mirror.name,name); assert.equal(mirror.financeiro,undefined);
  assert.equal((await db.doc('public_partners/246').get()).exists,false);
  blocked=true;
  await assert.rejects(handler(request('role-admin',{kind:'contacts'})),e=>e.code==='permission-denied' && e.message.includes('Clientes e Fornecedores'));
});

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
  assert.equal((await db.doc('personal_data/new-one').get()).data().personType,'individual');
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
  await updateMyData.run(request('new-three', {name:'Consumidor Empresa', offers:false,
    personType:'company', cpf:'', cnpj:'62.581.826/0001-49', companyLegalName:'Royal Clean Distribuidora LTDA', role:'admin', phoneVerified:true}));
  assert.equal((await db.doc('users/new-three').get()).data().role,'consumer');
  const company = (await db.doc('personal_data/new-three').get()).data();
  assert.equal(company.personType,'company');
  assert.equal(company.phoneVerified,false);
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

test('Dashboard manual refresh discovers new products and refreshes their current status privately',async()=>{
  await db.doc('integrations_private/bling').set({accessToken:'test-token',expiresAt:Timestamp.fromMillis(Date.now()+3600000)});
  const paths=[];
  const handler=createBlingDataHandler({db,authenticated:async r=>({uid:r.auth.uid}),requireAdmin:async u=>{if(u.uid!=='role-admin')throw Error('Not admin');},rateLimit:async()=>{},fetchImpl:async url=>{
    const p=new URL(url);paths.push(p.pathname);
    if(p.pathname==='/Api/v3/produtos') {assert.equal(p.searchParams.get('limite'),'100');return {ok:true,status:200,json:async()=>({data:[{id:456789,nome:'Teste',situacao:'A',preco:10}]})};}
    return {ok:true,status:200,json:async()=>({data:{id:Number(p.pathname.split('/').at(-1)),situacao:'I',preco:11,estoque:{saldoVirtualTotal:2},privateSecret:'never-copy'}})};
  }});
  await handler(request('role-admin',{kind:'dashboard',group:'products',period:'monthly',refreshDetails:true,syncLatest:true,refreshSince:new Date().toISOString()}));
  const row=(await db.doc('bling_private_products/456789').get()).data();
  assert.equal(row.status,'A');assert.equal(row.price,10);assert.equal(row.privateSecret,undefined);
  assert.ok(paths.includes('/Api/v3/produtos'));assert.equal(paths.includes('/Api/v3/produtos/456789'),false);
  await db.doc('bling_private_products/456789').delete();
});
test('Full product catalog paginates, preserves SKU, excludes deleted from current total, and retains last complete version on failure',async()=>{
  const {syncProductCatalog}=await import('../bling-product-catalog.js');
  const {sanitizeBlingRecord}=await import('../bling-data.js');
  const {readDashboard}=await import('../bling-dashboard.js');
  const state=db.doc('integrations_private/bling_product_catalog');await state.delete();
  let rows=Array.from({length:539},(_,i)=>({id:800000+i,nome:`Produto ${i}`,codigo:`000${i}`,preco:10+i,situacao:i<426?'A':i===426?'I':'E'}));
  let failPage=0;const pages=[];
  const get=async path=>{const u=new URL('https://example.test/'+path);assert.equal(u.searchParams.get('criterio'),'5');assert.equal(u.searchParams.get('tipo'),'T');const p=+u.searchParams.get('pagina');pages.push(p);if(p===failPage)return {ok:false,status:503};return {ok:true,data:rows.slice((p-1)*100,p*100)};};
  const sync=()=>syncProductCatalog({db,get,sanitize:x=>sanitizeBlingRecord('products',x),recheck:async()=>{},force:true});
  await sync();assert.deepEqual(pages,[1,2,3,4,5,6]);
  let dashboard=await readDashboard(db,{group:'products',period:'monthly'});
  assert.equal(dashboard.records,427);assert.equal(dashboard.excluded,112);assert.equal(dashboard.partial,false);
  assert.deepEqual(dashboard.metrics[0].values,[426,1,0]);
  const original=(await db.doc('bling_private_products/800001').get()).data();assert.equal(original.code,'0001');assert.equal(original.id,'800001');
  const completed=(await state.get()).data().complete.runId;
  rows=[...rows.slice(1),{id:900000,nome:'Novo produto',codigo:'NEW-001',preco:29.95,situacao:'A'}];
  failPage=2;await assert.rejects(sync(),/última versão completa/);
  assert.equal((await state.get()).data().complete.runId,completed);
  dashboard=await readDashboard(db,{group:'products',period:'daily'});assert.equal(dashboard.catalogPending,true);assert.equal(dashboard.records,427);
  failPage=0;await sync();assert.notEqual((await state.get()).data().complete.runId,completed);
  assert.equal((await db.doc('bling_private_products/900000').get()).data().code,'NEW-001');
  assert.equal((await readDashboard(db,{group:'products',period:'daily'})).records,427);
  // Isolated emulator-only fixture cleanup, including both staging slots.
  for(const slot of ['a','b']) await db.recursiveDelete(db.doc(`bling_catalog_snapshots/${slot}`));
  await state.delete();
});
test('Full contacts and invoices include newly created records, cancellation updates and preserve complete snapshots on failure',async()=>{
  const {syncRecordCatalog}=await import('../bling-record-catalog.js');
  const {sanitizeBlingRecord}=await import('../bling-data.js');
  const {readDashboard}=await import('../bling-dashboard.js');
  for(const group of ['contacts','invoices']){
    const state=db.doc(`integrations_private/bling_${group}_catalog`);await state.delete();
    let rows=Array.from({length:107},(_,i)=>({id:700000+i,nome:`Cadastro ${i}`,situacao:group==='invoices'?5:'A',tipo:1,numero:i,dataEmissao:'2026-09-26',valorNota:10,tiposContato:[{id:1}]}));
    let failed=false;
    const get=async path=>{
      const u=new URL('https://example.test/'+path);
      if(path==='contatos/tipos')return {ok:true,data:[{id:1,descricao:'Cliente'}]};
      if(u.searchParams.has('pagina')){
        const page=+u.searchParams.get('pagina'),limit=+u.searchParams.get('limite');
        if(failed&&page===2)return {ok:false,status:503};
        const filtered=group==='invoices'?rows.filter(r=>u.searchParams.has('situacao')?r.situacao===2:r.situacao!==2):rows;
        return {ok:true,data:filtered.slice((page-1)*limit,page*limit+(page===1?2:0))};
      }
      return {ok:true,data:rows.find(r=>String(r.id)===path.split('/').at(-1))};
    };
    const sync=()=>syncRecordCatalog({db,group,get,sanitize:x=>sanitizeBlingRecord(group,x),recheck:async()=>{},force:true});
    await sync();
    let result=await readDashboard(db,{group,period:'yearly'});assert.equal(result.records,107);assert.equal(result.partial,false);
    const completed=(await state.get()).data().complete.runId;
    rows.push({...rows[0],id:800000,nome:'Novo registro'});
    if(group==='invoices')rows[0].situacao=2;
    failed=true;await assert.rejects(sync(),/preservado/);
    assert.equal((await state.get()).data().complete.runId,completed);
    assert.equal((await readDashboard(db,{group,period:'yearly'} )).records,107);
    failed=false;await sync();
    result=await readDashboard(db,{group,period:'yearly'});assert.equal(result.records,108);assert.equal(result.catalogPending,false);
    if(group==='invoices')assert.equal(result.metrics.find(m=>m.label==='Canceladas').values.reduce((a,b)=>a+b),1);
    else assert.equal((await readDashboard(db,{group,period:'yearly',contactRole:'customer'} )).records,108);
    await state.delete();
    for(const slot of ['a','b'])await db.recursiveDelete(db.collection(`bling_catalog_snapshots/${slot}/${group}`));
    for(const row of rows)await db.doc(`bling_private_${group}/${row.id}`).delete();
  }
});

test('Scheduled sync resumes pending groups, isolates failures and never includes sales',async()=>{
  const {createScheduledBlingSync}=await import('../bling-scheduled-sync.js');
  const ref=db.doc('integrations_private/bling_scheduled_sync');await ref.delete();
  await db.doc('integrations_private/bling').set({connectedBy:'role-admin'});
  const calls=[];
  let transient=0;const run=createScheduledBlingSync({db,wait:async()=>{},read:async request=>{
    assert.equal(request.auth.uid,'role-admin');calls.push(request.data);
    if(request.data.group==='invoices')throw Object.assign(new Error('provider unavailable'),{code:'permission-denied'});
    if(request.data.group==='contacts'&&transient++===0)throw Object.assign(new Error('retry'),{code:'unavailable'});
    return {enrichment:{catalogPending:request.data.group==='products'&&request.data.syncLatest}};
  }});
  await run();
  assert.deepEqual(calls.map(c=>c.group),['products','products','invoices','contacts','contacts']);
  assert.deepEqual(calls.map(c=>c.syncLatest),[true,false,true,true,true]);
  assert.deepEqual((await ref.get()).data().results,{products:'complete',invoices:'permission-denied',contacts:'complete'});
  await ref.set({leaseUntil:Date.now()+60000});await run();assert.equal(calls.length,5);
  await ref.delete();
});

test('Parallel catalog details share the account quota and publish only safe complete records',async()=>{
  const state=db.doc('integrations_private/bling_contacts_catalog');await state.delete();
  await db.doc('integrations_private/bling_read_quota').delete();
  await db.doc('integrations_private/bling').set({accessToken:'test-token',expiresAt:Timestamp.fromMillis(Date.now()+3600000)});
  const times=[];
  const rows=Array.from({length:7},(_,i)=>({id:910000+i,nome:'Contato de teste',situacao:'A',tiposContato:[{id:1}]}));
  const handler=createBlingDataHandler({db,authenticated:async()=>({uid:'role-admin'}),requireAdmin:async()=>{},rateLimit:async()=>{},fetchImpl:async url=>{
    times.push(Date.now());const path=new URL(url).pathname;
    const data=path.endsWith('/tipos')?[{id:1,descricao:'Cliente'}]:path.endsWith('/contatos')?rows:rows.find(row=>String(row.id)===path.split('/').at(-1));
    return {ok:true,status:200,json:async()=>({data})};
  }});
  const result=await handler(request('role-admin',{kind:'dashboard',group:'contacts',period:'yearly',refreshDetails:true,syncLatest:true}));
  assert.equal(result.records,7);assert.equal(result.partial,false);assert.equal(times.length,9);
  for(let i=1;i<times.length;i++)assert.ok(times[i]-times[i-1]>=350,'Provider requests must be spaced, even for parallel details');
  await state.delete();
  for(const slot of ['a','b'])await db.recursiveDelete(db.collection(`bling_catalog_snapshots/${slot}/contacts`));
  for(const row of rows)await db.doc(`bling_private_contacts/${row.id}`).delete();
});
