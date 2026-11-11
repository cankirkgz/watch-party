import test from 'node:test';
import assert from 'node:assert/strict';
import { TokenVerifier } from 'livekit-server-sdk';
import { validateVoiceRoomId, createVoiceToken } from '../src/voice.js';

test('voice tokens only admit a named member into one audio-only room', async () => {
  const config = { url: 'wss://qa.livekit.cloud', apiKey: 'test-key', apiSecret: 'test-secret-that-is-at-least-thirty-two-chars' };
  const result = await createVoiceToken(config, { roomId: 'QA2345', userId: 'member-one', name: 'Can' });
  const decoded = await new TokenVerifier(config.apiKey, config.apiSecret).verify(result.token);
  assert.equal(decoded.sub, 'member-one');
  assert.equal(decoded.name, 'Can');
  assert.equal(decoded.video.room, 'watchparty-QA2345');
  assert.equal(decoded.video.roomJoin, true);
  assert.equal(decoded.video.canPublishData, false);
  assert.deepEqual(decoded.video.canPublishSources, ['microphone']);
  assert.equal(decoded.video.roomAdmin, undefined);
  assert.equal(decoded.roomConfig.maxParticipants, 50);
  assert.equal(decoded.roomConfig.emptyTimeout, 60);
  assert.ok(decoded.exp - decoded.nbf <= 300);
});
test('voice tokens reject paths and invalid identifiers', () => {
  for (const value of ['../secret', 'QA2345/other', '', null, 123]) {
    assert.throws(() => validateVoiceRoomId(value));
  }
});
