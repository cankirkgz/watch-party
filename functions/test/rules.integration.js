import { before, after, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, getDoc, getDocs, collection, onSnapshot, arrayUnion, serverTimestamp } from 'firebase/firestore';
import { ref, uploadBytes, getBytes } from 'firebase/storage';

let env;
before(async () => { env = await initializeTestEnvironment({projectId:'demo-watchparty-rules',firestore:{rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')},storage:{rules:readFileSync(new URL('../../storage.rules',import.meta.url),'utf8')}}); });
after(async () => { await env?.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });
const room = () => ({videoId:'dQw4w9WgXcQ',videoTitle:'Test video',createdBy:'alice',participants:['alice'],currentTime:0,isPlaying:false,queue:[],lastUpdatedAt:serverTimestamp(),syncEventId:'initial'});
async function setup() {
  const alice = env.authenticatedContext('alice'); const bob = env.authenticatedContext('bob');
  await setDoc(doc(alice.firestore(),'rooms/ABC234'),room());
  await updateDoc(doc(bob.firestore(),'rooms/ABC234'),{participants:arrayUnion('bob')});
  return {alice,bob};
}
function observes(db, predicate) {
  return new Promise((resolve,reject) => { let stop; const timeout = setTimeout(() => {stop?.();reject(new Error('Room did not synchronise'));},5000); stop=onSnapshot(doc(db,'rooms/ABC234'),snapshot=>{if(predicate(snapshot.data())) {clearTimeout(timeout);stop?.();resolve(snapshot.data());}},reject); });
}

test('read cursor is visible to the sender, belongs to the reader, and cannot acknowledge future or forged messages', async () => {
  const {alice, bob} = await setup();
  const a = alice.firestore(), b = bob.firestore();
  const path = 'rooms/ABC234/messages/read-test';
  await setDoc(doc(a, path), {type:'text', text:'Hello', senderId:'alice', senderName:'Alice', sentAt:serverTimestamp(), reactions:{}});
  const sentAt = (await getDoc(doc(a, path))).data().sentAt;
  const receipt = {messageId:'read-test', readThrough:sentAt, updatedAt:serverTimestamp()};
  await assertSucceeds(setDoc(doc(b, 'rooms/ABC234/readReceipts/bob'), receipt));
  assert.equal((await getDoc(doc(a, 'rooms/ABC234/readReceipts/bob'))).data().messageId, 'read-test');
  await assertFails(setDoc(doc(b, 'rooms/ABC234/readReceipts/alice'), receipt));
  await assertFails(setDoc(doc(a, 'rooms/ABC234/readReceipts/alice'), receipt));
  await assertFails(setDoc(doc(b, 'rooms/ABC234/readReceipts/bob'), {...receipt, messageId:'missing'}));
  await assertFails(setDoc(doc(b, 'rooms/ABC234/readReceipts/bob'), {...receipt, readThrough:new Date(Date.now()+86400000)}));
  const outsider = env.authenticatedContext('outsider').firestore();
  await assertFails(getDocs(collection(outsider, 'rooms/ABC234/readReceipts')));
});
test('two authenticated clients observe shared play, pause and seek; a late join sees the current position', async () => {
  const {alice,bob}=await setup();
  const playing=observes(bob.firestore(),d=>d?.syncEventId==='play-1');
  await updateDoc(doc(alice.firestore(),'rooms/ABC234'),{isPlaying:true,currentTime:42,lastUpdatedAt:serverTimestamp(),updatedBy:'alice',syncEventId:'play-1'});
  assert.equal((await playing).isPlaying,true);
  const paused=observes(alice.firestore(),d=>d?.syncEventId==='pause-2');
  await updateDoc(doc(bob.firestore(),'rooms/ABC234'),{isPlaying:false,currentTime:45,lastUpdatedAt:serverTimestamp(),updatedBy:'bob',syncEventId:'pause-2'});
  assert.equal((await paused).currentTime,45);
  const sought=observes(alice.firestore(),d=>d?.syncEventId==='seek-3');
  await updateDoc(doc(bob.firestore(),'rooms/ABC234'),{currentTime:180,lastUpdatedAt:serverTimestamp(),updatedBy:'bob',syncEventId:'seek-3'});
  assert.equal((await sought).currentTime,180);
  const late=env.authenticatedContext('late').firestore();
  await updateDoc(doc(late,'rooms/ABC234'),{participants:arrayUnion('late')});
  assert.equal((await getDoc(doc(late,'rooms/ABC234'))).data().currentTime,180);
});
test('room membership cannot be forged, and non-members cannot read chat or control video', async () => {
  const {alice}=await setup(); const outsider=env.authenticatedContext('outsider').firestore();
  await assertFails(updateDoc(doc(outsider,'rooms/ABC234'),{isPlaying:true}));
  await assertFails(updateDoc(doc(outsider,'rooms/ABC234'),{participants:arrayUnion('victim')}));
  await assertFails(getDocs(collection(outsider,'rooms/ABC234/messages')));
  await assertFails(getDocs(collection(alice.firestore(),'rooms')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'rooms/ABC234')));
});
test('text, photos and audio preserve sender identity; reactions only alter the current user', async () => {
  const {alice,bob}=await setup();
  const message={senderId:'alice',senderName:'Can',senderCountry:'TR',text:'Привет, как дела?',type:'text',roomId:'ABC234',sentAt:serverTimestamp(),reactions:{},languageCode:'ru'};
  await assertSucceeds(setDoc(doc(alice.firestore(),'rooms/ABC234/messages/m1'),message));
  await assertFails(setDoc(doc(bob.firestore(),'rooms/ABC234/messages/fake'),message));
  await assertSucceeds(updateDoc(doc(bob.firestore(),'rooms/ABC234/messages/m1'),{'reactions.bob':'❤️'}));
  await assertSucceeds(updateDoc(doc(bob.firestore(),'rooms/ABC234/messages/m1'),{'reactions.bob':'🍿'}));
  await assertSucceeds(updateDoc(doc(bob.firestore(),'rooms/ABC234/messages/m1'),{'reactions.bob':'🥹'}));
  await assertFails(updateDoc(doc(bob.firestore(),'rooms/ABC234/messages/m1'),{'reactions.bob':'<script>'}));
  await assertFails(updateDoc(doc(bob.firestore(),'rooms/ABC234/messages/m1'),{'reactions.alice':'🔥'}));
  await assertFails(updateDoc(doc(bob.firestore(),'rooms/ABC234/messages/m1'),{text:'tampered'}));
  for(const type of ['image','audio']) await assertSucceeds(setDoc(doc(alice.firestore(),'rooms/ABC234/messages/'+type),{...message,text:'',type,mediaUrl:'https://example.test/media'}));
  await assertFails(setDoc(doc(alice.firestore(),'rooms/ABC234/messages/long'),{...message,text:'x'.repeat(2001)}));
});
test('the shared queue can change the video without losing room members', async () => {
  const {alice,bob}=await setup();
  await assertSucceeds(updateDoc(doc(bob.firestore(),'rooms/ABC234'),{queue:[{id:'q1',videoId:'M7lc1UVf-VE',title:'API example',addedBy:'bob'}]}));
  await assertSucceeds(updateDoc(doc(alice.firestore(),'rooms/ABC234'),{queue:[],videoId:'M7lc1UVf-VE',videoTitle:'API example',currentTime:0,isPlaying:true}));
  assert.deepEqual((await getDoc(doc(bob.firestore(),'rooms/ABC234'))).data().participants,['alice','bob']);
  await assertFails(updateDoc(doc(bob.firestore(),'rooms/ABC234'),{createdBy:'bob'}));
});
test('media storage accepts member photos/audio and rejects outsiders, path spoofing and executable content', async () => {
  const {alice,bob}=await setup(); const outsider=env.authenticatedContext('outsider');
  const bytes=new Uint8Array([137,80,78,71,13,10,26,10]);
  await assertSucceeds(uploadBytes(ref(alice.storage(),'room_media/ABC234/alice/photo.png'),bytes,{contentType:'image/png'}));
  await assertSucceeds(getBytes(ref(bob.storage(),'room_media/ABC234/alice/photo.png')));
  await assertFails(getBytes(ref(outsider.storage(),'room_media/ABC234/alice/photo.png')));
  await assertFails(uploadBytes(ref(bob.storage(),'room_media/ABC234/alice/fake.png'),bytes,{contentType:'image/png'}));
  await assertFails(uploadBytes(ref(alice.storage(),'room_media/ABC234/alice/script.html'),bytes,{contentType:'text/html'}));
  await assertSucceeds(uploadBytes(ref(bob.storage(),'room_media/ABC234/bob/voice.m4a'),bytes,{contentType:'audio/mp4'}));
});
