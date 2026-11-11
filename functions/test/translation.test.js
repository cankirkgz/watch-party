import { test } from 'node:test';
import assert from 'node:assert/strict';
import { consumeRateWindow, validateTranslationRequest } from '../src/translation.js';

test('rejects path traversal and unsupported translation targets before reads or API calls', () => {
  for (const data of [{roomId:'../users',messageId:'x',targetLanguage:'tr'}, {roomId:'ABC234',messageId:'../x',targetLanguage:'tr'}, {roomId:'ABC234',messageId:'x',targetLanguage:'invalid'}, null]) assert.throws(() => validateTranslationRequest(data), /invalid-argument/);
});
test('accepts real Firestore message identifiers and Russian-to-Turkish target', () => {
  assert.deepEqual(validateTranslationRequest({roomId:'ABC234',messageId:'_msg-123',targetLanguage:'tr'}), {roomId:'ABC234',messageId:'_msg-123',targetLanguage:'tr'});
});
test('limits a burst, then permits translation in a new minute', () => {
  let rate;
  for (let i=0; i<30; i++) rate = consumeRateWindow(rate, 1000);
  assert.throws(() => consumeRateWindow(rate, 2000), /resource-exhausted/);
  assert.deepEqual(consumeRateWindow(rate, 61000), {startedAt:61000,count:1});
});
