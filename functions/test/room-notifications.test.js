import assert from 'node:assert/strict';
import test from 'node:test';
import { notifyRoomChat } from '../src/room-notifications.js';

test('room messages notify other members without including private chat text', async () => {
  const now = 1710000000000;
  const fetched = [];
  const removed = [];
  const expired = {
    data: () => ({ userId: 'bob', token: 'old-token', language: 'ru' }),
    ref: { delete: async condition => removed.push(condition.lastUpdateTime) },
    updateTime: 'old-version',
  };
  const phone = { data: () => ({ userId: 'bob', token: 'current-token', language: 'ru' }) };
  const room = {
    id: 'ABC234',
    get: async () => ({ data: () => ({ participants: ['alice', 'bob', 'bob'] }) }),
    collection: name => {
      assert.equal(name, 'notificationMembers');
      return { doc: id => {
        fetched.push(id);
        return { collection: path => {
          assert.equal(path, 'devices');
          return { get: async () => ({ docs: [expired, phone, phone] }) };
        } };
      } };
    },
  };
  const message = {
    id: 'message123',
    createTime: { toMillis: () => now },
    ref: { parent: { parent: room } },
    data: () => ({ senderId: 'alice', text: 'Private message' }),
  };
  const messaging = { sendEach: async payloads => {
    assert.equal(payloads.length, 2);
    assert.equal(payloads[1].notification.title, 'Новое сообщение в комнате');
    assert.deepEqual(payloads[1].data,
      { type: 'room_chat', roomId: 'ABC234', recipientId: 'bob' });
    assert.ok(!JSON.stringify(payloads).includes('Private message'));
    return { successCount: 1, responses: [
      { error: { code: 'messaging/registration-token-not-registered' } }, {},
    ] };
  } };
  assert.equal(await notifyRoomChat(message, messaging, now), 1);
  assert.deepEqual(fetched, ['bob']);
  assert.deepEqual(removed, ['old-version']);
  assert.equal(await notifyRoomChat(message, messaging, now + 121_000), 0);
  assert.deepEqual(fetched, ['bob']);
});
