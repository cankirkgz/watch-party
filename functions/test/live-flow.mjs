import { readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { randomBytes } from 'node:crypto';
import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, signInAnonymously, connectAuthEmulator, deleteUser } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator, doc, setDoc, updateDoc, getDoc, addDoc, collection, arrayUnion, serverTimestamp, onSnapshot } from 'firebase/firestore';
import { getStorage, connectStorageEmulator, ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { getFunctions, connectFunctionsEmulator, httpsCallable } from 'firebase/functions';

const emulator = process.argv.includes('--emulator');
const serve = process.argv.includes('--serve');
const raw = readFileSync(new URL('../../lib/firebase_options.dart',import.meta.url),'utf8').split('static const FirebaseOptions web =')[1].split('static const FirebaseOptions android =')[0];
const config = Object.fromEntries(['apiKey','appId','messagingSenderId','projectId','storageBucket','authDomain'].map(k=>[k,raw.match(new RegExp(k+": '([^']+)'"))?.[1]]));
const clients = [];
const roomId = 'QA'+randomBytes(2).toString('hex').toUpperCase();
const report = {mode:emulator?'emulator':'production',roomId};
let heartbeat;
try {
  for (const [name,country,language] of [['Can · QA','TR','tr'],['Anastasia · QA','RU','ru']]) {
    const app=initializeApp(config,'qa-'+country+'-'+Date.now());
    const auth=getAuth(app), db=getFirestore(app), storage=getStorage(app), functions=getFunctions(app,'europe-west1');
    if(emulator){connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});connectFirestoreEmulator(db,'127.0.0.1',8080);connectStorageEmulator(storage,'127.0.0.1',9199);connectFunctionsEmulator(functions,'127.0.0.1',5001);}
    const {user}=await signInAnonymously(auth);
    const profile={id:user.uid,name,countryCode:country,preferredLanguage:language,translationLanguage:language,autoTranslate:false,createdAt:serverTimestamp()};
    await setDoc(doc(db,'users',user.uid),profile);
    clients.push({app,auth,db,storage,functions,user,profile});
  }
  report.auth=true;
  const [a,b]=clients;
  await setDoc(doc(a.db,'rooms',roomId),{videoId:'M7lc1UVf-VE',videoTitle:'YouTube Player API · birlikte test',createdAt:serverTimestamp(),createdBy:a.user.uid,participants:[a.user.uid],currentTime:0,isPlaying:false,lastUpdatedAt:serverTimestamp(),updatedBy:a.user.uid,syncEventId:'qa-initial',queue:[]});
  await updateDoc(doc(b.db,'rooms',roomId),{participants:arrayUnion(b.user.uid)});
  const pausedObserved=new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('sync-timeout')),10000);const stop=onSnapshot(doc(a.db,'rooms',roomId),s=>{if(s.data()?.syncEventId==='qa-pause'){clearTimeout(timer);stop();resolve(s.data());}},reject);});
  await updateDoc(doc(b.db,'rooms',roomId),{isPlaying:false,currentTime:36,syncEventId:'qa-pause',lastUpdatedAt:serverTimestamp(),updatedBy:b.user.uid});
  report.firestore=(await pausedObserved).currentTime===36;
  const message={senderId:b.user.uid,senderName:b.profile.name,senderCountry:'RU',text:'Этот момент просто невероятный 😂',type:'text',roomId,sentAt:serverTimestamp(),reactions:{},languageCode:'ru',videoSeconds:36};
  const messageRef=await addDoc(collection(b.db,'rooms',roomId,'messages'),message);
  try {
    const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==','base64');
    const media=ref(b.storage,`room_media/${roomId}/${b.user.uid}/qa-photo.png`);
    await uploadBytes(media,png,{contentType:'image/png'});
    const url=await getDownloadURL(media);
    await addDoc(collection(b.db,'rooms',roomId,'messages'),{...message,text:'',type:'image',mediaUrl:url});
    report.media=true;
  } catch(e) {report.media={code:e.code ?? null};}
  try {
    const translate=httpsCallable(a.functions,'translateMessage');
    const result=await translate({roomId,messageId:messageRef.id,targetLanguage:'tr'});
    const cached=await translate({roomId,messageId:messageRef.id,targetLanguage:'tr'});
    report.gpt={text:result.data.text,cached:cached.data.cached===true};
  } catch(e) {report.gpt={code:e.code ?? null};}
  async function beat(){for(const c of clients) await setDoc(doc(c.db,'rooms',roomId,'presence',c.user.uid),{userId:c.user.uid,name:c.profile.name,countryCode:c.profile.countryCode,languageCode:c.profile.preferredLanguage,active:true,lastSeenAt:serverTimestamp()});}
  await beat();
  console.log(JSON.stringify(report));
  if(serve){
    heartbeat=setInterval(()=>beat().catch(()=>{}),25000);
    createServer(async(req,res)=>{
      try {
        const url=new URL(req.url,'http://localhost');
        if(url.pathname==='/state'){res.end(JSON.stringify((await getDoc(doc(a.db,'rooms',roomId))).data()));return;}
        if(['/play','/pause','/seek'].includes(url.pathname)) await updateDoc(doc(b.db,'rooms',roomId),{isPlaying:url.pathname==='/play',currentTime:Number(url.searchParams.get('t')??36),lastUpdatedAt:serverTimestamp(),updatedBy:b.user.uid,syncEventId:'qa-'+Date.now()});
        if(url.pathname==='/message') await addDoc(collection(b.db,'rooms',roomId,'messages'),{...message,text:url.searchParams.get('text')??message.text,sentAt:serverTimestamp()});
        res.end(JSON.stringify({ok:true,roomId}));
      } catch(e){res.statusCode=500;res.end(JSON.stringify({code:e.code??e.message}));}
    }).listen(4377,'127.0.0.1',()=>console.log('QA control: http://127.0.0.1:4377'));
  } else {
    for(const c of clients){await deleteUser(c.user).catch(()=>{});await deleteApp(c.app);}
  }
} catch(e) {console.log(JSON.stringify({...report,ok:false,code:e.code??e.message}));process.exitCode=1;for(const c of clients)await deleteApp(c.app).catch(()=>{});}
