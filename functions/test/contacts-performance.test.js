import test from 'node:test';
import assert from 'node:assert/strict';
import {buildContactsOverview,contactPeriods,activityObservation} from '../contacts-performance.js';
const now=Date.parse('2026-10-11T15:00:00-03:00');
const time=s=>Date.parse(s+'-03:00');
test('Daily uses full São Paulo day and separates registration, deletion and pending cohort',()=>{
 const result=buildContactsOverview({now,period:'daily',coverage:time('2026-10-01T00:00:00'),
 profiles:[{id:'a',createdAt:time('2026-10-11T01:00:00'),deletedAt:null},{id:'b',createdAt:time('2026-10-10T23:00:00'),deletedAt:time('2026-10-11T05:00:00')}],
 invites:[{createdAt:time('2026-10-11T08:00:00'),expiresAt:now+1000},{createdAt:time('2026-10-10T08:00:00')},{createdAt:time('2026-10-11T08:00:00'),usedAt:now-1}],
 presence:[{user:'a',foreground:true,updatedAt:now-1000}],samples:[]});
 const b=result.bins.at(-1);
 assert.equal(b.start,time('2026-10-11T00:00:00'));assert.equal(b.registered,1);assert.equal(b.deleted,1);assert.equal(b.pending,1);
 assert.equal(b.online,1);assert.equal(b.absent,0);assert.equal(b.closed,false);
});
test('Players opens from real prior registrations, never from a fictitious invitation loss',()=>{
 const state={now,period:'daily',coverage:time('2026-10-01T00:00:00'),presence:[],samples:[],
 profiles:[{id:'a',createdAt:time('2026-10-09T10:00:00'),deletedAt:time('2026-10-10T15:00:00')},
 {id:'b',createdAt:time('2026-10-09T10:00:00')},{id:'c',createdAt:time('2026-10-10T10:00:00')},
 {id:'d',createdAt:time('2026-10-11T10:00:00')}],invites:[{createdAt:time('2026-10-10T10:00:00')}]};
 const bins=buildContactsOverview(state).bins;
 assert.equal(bins.at(-2).playersOpen,2);assert.equal(bins.at(-2).playersPositiveClose,3);
 assert.equal(bins.at(-2).playersClose,1);assert.equal(bins.at(-2).totalRegisteredEnd,2);
 assert.equal(bins.at(-1).playersOpen,2);assert.equal(bins.at(-1).playersBaseAdjustment,1);
 assert.equal(bins.at(-1).playersClose,3);
});
test('Activity retains observed OHLC across reads, rollover and out-of-order delivery',()=>{
 const start=time('2026-10-11T00:00:00');
 let sample=activityObservation(null,{close:4},start+60000,6,2);
 sample=activityObservation(sample,null,start+120000,9,1);
 sample=activityObservation(sample,null,start+180000,3,7);
 assert.equal(sample.open,4);assert.equal(sample.high,9);assert.equal(sample.low,3);assert.equal(sample.close,3);
 assert.equal(activityObservation(sample,null,start+100000,99,0).high,9);
 const b=buildContactsOverview({now:start+240000,period:'daily',coverage:start,profiles:[],invites:[],presence:[],samples:[sample]}).bins.at(-1);
 assert.equal(b.activityHigh,9);assert.equal(b.activityLow,0);assert.equal(b.activityClose,0);
});
test('Expired, revoked and used invitations do not remain processing; missing presence stays unknown',()=>{
 const result=buildContactsOverview({now,period:'daily',coverage:now,profiles:[],presence:[],samples:[],invites:[
 {createdAt:now-10000,expiresAt:now-1},{createdAt:now-10000,endedAt:now-1},{createdAt:now-10000,usedAt:now-1}]});
 assert.equal(result.bins.at(-1).pending,0);
 assert.equal(result.bins.at(-2).online,null);assert.equal(result.bins.at(-2).deletionComplete,false);
});
test('Historical invitation state is evaluated at closing, not today; devices are deduplicated',()=>{
 const created=time('2026-10-10T10:00:00');
 const result=buildContactsOverview({now,period:'daily',coverage:now,profiles:[{id:'a',createdAt:created},{id:'b',createdAt:created}],
 invites:[{createdAt:created,usedAt:now-1000}],presence:[{user:'a',foreground:true,updatedAt:now},{user:'a',foreground:true,updatedAt:now},{user:'b',foreground:true,updatedAt:now-121000}],
 samples:[{at:time('2026-10-10T23:59:00'),online:0,absent:2}]});
 assert.equal(result.bins.at(-2).pending,1);assert.equal(result.bins.at(-2).absent,2);
 assert.equal(result.bins.at(-1).online,1);assert.equal(result.bins.at(-1).absent,1);
});
test('All timeframes are contiguous and no invalid period is accepted',()=>{
 for(const period of ['daily','weekly','monthly','quarterly','halfYear','yearly']){
 const bins=contactPeriods(period,now);for(let i=1;i<bins.length;i++)assert.equal(bins[i-1].end,bins[i].start);
 assert.ok(bins.at(-1).start<=now&&bins.at(-1).end>now);
 }assert.throws(()=>contactPeriods('bad',now));
});
