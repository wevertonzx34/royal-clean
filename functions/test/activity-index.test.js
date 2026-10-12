import test from 'node:test';
import assert from 'node:assert/strict';
import {activityStrength,activityReference,advanceActivityIndex,localActivityDay,publicActivityIndex} from '../activity-index.js';
const minute=60000,day=86400000,start=Date.parse('2026-10-12T03:00:00Z');
const refs=()=>Array.from({length:24},()=>({ppm:50000,origin:'initial'}));
const advance=(input)=>advanceActivityIndex({now:start,online:1,eligible:1,references:refs(),...input});
test('Normalized strength is invariant to network size and cannot exceed one point per day',()=>{
 assert.deepEqual(activityStrength(1,10,50000),activityStrength(1000,10000,50000));
 let value;
 for(let i=0;i<1440;i++)value=advance({state:value?.state,day:value?.day,now:start+i*minute});
 assert.equal(value.day.open,100);assert.equal(value.day.close,101);assert.equal(value.day.high,101);assert.equal(value.day.low,100);
 assert.equal(value.day.volume,1);assert.equal(value.day.coverage,1);assert.equal(value.day.partial,false);
 let other;
 for(let i=0;i<1440;i++)other=advance({state:other?.state,day:other?.day,now:start+i*minute,online:10,eligible:10});
 assert.equal(other.day.close,101);assert.equal(other.day.volume,10);
});
test('Retries, missing minutes and no eligible profiles cannot fabricate points',()=>{
 const first=advance({});
 assert.equal(advance({state:first.state,day:first.day}),null);
 const second=advance({state:first.state,day:first.day,now:start+10*minute,online:0,eligible:0});
 assert.equal(second.day.close,first.day.close);assert.equal(second.day.observed,1);assert.equal(second.day.partial,true);
 const negative=advance({state:second.state,day:second.day,now:start+11*minute,online:0,eligible:1});
 assert.ok(negative.day.close<second.day.close);assert.equal(negative.day.high,first.day.close);
 assert.equal(activityStrength(2,1,50000),null);
});
test('Next candle opens at previous close; wick preserves real extremes',()=>{
 const up=advance({});
 const down=advance({state:up.state,day:up.day,now:start+minute,online:0,eligible:1});
 const next=advance({state:down.state,now:start+day});
 assert.equal(next.day.open,down.day.close);assert.equal(down.day.high,up.day.close);
 assert.equal(down.day.low,100);assert.equal(localActivityDay(start+day-1).id,'2026-10-12');
});
test('Historical references require comparable days and remain frozen through the day',()=>{
 const local=localActivityDay(start);
 const history=[7,14,21].map(n=>({start:start-n*day,weekday:1,hours:{0:{observed:60,ratioSum:60*200000}}}));
 assert.equal(activityReference(history.slice(0,2),local)[0].ppm,50000);
 const historical=activityReference(history,local);assert.equal(historical[0].ppm,200000);assert.equal(historical[1].origin,'initial');
 const first=advance({references:historical});
 const second=advance({state:first.state,day:first.day,now:start+minute,references:refs()});
 assert.equal(second.day.referencePpm,200000);
});
test('Public payload exposes only aggregates and marks gaps instead of inventing history',()=>{
 const sample=advance({now:start+12*minute});
 const result=publicActivityIndex([sample.day],'daily',start+13*minute);
 assert.equal(result.base,100);assert.equal(result.bins.at(-1).activityPartial,true);
 assert.equal(result.bins.at(-2).activityClose,null);assert.equal(result.bins.at(-1).activityClose,sample.day.close);
 for(const name of ['eligible','online','user','email','references','hours','lastSeenAt'])assert.equal(result.bins.at(-1)[name],undefined);
});
