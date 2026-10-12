// One immutable minute history; all views use the same underlying index.
const MINUTE=60000,DAY=86400000,ZONE=3*3600000;
export const ACTIVITY_PERIODS=['m1','m5','m15','m30','h1','h4','daily','weekly','monthly','quarterly','halfYear','yearly'];
export const INTRADAY_MINUTES={m1:1,m5:5,m15:15,m30:30,h1:60,h4:240};
export function activityWindow(period,now){
 const d=new Date(now-ZONE),y=d.getUTCFullYear(),m=d.getUTCMonth();
 const midnight=Date.UTC(y,m,d.getUTCDate())+ZONE;
 if(INTRADAY_MINUTES[period]){const width=INTRADAY_MINUTES[period]*MINUTE,start=midnight+Math.floor((now-midnight)/width)*width;return {start,end:start+width};}
 if(period==='daily')return {start:midnight,end:midnight+DAY};
 if(period==='weekly'){const start=midnight-((d.getUTCDay()+6)%7)*DAY;return {start,end:start+7*DAY};}
 const months={monthly:1,quarterly:3,halfYear:6,yearly:12}[period];
 if(!months)throw new Error('Invalid activity timeframe');
 const first=Math.floor(m/months)*months;
 return {start:Date.UTC(y,first,1)+ZONE,end:Date.UTC(y,first+months,1)+ZONE};
}
function coverage(start,end,at,observed){
 const expected=Math.max(1,Math.min((end-start)/MINUTE,Math.floor((at-start)/MINUTE)+1));
 return {coverage:Math.min(1,observed/expected),activityPartial:observed<expected};
}
export function finalizeActivityCandle(candle,now){
 const result=coverage(candle.start,candle.end,Math.min(now,candle.end-1),candle.observed);
 return {...candle,closed:candle.end<=now,...result,activityPartial:candle.activityPartial||result.activityPartial};
}
export function minuteActivityCandle(previousState,nextDay,now){
 const window=activityWindow('m1',now),open=100+(previousState?.totalStrength??0)/(1440*1000000);
 const observed=nextDay.strengthPpm==null?0:1,close=nextDay.close;
 return {...window,indexPoints:true,activityOpen:observed?open:null,activityClose:observed?close:null,
  activityHigh:observed?Math.max(open,close):null,activityLow:observed?Math.min(open,close):null,
  observed,volume:observed?nextDay.online/1440:0,activityAt:now,
  referencePpm:nextDay.referencePpm,referenceOrigin:nextDay.referenceOrigin,...coverage(window.start,window.end,now,observed)};
}
export function rollActivityCandle(previous,sample,period,now){
 const window=activityWindow(period,now),old=previous??{};
 if(old.activityAt>=now)return old;
 const observed=(old.observed??0)+sample.observed;
 const values=[old,sample].filter(x=>x.activityClose!=null);
 return {...window,indexPoints:true,activityOpen:values[0]?.activityOpen??null,activityClose:values.at(-1)?.activityClose??null,
  activityHigh:values.length?Math.max(...values.map(x=>x.activityHigh)):null,
  activityLow:values.length?Math.min(...values.map(x=>x.activityLow)):null,
  observed,volume:(old.volume??0)+sample.volume,activityAt:now,
  referencePpm:sample.referencePpm,referenceOrigin:sample.referenceOrigin,...coverage(window.start,window.end,now,observed)};
}
export function aggregateActivityDays(days,period,now){
 const groups=new Map();
 for(const d of days){const w=activityWindow(period,d.start);if(!groups.has(w.start))groups.set(w.start,{window:w,rows:[]});groups.get(w.start).rows.push(d);}
 return [...groups.values()].sort((a,b)=>a.window.start-b.window.start).map(({window,rows})=>{
  rows.sort((a,b)=>a.start-b.start);const first=rows[0],last=rows.at(-1),observed=rows.reduce((sum,d)=>sum+d.observed,0);
  const c=coverage(window.start,window.end,Math.min(now,window.end-1),observed);
  return {...window,indexPoints:true,activityOpen:observed?first.open:null,activityClose:observed?last.close:null,
   activityHigh:observed?Math.max(...rows.map(d=>d.high)):null,activityLow:observed?Math.min(...rows.map(d=>d.low)):null,
   observed,volume:rows.reduce((sum,d)=>sum+d.volume,0),activityAt:last.at,
   referencePpm:last.referencePpm,referenceOrigin:last.referenceOrigin,...c,activityPartial:c.activityPartial||rows.some(d=>d.partial)};
 });
}
