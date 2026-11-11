import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { lyricsRevision, readLyrics } from '../src/lyrics.js';

// Use the local Firestore emulator even when production credentials are present.
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
const app = initializeApp({ projectId: 'watch-party-d4610' });
try {
  const db = getFirestore(app);
  const videoId = 'XTdU5RSodZ4';
  const data = {
    enabled: true,
    language: 'tr',
    cues: [
      { startMs: 0, endMs: 8000, text: 'Deneme altyazısı: başlangıç.' },
      { startMs: 15000, endMs: 40000, text: 'Deneme altyazısı: ileri sarma.' },
    ],
  };
  const lyrics = readLyrics(data);
  const revision = lyricsRevision(lyrics, 'ru', 'gpt-4.1-mini');
  const translations = ['Проверка субтитров: начало.', 'Проверка субтитров: перемотка.'];
  const batch = db.batch();
  batch.set(db.doc(`_songLyrics/${videoId}`), data);
  batch.set(db.doc(`_songSubtitles/${videoId}/translations/${revision}`), {
    cues: lyrics.cues.map((cue, index) => ({ ...cue, text: translations[index] })),
  });
  await batch.commit();
  console.log('Seeded local subtitle fixtures.');
} finally {
  await deleteApp(app);
}
