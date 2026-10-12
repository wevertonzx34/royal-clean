import test from 'node:test';
import assert from 'node:assert/strict';
import {initializeApp} from 'firebase-admin/app';
import {getFirestore,Timestamp} from 'firebase-admin/firestore';
import {createActivityIndex} from '../activity-index.js';
if(process.env.FIRESTORE_EMULATOR_HOST!=='127.0.0.1:8185')throw new Error('Local emulator required');
const db=getFirestore(initializeApp({projectId:'demo-royal-clean'},'activity-index-tests'));
test('Scheduled calculation deduplicates devices, filters deleted profiles, retries safely and publishes guest-safe periods',async()=>{
 const now=Date.parse('2026-10-13T12:00:00Z');
 await db.doc('app_contact_profiles/index-active').set({active:true,lastSeenAt:Timestamp.fromMillis(now)});
 await db.doc('app_contact_profiles/index-away').set({active:true,lastSeenAt:Timestamp.fromMillis(now-86400000)});
 await db.doc('app_contact_profiles/index-deleted').set({active:true,deletedAt:now,lastSeenAt:Timestamp.fromMillis(now)});
 for(const id of ['device-one','device-two'])await db.doc(`app_contact_presence/${id}`).set({user:'index-active',foreground:true,updatedAt:Timestamp.fromMillis(now)});
 const service=createActivityIndex({db});await service.tick({now});
 const first=(await db.doc('app_activity_index_days/2026-10-13').get()).data();
 assert.equal(first.online,1);assert.equal(first.eligible,2);
 await service.tick({now});assert.deepEqual((await db.doc('app_activity_index_days/2026-10-13').get()).data(),first);
 for(const period of ['daily','weekly','monthly','quarterly','halfYear','yearly']){
  const view=(await db.doc(`public_activity_index/${period}`).get()).data();
  assert.equal(view.latest,first.close);assert.equal(view.source,'royal-clean');
  assert.equal(view.bins.at(-1).online,undefined);assert.equal(view.bins.at(-1).eligible,undefined);
 }
 await service.tick({now:now+60000});await service.tick({now});
 assert.equal((await db.doc('public_activity_index/daily').get()).data().generatedAt,now+60000);
 const minutes=await db.collection('public_activity_candles/m1/candles').orderBy('start').get();
 assert.equal(minutes.size,2);assert.equal(minutes.docs[1].data().activityOpen,minutes.docs[0].data().activityClose);
 const five=(await db.collection('public_activity_candles/m5/candles').get()).docs[0].data();
 assert.equal(five.observed,2);assert.equal(five.volume,2/1440);
 assert.equal((await db.doc('public_activity_index/m1').get()).data().bins.length,2);
 for(const id of ['index-active','index-away','index-deleted'])await db.doc(`app_contact_profiles/${id}`).delete();
 for(const id of ['device-one','device-two'])await db.doc(`app_contact_presence/${id}`).delete();
});
