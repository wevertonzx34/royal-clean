import {createHash} from 'node:crypto';
import {FieldValue, Timestamp} from 'firebase-admin/firestore';

const DAY = 86400000;
export const millis = value => value?.toMillis?.() ?? (typeof value === 'number' ? value : null);
const key = value => createHash('sha256').update(value).digest('hex');
// Brazil has no DST: business dates are always interpreted in São Paulo (UTC-3).
export function contactPeriods(period, now = Date.now()) {
  const local = new Date(now - 3 * 3600000);
  const y = local.getUTCFullYear(), m = local.getUTCMonth(), d = local.getUTCDate();
  const midnight = (year, month, day) => Date.UTC(year, month, day) + 3 * 3600000;
  let start, end, step;
  if (period === 'daily') {
    end = midnight(y,m,d+1); start=end-14*DAY; step=DAY;
  } else if (period === 'weekly') {
    end=midnight(y,m,d+1)+(7-((local.getUTCDay()+6)%7)-1)*DAY; start=end-12*7*DAY; step=7*DAY;
  } else {
    const months={monthly:1,quarterly:3,halfYear:6,yearly:12}[period];
    if (!months) throw new Error('Invalid period');
    const aligned=Math.floor(m/months)*months;
    return Array.from({length:period==='yearly'?5:8}, (_, i) => {
      const offset=(i-(period==='yearly'?4:7))*months;
      return {start:midnight(y,aligned+offset,1),end:midnight(y,aligned+offset+months,1)};
    });
  }
  return Array.from({length:(end-start)/step},(_,i)=>({start:start+i*step,end:start+(i+1)*step}));
}

export function buildContactsOverview({profiles, invites, presence, samples, coverage, period, now=Date.now()}) {
  const bins=contactPeriods(period,now).filter(b=>b.start<=now).map(b=>{
    const cutoff=Math.min(b.end,now);
    const registered=profiles.filter(p=>p.createdAt>=b.start&&p.createdAt<cutoff).length;
    const deleted=profiles.filter(p=>p.deletedAt>=b.start&&p.deletedAt<cutoff).length;
    // Pending invitations are a cohort, NOT another deletion or a registered user.
    const pending=invites.filter(p=>p.createdAt>=b.start&&p.createdAt<cutoff
      && !(p.usedAt!=null&&p.usedAt<=cutoff) && !(p.endedAt!=null&&p.endedAt<=cutoff)
      && !(p.expiresAt!=null&&p.expiresAt<=cutoff)).length;
    let online=null, absent=null, activityAt=null;
    if (b.end>now) {
      const living=profiles.filter(p=>p.createdAt<=now&&!(p.deletedAt!=null&&p.deletedAt<=now)&&p.active!==false);
      const live=new Set(presence.filter(p=>p.foreground&&p.updatedAt>=now-120000).map(p=>p.user));
      online=living.filter(p=>live.has(p.id)).length; absent=living.length-online; activityAt=now;
    } else {
      const sample=samples.filter(s=>s.at>=b.start&&s.at<=b.end).sort((a,b)=>b.at-a.at)[0];
      if(sample) { online=sample.online; absent=sample.absent; activityAt=sample.at; }
    }
    const playersOpen=profiles.filter(p=>p.createdAt<b.start&&(p.deletedAt==null||p.deletedAt>=b.start)).length;
    const playersPositiveClose=playersOpen+registered;
    const activitySamples=samples.filter(s=>s.at>=b.start&&s.at<b.end&&s.at<=cutoff).sort((a,b)=>a.at-b.at);
    const first=activitySamples[0];
    const activityOpen=first?.open??first?.online??online;
    const activityClose=online;
    const highs=activitySamples.map(s=>s.high??s.online);
    const lows=activitySamples.map(s=>s.low??s.online);
    if(online!=null){highs.push(online);lows.push(online);}
    if(activityOpen!=null){highs.push(activityOpen);lows.push(activityOpen);}
    return {...b, registered, deleted, pending, online, absent, activityAt,
      playersOpen,playersPositiveClose,playersClose:playersPositiveClose-deleted-pending,
      totalRegisteredEnd:playersPositiveClose-deleted,
      activityOpen,activityClose,activityHigh:highs.length?Math.max(...highs):null,
      activityLow:lows.length?Math.min(...lows):null,
      activityPartial:!first||activitySamples.some(s=>s.partial===true)||(first.firstAt??first.at)>b.start+120000
        ||activitySamples.length<Math.max(1,Math.ceil((cutoff-b.start)/DAY)),
      deletionComplete:coverage!=null&&b.start>=coverage,closed:b.end<=now};
  });
  for(let i=1;i<bins.length;i++)bins[i].playersBaseAdjustment=bins[i].playersOpen-bins[i-1].playersClose;
  return {source:'royal-clean',period,generatedAt:now,coverageFrom:coverage,bins,
    records:profiles.filter(p=>p.deletedAt==null).length};
}

export function activityObservation(old,previous,now,online,absent) {
  if(old?.at>now)return old;
  const dayStart=Date.UTC(...(()=>{const d=new Date(now-3*3600000);return [d.getUTCFullYear(),d.getUTCMonth(),d.getUTCDate()];})())+3*3600000;
  const firstAt=old?.firstAt??old?.at??now;
  const open=old?.open??old?.online??previous?.close??previous?.online??online;
  return {at:now,firstAt,open,close:online,high:Math.max(old?.high??old?.online??open,open,online),
    low:Math.min(old?.low??old?.online??open,open,online),online,absent,
    observations:(old?.observations??(old?1:0))+1,partial:old?.partial??(firstAt>dayStart+120000)};
}

export function createContactsPerformance({db, auth, authenticated, requireAdmin, rateLimit}) {
  async function coverage() {
    const ref=db.doc('app_contact_meta/coverage');
    await db.runTransaction(async tx=>{if(!(await tx.get(ref)).exists)tx.create(ref,{startedAt:FieldValue.serverTimestamp()});});
    return millis((await ref.get()).data()?.startedAt);
  }
  async function profile(uid, data, deletedAt=null) {
    const ref=db.doc(`app_contact_profiles/${key(uid)}`);
    await db.runTransaction(async tx=>{
      const old=(await tx.get(ref)).data();
      const incoming=millis(data?.createdAt)??old?.createdAt;
      const createdAt=old?.createdAt!=null&&incoming!=null?Math.min(old.createdAt,incoming):incoming;
      if(createdAt==null)return; // Never fabricate an original registration date.
      const next={createdAt,active:data?.active??old?.active??true,deletedAt:old?.deletedAt??deletedAt};
      if(old&&old.createdAt===next.createdAt&&old.active===next.active&&old.deletedAt===next.deletedAt)return;
      tx.set(ref,next,{merge:true});
    });
  }
  async function userWritten(event) {
    await coverage();
    const before=event.data?.before.data(),after=event.data?.after.data();
    if(!before&&!after)return;
    await profile(event.params.uid,after??before,after?null:Date.parse(event.time));
  }
  async function authDeleted(user,context) {
    await coverage();
    let data=(await db.doc(`users/${user.uid}`).get()).data();
    if(!data&&(await db.doc(`admin/${user.uid}`).get()).exists) {
      const createdAt=Date.parse(user.metadata.creationTime);
      if(Number.isFinite(createdAt))data={createdAt};
    }
    await profile(user.uid,data,Date.parse(context.timestamp));
  }
  async function adminProfile(uid,data) {
    if(!data||data.eAdministrador!==true)return;
    let account;
    try { account=await auth.getUser(uid); }
    catch(error) { if(error.code==='auth/user-not-found')return; throw error; }
    const createdAt=millis(data.createdAt)??Date.parse(account.metadata.creationTime);
    if(!Number.isFinite(createdAt))return;
    await profile(uid,{createdAt,active:data.ativo===true&&!account.disabled});
  }
  async function adminWritten(event) {
    await coverage();
    const before=event.data?.before.data(),after=event.data?.after.data();
    // Removing an admin grant is a permission change, not deletion of the account.
    await adminProfile(event.params.uid,after?.eAdministrador===true?after:before?{...before,ativo:false}:null);
  }
  async function inviteWritten(event) {
    await coverage();
    const before=event.data?.before.data(),after=event.data?.after.data(),data=after??before;
    if(!data)return;
    const ended=!after||['cancelled','canceled','revoked','deleted','expired'].includes(data.status);
    const ref=db.doc(`app_contact_invites/${key(event.params.inviteId)}`);
    await db.runTransaction(async tx=>{
      const old=(await tx.get(ref)).data()??{};
      const createdAt=millis(data.createdAt)??old.createdAt;
      if(createdAt==null)return;
      const next={createdAt,usedAt:millis(data.usedAt)??old.usedAt??null,
        expiresAt:millis(data.expiresAt)??old.expiresAt??null,
        endedAt:old.endedAt??(ended?Date.parse(event.time):null)};
      if(JSON.stringify(next)===JSON.stringify(old))return;
      tx.set(ref,next);
    });
  }
  let seeded=false;
  async function seed() {
    if(seeded)return;
    // A paginated backfill preserves historical createdAt without copying PII.
    for(const collection of ['users','access_invites','admin']) {
      let last;
      for(;;) {
        let q=db.collection(collection).orderBy('__name__').limit(300);
        if(last)q=q.startAfter(last);
        const page=await q.get(); if(page.empty)break;
        for(let offset=0;offset<page.docs.length;offset+=20) {
          await Promise.all(page.docs.slice(offset,offset+20).map(doc=>collection==='users'
            ? profile(doc.id,doc.data()) : collection==='admin'?adminProfile(doc.id,doc.data())
            : inviteWritten({params:{inviteId:doc.id},time:new Date().toISOString(),data:{after:doc,before:{data:()=>null}}})));
        }
        last=page.docs.at(-1); if(page.size<300)break;
      }
    }
    seeded=true;
  }
  async function readState({history=true}={}) {
    const [p,i,s,a]=await Promise.all([
      db.collection('app_contact_profiles').get(),history?db.collection('app_contact_invites').get():Promise.resolve({docs:[]}),
      db.collection('app_contact_presence').where('updatedAt','>=',Timestamp.fromMillis(Date.now()-120000)).get(),
      history?db.collection('app_contact_activity').orderBy('at','desc').limit(800).get():Promise.resolve({docs:[]}),
    ]);
    return {profiles:p.docs.map(d=>({id:d.id,...d.data()})),invites:i.docs.map(d=>d.data()),
      presence:s.docs.map(d=>({...d.data(),updatedAt:millis(d.data().updatedAt)})),
      samples:a.docs.map(d=>d.data())};
  }
  async function overview(request) {
    const user=await authenticated(request); await requireAdmin(user); await rateLimit(user.uid,'contacts_overview',12);
    const period=request.data?.period??'daily'; contactPeriods(period);
    const started=await coverage(); await seed();
    const state=await readState(),now=Date.now();
    const live=buildContactsOverview({...state,coverage:started,period:'daily',now}).bins.at(-1);
    const observation=await recordActivity(now,live.online,live.absent);
    const dayStart=contactPeriods('daily',now).at(-1).start;
    state.samples=state.samples.filter(s=>s.at<dayStart);state.samples.push(observation);
    return buildContactsOverview({...state,coverage:started,period,now});
  }
  async function heartbeat(request) {
    const user=await authenticated(request); await rateLimit(user.uid,'contacts_presence',10);
    let data=(await db.doc(`users/${user.uid}`).get()).data();
    if(!data) {
      const admin=(await db.doc(`admin/${user.uid}`).get()).data();
      if(admin?.eAdministrador!==true||admin.ativo!==true||admin.email?.toLowerCase()!==user.email?.toLowerCase())return {accepted:false};
      const createdAt=millis(admin.createdAt)??Date.parse(user.metadata.creationTime);
      if(!Number.isFinite(createdAt))return {accepted:false};
      data={createdAt,active:true};
    }
    if(!data||data.active===false)return {accepted:false};
    const session=request.data?.session;
    if(typeof session!=='string'||!/^[a-zA-Z0-9-]{16,80}$/.test(session))return {accepted:false};
    await profile(user.uid,data);
    await db.doc(`app_contact_presence/${key(user.uid+':'+session)}`).set({user:key(user.uid),
      foreground:request.data.foreground===true,updatedAt:FieldValue.serverTimestamp(),
      expiresAt:Timestamp.fromMillis(Date.now()+DAY)});
    if(request.data.foreground===true)await db.doc(`app_contact_profiles/${key(user.uid)}`).set({lastSeenAt:FieldValue.serverTimestamp()},{merge:true});
    return {accepted:true};
  }
  async function snapshot() {
    await coverage(); await seed();
    const now=Date.now(),state=await readState({history:false});
    const bin=buildContactsOverview({...state,coverage:now,period:'daily',now}).bins.at(-1);
    await recordActivity(now,bin.online,bin.absent);
    // Remove expired ephemeral device sessions; never remove account or business data.
    const stale=await db.collection('app_contact_presence').where('expiresAt','<',Timestamp.fromMillis(now)).limit(400).get();
    const batch=db.batch(); for(const doc of stale.docs)batch.delete(doc.ref); if(!stale.empty)await batch.commit();
  }
  async function recordActivity(now,online,absent) {
    const day=new Date(now-3*3600000).toISOString().slice(0,10);
    const previous=new Date(now-3*3600000-DAY).toISOString().slice(0,10);
    return db.runTransaction(async tx=>{
      const ref=db.doc(`app_contact_activity/${day}`);
      const [current,prior]=await Promise.all([tx.get(ref),tx.get(db.doc(`app_contact_activity/${previous}`))]);
      const next=activityObservation(current.data(),prior.data(),now,online,absent);
      tx.set(ref,next);return next;
    });
  }
  return {overview,heartbeat,userWritten,inviteWritten,adminWritten,authDeleted,snapshot};
}
