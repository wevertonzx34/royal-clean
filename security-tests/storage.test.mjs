import {readFileSync} from 'node:fs';
import {before,after,test} from 'node:test';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc} from 'firebase/firestore';
import {ref,uploadBytes,getMetadata,listAll,deleteObject} from 'firebase/storage';
if(process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8185' || process.env.FIREBASE_STORAGE_EMULATOR_HOST !== '127.0.0.1:9299') throw Error('Local emulators required');
let env;
const context=(uid,verified=true)=>env.authenticatedContext(uid,{email:`${uid}@example.test`,email_verified:verified});
const image=(uid,ctx=context(uid))=>ref(ctx.storage(),'profile_media/'+uid+'/photo.png');
before(async()=>{
  env=await initializeTestEnvironment({projectId:'demo-royal-clean',firestore:{host:'127.0.0.1',port:8185,rules:readFileSync(new URL('../firestore.rules',import.meta.url),'utf8')},storage:{host:'127.0.0.1',port:9299,rules:readFileSync(new URL('../storage.rules',import.meta.url),'utf8')}});
  await env.withSecurityRulesDisabled(async ctx=>{
    for(const uid of ['photo-owner','photo-other','photo-unverified','photo-disabled']) await setDoc(doc(ctx.firestore(),'users',uid),{active:uid!=='photo-disabled',role:'consumer'});
    await setDoc(doc(ctx.firestore(),'admin/photo-admin'),{ativo:true,eAdministrador:true,email:'photo-admin@example.test'});
  });
});
after(async()=>env?.cleanup());
test('private media: verified active owner only, including administrators',async()=>{
  const bytes=new Uint8Array([137,80,78,71]);
  await assertSucceeds(uploadBytes(image('photo-owner'),bytes,{contentType:'image/png'}));
  await assertSucceeds(getMetadata(image('photo-owner')));
  await assertSucceeds(uploadBytes(image('photo-admin'),bytes,{contentType:'image/png'}));
  for(const ctx of [context('photo-other'),env.unauthenticatedContext()]) {
    await assertFails(getMetadata(image('photo-owner',ctx)));
    await assertFails(uploadBytes(image('photo-owner',ctx),bytes,{contentType:'image/png'}));
  }
  await assertFails(uploadBytes(image('photo-unverified',context('photo-unverified',false)),bytes,{contentType:'image/png'}));
  await assertFails(uploadBytes(image('photo-disabled'),bytes,{contentType:'image/png'}));
  await assertFails(listAll(ref(context('photo-owner').storage(),'profile_media/photo-owner')));
  await assertSucceeds(deleteObject(image('photo-owner')));
});
test('private media: only expected image paths, PNG metadata and bounded size',async()=>{
  const ctx=context('photo-owner');
  await assertFails(uploadBytes(ref(ctx.storage(),'profile_media/photo-owner/arbitrary.png'),new Uint8Array(4),{contentType:'image/png'}));
  await assertFails(uploadBytes(image('photo-owner'),new Uint8Array(4),{contentType:'text/html'}));
  await assertFails(uploadBytes(image('photo-owner'),new Uint8Array(2*1024*1024+1),{contentType:'image/png'}));
});
