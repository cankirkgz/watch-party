import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, signInAnonymously, deleteUser } from 'firebase/auth';
import { getFirestore, doc, setDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';
import { getFunctions, httpsCallable } from 'firebase/functions';

assert.ok(process.argv.includes('--live'), 'Pass --live to test the production function.');
const catalog = JSON.parse(await readFile(new URL('../../catalog/traditional-tr.json', import.meta.url), 'utf8'));
const raw = (await readFile(new URL('../../lib/firebase_options.dart', import.meta.url), 'utf8'))
  .split('static const FirebaseOptions web =')[1].split('static const FirebaseOptions android =')[0];
const config = Object.fromEntries(['apiKey', 'appId', 'messagingSenderId', 'projectId', 'authDomain']
  .map(key => [key, raw.match(new RegExp(`${key}: '([^']+)'`))?.[1]]));
assert.equal(config.projectId, 'watch-party-d4610');

const app = initializeApp(config);
try {
  const { user } = await signInAnonymously(getAuth(app));
  try {
    const db = getFirestore(app);
    const prepare = httpsCallable(getFunctions(app, 'europe-west1'), 'prepareSongSubtitles', { timeout: 30_000 });
    for (const song of catalog) {
      const roomId = 'QA' + randomBytes(2).toString('hex').toUpperCase();
      const room = doc(db, 'rooms', roomId);
      const videoId = new URL(song.provenance.recording).searchParams.get('v');
      assert.equal(videoId, song.videoId);
      await setDoc(room, {
        videoId, videoTitle: song.title, createdBy: user.uid, participants: [user.uid],
        currentTime: 0, isPlaying: false, createdAt: serverTimestamp(),
        lastUpdatedAt: serverTimestamp(), syncEventId: 'qa-subtitles', queue: [],
      });
      try {
        const request = { roomId, videoId, targetLanguage: 'ru' };
        const started = performance.now();
        const { data: { cues } } = await prepare(request);
        const elapsed = Math.round(performance.now() - started);
        assert.deepEqual(cues.map(({startMs, endMs}) => ({startMs, endMs})),
          song.cues.map(({startMs, endMs}) => ({startMs, endMs})));
        assert.ok(cues.every(cue => /[А-Яа-яЁё]/u.test(cue.text)));
        assert.deepEqual((await prepare(request)).data.cues, cues);
        console.log(`PASS ${videoId}: ${cues.length} Russian cues, ${elapsed} ms first response`);
      } finally {
        await deleteDoc(room);
      }
    }
  } finally {
    await deleteUser(user);
  }
} finally {
  await deleteApp(app);
}
