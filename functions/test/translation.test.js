import { test } from 'node:test';
import assert from 'node:assert/strict';
import { consumeRateWindow, messageTranslationKey, validateTranslationRequest } from '../src/translation.js';

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

test('keeps existing translation keys and uses a separate key for edited text', () => {
  const key = (text, editedAt) => messageTranslationKey('message', 'tr', {text, editedAt});
  assert.equal(key('Original'), 'message_tr');
  assert.notEqual(key('First edit', 1), key('Original'));
  assert.notEqual(key('First edit', 1), key('Second edit', 2));
  assert.equal(key('First edit', 1), key('First edit', 3));
});
