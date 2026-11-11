import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret, defineString } from 'firebase-functions/params';
import OpenAI from 'openai';
import { validateTranslationRequest, translationInstructions, consumeRateWindow, languages } from './translation.js';
import { validateVoiceRoomId, createVoiceToken } from './voice.js';
import { readLyrics, lyricsRevision, translateLyrics, videoIdPattern } from './lyrics.js';

initializeApp();
const db = getFirestore();
const apiKey = defineSecret('OPENAI_API_KEY');
const model = defineString('TRANSLATION_MODEL', { default: 'gpt-4.1-mini' });
const voiceConfig = defineSecret('LIVEKIT_CONFIG');
const pendingLyrics = new Map();

export const prepareSongSubtitles = onCall({
  region: 'europe-west1', invoker: 'public', secrets: [apiKey],
  timeoutSeconds: 25, memory: '256MiB', cpu: 1,
  concurrency: 8, minInstances: 0, maxInstances: 1,
}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const { roomId, videoId, targetLanguage } = request.data ?? {};
  if (typeof roomId !== 'string' || !/^[A-Z0-9]{6}$/.test(roomId) ||
      typeof videoId !== 'string' || !videoIdPattern.test(videoId) ||
      !languages.has(targetLanguage)) {
    throw new HttpsError('invalid-argument', 'Invalid subtitle request.');
  }
  const room = (await db.doc(`rooms/${roomId}`).get()).data();
  if (!room?.participants?.includes(request.auth.uid)) {
    throw new HttpsError('permission-denied', 'Join the room first.');
  }
  if (room.videoId !== videoId) return { cues: [] };
  const source = readLyrics((await db.doc(`_songLyrics/${videoId}`).get()).data());
  if (!source) return { cues: [] };
  if (source.language === targetLanguage) return { cues: source.cues };

  const modelName = model.value();
  const revision = lyricsRevision(source, targetLanguage, modelName);
  const ref = db.doc(`_songSubtitles/${videoId}/translations/${revision}`);
  const cached = await ref.get();
  if (cached.exists) return { cues: cached.data().cues };
  const key = ref.path;
  let work = pendingLyrics.get(key);
  if (!work) {
    work = (async () => {
      await db.runTransaction(async transaction => {
        const limit = db.doc(`_songSubtitleLimits/${request.auth.uid}`);
        const previous = (await transaction.get(limit)).data();
        const now = Date.now();
        const recent = previous && now - previous.startedAt < 60_000;
        const count = recent ? previous.count : 0;
        if (count >= 5) throw new HttpsError('resource-exhausted', 'Please wait before translating another song.');
        transaction.set(limit, { startedAt: recent ? previous.startedAt : now, count: count + 1 });
      });
      const client = new OpenAI({ apiKey: apiKey.value(), timeout: 17_000, maxRetries: 0 });
      const cues = await translateLyrics(client, modelName, source, targetLanguage);
      await ref.set({ cues, targetLanguage, createdAt: FieldValue.serverTimestamp() });
      return cues;
    })().finally(() => pendingLyrics.delete(key));
    pendingLyrics.set(key, work);
  }
  try {
    return { cues: await work };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError('unavailable', 'Subtitles are temporarily unavailable.');
  }
});

export const joinVoiceRoom = onCall({
  region: 'europe-west1', invoker: 'public', secrets: [voiceConfig],
  timeoutSeconds: 15, memory: '256MiB', cpu: 'gcf_gen1',
  concurrency: 1, minInstances: 0, maxInstances: 1,
}, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  let roomId;
  try { roomId = validateVoiceRoomId(request.data?.roomId); }
  catch { throw new HttpsError('invalid-argument', 'Invalid room.'); }
  const [room, profile] = await Promise.all([
    db.doc(`rooms/${roomId}`).get(), db.doc(`users/${request.auth.uid}`).get(),
  ]);
  if (!room.exists || !room.data().participants?.includes(request.auth.uid)) {
    throw new HttpsError('permission-denied', 'Join the watch room first.');
  }
  await db.runTransaction(async (transaction) => {
    const ref = db.doc(`_voiceLimits/${request.auth.uid}`);
    const previous = (await transaction.get(ref)).data();
    const now = Date.now();
    const recent = previous && now - previous.windowStart < 60000;
    const count = recent ? previous.count : 0;
    if (count >= 10) throw new HttpsError('resource-exhausted', 'Please wait before reconnecting.');
    transaction.set(ref, { windowStart: recent ? previous.windowStart : now, count: count + 1 });
  });
  try {
    return await createVoiceToken(JSON.parse(voiceConfig.value()), {
      roomId, userId: request.auth.uid, name: profile.data()?.name || request.auth.token.name,
    });
  } catch {
    throw new HttpsError('unavailable', 'Voice chat is temporarily unavailable.');
  }
});

export const translateMessage = onCall({ region: 'europe-west1', invoker: 'public', secrets: [apiKey], timeoutSeconds: 30, memory: '256MiB', cpu: 'gcf_gen1', concurrency: 1, minInstances: 0, maxInstances: 1 }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in to translate.');
  let input;
  try { input = validateTranslationRequest(request.data); }
  catch { throw new HttpsError('invalid-argument', 'Invalid translation request.'); }
  const { roomId, messageId, targetLanguage } = input;
  const room = db.doc(`rooms/${roomId}`);
  const [roomSnapshot, messageSnapshot] = await Promise.all([room.get(), room.collection('messages').doc(messageId).get()]);
  if (!roomSnapshot.exists || !roomSnapshot.data().participants?.includes(request.auth.uid)) throw new HttpsError('permission-denied', 'Join the room first.');
  const message = messageSnapshot.data();
  if (!message || (message.type ?? 'text') !== 'text' || typeof message.text !== 'string' || !message.text.trim() || message.text.length > 2000) throw new HttpsError('invalid-argument', 'Only text messages up to 2000 characters can be translated.');
  const cachedRef = room.collection('_translations').doc(`${messageId}_${targetLanguage}`);
  const cached = await cachedRef.get();
  if (cached.exists) return { text: cached.data().text, provider: 'GPT', cached: true };
  try {
    await db.runTransaction(async (transaction) => {
      const ref = db.doc(`_translationLimits/${request.auth.uid}`);
      const previous = await transaction.get(ref);
      transaction.set(ref, consumeRateWindow(previous.data(), Date.now()));
    });
  } catch (e) {
    if (e.message === 'resource-exhausted') throw new HttpsError('resource-exhausted', 'Please wait a minute before translating again.');
    throw new HttpsError('unavailable', 'Translation is temporarily unavailable.');
  }
  try {
    const client = new OpenAI({ apiKey: apiKey.value(), timeout: 23000, maxRetries: 0 });
    const response = await client.responses.create({ model: model.value(), instructions: translationInstructions(targetLanguage), input: message.text, max_output_tokens: 1600, store: false });
    const text = response.output_text?.trim();
    if (!text || response.status !== 'completed') throw new Error('empty-translation');
    await cachedRef.set({ text, targetLanguage, createdAt: FieldValue.serverTimestamp() });
    return { text, provider: 'GPT', cached: false };
  } catch (e) {
    console.warn('Translation request failed', { status: e.status ?? null, code: e.code ?? 'translation-failed' });
    throw new HttpsError(e.status === 429 ? 'resource-exhausted' : 'unavailable', 'GPT translation is temporarily unavailable. Try device translation or retry later.');
  }
});
