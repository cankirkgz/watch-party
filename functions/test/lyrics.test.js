import assert from 'node:assert/strict';
import test from 'node:test';
import { lyricsRevision, readLyrics, translateLyrics } from '../src/lyrics.js';

const tracks = [
  ['ru', ['Вместе смотрим на вечернее небо.', 'В окне горит свет.']],
  ['de', ['Gemeinsam schauen wir in den Abendhimmel.', 'Im Fenster brennt Licht.']],
  ['es', ['Miramos juntos el cielo al anochecer.', 'Hay luz en la ventana.']],
];
const lyrics = readLyrics({ enabled: true, language: 'tr', cues: [
  { startMs: 1800, endMs: 4200, text: 'Birlikte akşam göğüne bakıyoruz.' },
  { startMs: 5800, endMs: 8600, text: 'Pencerede ışık yanıyor.' },
] });

test('translates the whole lyric together and preserves each video timestamp', async () => {
  for (const [language, lines] of tracks) {
    const client = { responses: { create: async request => {
      assert.deepEqual(JSON.parse(request.input), lyrics.cues.map(cue => cue.text));
      assert.match(request.instructions, new RegExp(`into ${language}`));
      assert.equal(request.store, false);
      return { status: 'completed', output_text: JSON.stringify({ lines }) };
    } } };
    assert.deepEqual(await translateLyrics(client, 'model', lyrics, language),
      lyrics.cues.map((cue, i) => ({ ...cue, text: lines[i] })));
  }
  assert.deepEqual(await translateLyrics(null, 'model', lyrics, 'tr'), lyrics.cues);
});

test('rejects disabled sources, overlapping timings and incomplete translations', async () => {
  assert.equal(readLyrics({ ...lyrics, enabled: false }), null);
  assert.equal(readLyrics({ ...lyrics, enabled: true, cues: [lyrics.cues[0], lyrics.cues[0]] }), null);
  const client = { responses: { create: async () => ({
    status: 'completed', output_text: '{"lines":["Одна строка"]}',
  }) } };
  await assert.rejects(translateLyrics(client, 'model', lyrics, 'ru'), /invalid-translation-lines/);
  assert.notEqual(lyricsRevision(lyrics, 'ru', 'model'), lyricsRevision(lyrics, 'de', 'model'));
});
