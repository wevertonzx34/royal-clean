import test from 'node:test';
import assert from 'node:assert/strict';
import {ACTIVITY_PERIODS,activityWindow,minuteActivityCandle,rollActivityCandle,aggregateActivityDays,finalizeActivityCandle} from '../activity-candles.js';
import {advanceActivityIndex} from '../activity-index.js';
const start=Date.parse('2026-10-12T03:00:00Z'),minute=60000;
const refs=Array.from({length:24},()=>({ppm:50000,origin:'initial'}));
test('1440 real minute samples reproduce the daily OHLC and volume in every intraday resolution',()=>{
 let state,day;const candles=new Map();
 for(let i=0;i<1440;i++){
  const now=start+i*minute,online=i<720?100:0;
  const next=advanceActivityIndex({state,day,now,online,eligible:100,references:refs});
  const sample=minuteActivityCandle(state,next.day,now);
  for(const period of ACTIVITY_PERIODS.slice(0,6)){
   const key=`${period}:${activityWindow(period,now).start}`;
   candles.set(key,rollActivityCandle(candles.get(key),sample,period,now));
  }
  state=next.state;day=next.day;
 }
 for(const [period,count] of [['m1',1440],['m5',288],['m15',96],['m30',48],['h1',24],['h4',6]]){
  const rows=[...candles].filter(([k])=>k.startsWith(`${period}:`)).map(([,c])=>c);
  assert.equal(rows.length,count);assert.equal(rows[0].activityOpen,day.open);assert.equal(rows.at(-1).activityClose,day.close);
  assert.equal(Math.max(...rows.map(c=>c.activityHigh)),day.high);assert.equal(Math.min(...rows.map(c=>c.activityLow)),day.low);
  assert.ok(Math.abs(rows.reduce((sum,c)=>sum+c.volume,0)-day.volume)<1e-8);
  for(let i=1;i<rows.length;i++)assert.equal(rows[i].activityOpen,rows[i-1].activityClose);
 }
 assert.ok(day.close>day.open);assert.ok(day.high>day.close); // Real upper wick, not an invented doji.
});
test('Timezone, four-hour boundaries, weeks and calendar months use aligned exchange-like sessions',()=>{
 assert.equal(activityWindow('h4',start+239*minute).start,start);
 assert.equal(activityWindow('h4',start+240*minute).start,start+240*minute);
 assert.equal(activityWindow('weekly',start).start,start);
 assert.equal(activityWindow('monthly',Date.parse('2026-02-28T22:00:00Z')).end,Date.parse('2026-03-01T03:00:00Z'));
 assert.equal(activityWindow('quarterly',start).start,Date.parse('2026-10-01T03:00:00Z'));
 assert.equal(activityWindow('halfYear',start).start,Date.parse('2026-07-01T03:00:00Z'));
});
test('Missing observations stay gaps; aggregation retains old daily history without inventing minute records',()=>{
 const missedClosing=finalizeActivityCandle({start,end:start+5*minute,observed:4,activityPartial:false},start+5*minute);
 assert.equal(missedClosing.coverage,.8);assert.equal(missedClosing.activityPartial,true);
 const next=advanceActivityIndex({now:start+10*minute,online:0,eligible:0,references:refs});
 const sample=minuteActivityCandle(undefined,next.day,start+10*minute);
 const candle=rollActivityCandle(undefined,sample,'m15',start+10*minute);
 assert.equal(candle.activityClose,null);assert.equal(candle.volume,0);assert.equal(candle.activityPartial,true);
 const days=[{start,open:100,close:100.2,high:100.4,low:99.9,observed:1440,volume:5,at:start+1439*minute,partial:false,referencePpm:50000,referenceOrigin:'initial'}];
 const result=aggregateActivityDays(days,'daily',start+1440*minute);
 assert.equal(result[0].activityHigh,100.4);assert.equal(result[0].activityPartial,false);
 assert.equal(result[0].activityClose,100.2);
});
