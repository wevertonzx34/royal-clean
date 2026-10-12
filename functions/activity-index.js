import {contactPeriods} from './contacts-performance.js';
import {ACTIVITY_PERIODS,INTRADAY_MINUTES,activityWindow,minuteActivityCandle,rollActivityCandle,aggregateActivityDays,finalizeActivityCandle} from './activity-candles.js';

export const ACTIVITY_METHOD = 'royal-activity-v1';
export const ACTIVITY_BASE = 100;
const MINUTE=60000,DAY=86400000,PPM=1000000,DIVISOR=1440*PPM;
const clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
export function localActivityDay(now) {
  const d=new Date(now-3*3600000);
  return {id:d.toISOString().slice(0,10),start:Date.UTC(d.getUTCFullYear(),d.getUTCMonth(),d.getUTCDate())+3*3600000,hour:d.getUTCHours(),weekday:d.getUTCDay()};
}
export function activityReference(history,day) {
  const matching=history.filter(h=>h.start<day.start&&h.start>=day.start-28*DAY&&h.weekday===day.weekday);
  return Array.from({length:24},(_,hour)=>{
    const rows=matching.map(d=>d.hours?.[hour]).filter(h=>h?.observed>=30);
    if(rows.length<3)return {ppm:50000,origin:'initial'};
    const observed=rows.reduce((sum,h)=>sum+h.observed,0);
    return {ppm:clamp(Math.round(rows.reduce((sum,h)=>sum+h.ratioSum,0)/observed),0,PPM),origin:'historical'};
  });
}
export function activityStrength(online,eligible,referencePpm) {
  if(!Number.isSafeInteger(online)||!Number.isSafeInteger(eligible)||eligible<=0||online<0||online>eligible)return null;
  const ratioPpm=Math.round(online/eligible*PPM);
  return {ratioPpm,strength:clamp(Math.round((ratioPpm-referencePpm)*PPM/Math.max(referencePpm,PPM-referencePpm)),-PPM,PPM)};
}
export function advanceActivityIndex({state,day,now,online,eligible,references}) {
  const local=localActivityDay(now),minute=Math.floor(now/MINUTE);
  if(state?.lastMinute>=minute)return null;
  const refs=day?.references??references;
  const score=activityStrength(online,eligible,refs[local.hour].ppm);
  const total=state?.totalStrength??0;
  const nextTotal=total+(score?.strength??0);
  if(!Number.isSafeInteger(nextTotal))throw new Error('Activity index precision limit');
  const open=day?.open??ACTIVITY_BASE+total/DIVISOR,close=ACTIVITY_BASE+nextTotal/DIVISOR;
  const observed=(day?.observed??0)+(score?1:0),slots=(day?.slots??0)+1;
  const hours={...(day?.hours??{})},oldHour=hours[local.hour]??{observed:0,ratioSum:0};
  if(score)hours[local.hour]={observed:oldHour.observed+1,ratioSum:oldHour.ratioSum+score.ratioPpm};
  const userMinutes=(day?.userMinutes??0)+(score?online:0);
  return {state:{method:ACTIVITY_METHOD,base:ACTIVITY_BASE,totalStrength:nextTotal,lastMinute:minute,at:now},
    day:{method:ACTIVITY_METHOD,start:local.start,end:local.start+DAY,weekday:local.weekday,
      open,close,high:Math.max(day?.high??open,close),low:Math.min(day?.low??open,close),
      observed,slots,userMinutes,volume:userMinutes/1440,hours,references:refs,
      firstAt:day?.firstAt??now,at:now,referencePpm:refs[local.hour].ppm,referenceOrigin:refs[local.hour].origin,
      strengthPpm:score?.strength??null,eligible,online,coverage:observed/Math.max(1,Math.min(1440,Math.floor((now-local.start)/MINUTE)+1)),
      partial:(day?.partial??(minute*MINUTE>local.start))||!score||(state?.lastMinute!=null&&minute-state.lastMinute>1)}};
}
export function publicActivityIndex(days,period,now) {
  const bins=contactPeriods(period,now).filter(b=>b.start<=now).map(b=>{
    const rows=days.filter(d=>d.start>=b.start&&d.start<b.end).sort((a,b)=>a.start-b.start);
    const first=rows[0],last=rows.at(-1),observed=rows.reduce((sum,d)=>sum+d.observed,0);
    const expected=Math.max(1,Math.floor((Math.min(now,b.end)-b.start)/MINUTE));
    return {...b,indexPoints:true,closed:b.end<=now,
      activityOpen:observed?first.open:null,activityClose:observed?last.close:null,
      activityHigh:observed?Math.max(...rows.map(d=>d.high)):null,activityLow:observed?Math.min(...rows.map(d=>d.low)):null,
      volume:rows.reduce((sum,d)=>sum+d.volume,0),observed,coverage:Math.min(1,observed/expected),
      activityPartial:rows.some(d=>d.partial)||observed<expected,activityAt:last?.at??null,
      referencePpm:last?.referencePpm??50000,referenceOrigin:last?.referenceOrigin??'initial'};
  });
  return {source:'royal-clean',method:ACTIVITY_METHOD,unit:'points',base:ACTIVITY_BASE,period,generatedAt:now,
    bins,latest:days.slice().sort((a,b)=>b.start-a.start)[0]?.close??ACTIVITY_BASE};
}
export function createActivityIndex({db}) {
  let archiveDay=null,archive=[];
  let archiveSeeded=false;
  const views=new Map();
  async function tick({now=Date.now()}={}) {
    // Only the scheduler advances points. Reads/refreshes can never generate points.
    const local=localActivityDay(now);
    // Closed candles are immutable. Cache them for this server instance/day.
    // Cold starts reload from Firestore; never rely on a cache to calculate points.
    if(archiveDay!==local.id){
      const history=await db.collection('app_activity_index_days').orderBy('start','desc').limit(1827).get();
      archive=history.docs.map(d=>d.data()).filter(d=>d.start<local.start);archiveDay=local.id;
    }
    const closedDays=archive.slice();
    if(!archiveSeeded){
      const meta=db.doc('app_activity_index_meta/candle_archive');
      if(!(await meta.get()).exists){
        const records=ACTIVITY_PERIODS.filter(p=>!INTRADAY_MINUTES[p]).flatMap(period=>aggregateActivityDays(closedDays,period,now).map(c=>({period,c})));
        for(let i=0;i<records.length;i+=400){const batch=db.batch();for(const {period,c} of records.slice(i,i+400))batch.set(db.doc(`public_activity_candles/${period}/candles/${c.start}`),c);await batch.commit();}
        await meta.set({at:now});
      }
      archiveSeeded=true;
    }
    const [profiles,presence]=await Promise.all([
      db.collection('app_contact_profiles').where('lastSeenAt','>=',new Date(now-30*DAY)).get(),
      db.collection('app_contact_presence').where('updatedAt','>=',new Date(now-120000)).get(),
    ]);
    const live=new Set(presence.docs.filter(d=>d.data().foreground===true).map(d=>d.data().user));
    const eligible=profiles.docs.filter(d=>{const p=d.data();return p.active!==false&&p.deletedAt==null
      &&((p.lastSeenAt?.toMillis?.()??0)>=now-30*DAY||live.has(d.id));});
    const online=eligible.filter(d=>live.has(d.id)).length;
    const refs=activityReference(closedDays,local);
    const result=await db.runTransaction(async tx=>{
      const stateRef=db.doc('app_activity_index_state/current'),dayRef=db.doc(`app_activity_index_days/${local.id}`);
      const intraday=Object.keys(INTRADAY_MINUTES);
      const candleRefs=intraday.map(p=>db.doc(`public_activity_candles/${p}/candles/${activityWindow(p,now).start}`));
      const [state,day,...candles]=await Promise.all([tx.get(stateRef),tx.get(dayRef),...candleRefs.map(ref=>tx.get(ref))]);
      const next=advanceActivityIndex({state:state.data(),day:day.data(),now,online,eligible:eligible.length,references:refs});
      const currentDay=next?.day??day.data();
      if(!currentDay)return null;
      const currentCandles=new Map();
      if(next){
        tx.set(stateRef,next.state);tx.set(dayRef,next.day);
        const sample=minuteActivityCandle(state.data(),next.day,now);
        for(let i=0;i<intraday.length;i++){
          const candle=rollActivityCandle(candles[i].data(),sample,intraday[i],now);
          tx.set(candleRefs[i],candle);currentCandles.set(intraday[i],candle);
        }
      }else for(let i=0;i<intraday.length;i++)if(candles[i].exists)currentCandles.set(intraday[i],candles[i].data());
      for(const period of ACTIVITY_PERIODS.filter(p=>!INTRADAY_MINUTES[p])){
        const candle=aggregateActivityDays([...closedDays,currentDay],period,currentDay.at).at(-1);
        if(next)tx.set(db.doc(`public_activity_candles/${period}/candles/${candle.start}`),candle);
        currentCandles.set(period,candle);
      }
      return {day:currentDay,candles:currentCandles};
    });
    if(!result)return;
    for(const period of ACTIVITY_PERIODS){
      if(!views.has(period)){
        const page=await db.collection(`public_activity_candles/${period}/candles`).orderBy('start','desc').limit(120).get();
        views.set(period,page.docs.map(d=>d.data()));
      }
      const current=result.candles.get(period);
      if(current)views.set(period,[...views.get(period).filter(c=>c.start!==current.start),current].sort((a,b)=>b.start-a.start).slice(0,120));
    }
    // Publish every period together, with no names, identities, invitations or device data.
    await db.runTransaction(async tx=>{
      const current=await tx.get(db.doc('app_activity_index_state/current'));
      // A late retry must never replace a newer closing value or time period.
      if(current.data()?.lastMinute!==Math.floor(now/MINUTE))return;
      const at=current.data().at;
      for(const period of ACTIVITY_PERIODS){
        const bins=views.get(period).filter(c=>c.start<=at).slice().reverse().map(c=>finalizeActivityCandle(c,at));
        tx.set(db.doc(`public_activity_index/${period}`),{source:'royal-clean',method:ACTIVITY_METHOD,unit:'points',base:100,period,generatedAt:at,
          latest:result.day.close,bins,pageSize:256});
      }
    });
  }
  return {tick};
}
