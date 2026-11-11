import { AccessToken, RoomConfiguration, TrackSource } from 'livekit-server-sdk';

export function validateVoiceRoomId(value) {
  if (typeof value !== 'string' || !/^[A-Z0-9]{6}$/.test(value)) {
    throw new Error('invalid-room');
  }
  return value;
}

export async function createVoiceToken(config, { roomId, userId, name }) {
  if (!/^wss:\/\/[a-z0-9.-]+\.livekit\.cloud\/?$/.test(config.url) ||
      !config.apiKey || !config.apiSecret) throw new Error('invalid-voice-config');
  const token = new AccessToken(config.apiKey, config.apiSecret, {
    identity: userId, name: String(name || 'Guest').slice(0, 60), ttl: 300,
  });
  token.addGrant({
    room: `watchparty-${validateVoiceRoomId(roomId)}`, roomJoin: true,
    canSubscribe: true, canPublish: true,
    canPublishSources: [TrackSource.MICROPHONE],
    canPublishData: false, canUpdateOwnMetadata: false,
  });
  token.roomConfig = new RoomConfiguration({
    emptyTimeout: 60, departureTimeout: 20, maxParticipants: 50,
  });
  return { url: config.url, token: await token.toJwt() };
}
