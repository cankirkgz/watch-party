const labels = {
  tr: ['İzleme odanda yeni mesaj', 'Sohbeti açmak için dokun.'],
  en: ['New message in your watch room', 'Tap to open the chat.'],
  ru: ['Новое сообщение в комнате', 'Нажмите, чтобы открыть чат.'],
  de: ['Neue Nachricht in deinem Raum', 'Zum Chat tippen.'],
  es: ['Nuevo mensaje en tu sala', 'Toca para abrir el chat.'],
};

export async function notifyRoomChat(snapshot, messaging, now = Date.now()) {
  const room = snapshot.ref.parent.parent;
  const message = snapshot.data();
  if (!message || !room || now - snapshot.createTime.toMillis() > 120_000) return 0;
  const members = (await room.get()).data()?.participants;
  if (!Array.isArray(members) || typeof message.senderId !== 'string') return 0;
  const recipients = [...new Set(members)].filter(id => id !== message.senderId);
  const subscriptions = await Promise.all(recipients.map(id =>
    room.collection('notificationMembers').doc(id).collection('devices').get()));
  const distinct = [...new Map(subscriptions.flatMap(result =>
    result.docs.map(doc => [doc.data().token, doc]))).values()];
  const event = `${room.id}-${snapshot.id}`;
  let delivered = 0;
  for (let i = 0; i < distinct.length; i += 500) {
    const batch = distinct.slice(i, i + 500);
    const payloads = batch.map(doc => {
      const { token, language, userId } = doc.data();
      const [title, body] = Object.hasOwn(labels, language) ? labels[language] : labels.en;
      return {
        token,
        notification: { title, body },
        data: { type: 'room_chat', roomId: room.id, recipientId: userId },
        android: { priority: 'high', ttl: 120_000,
          notification: { tag: event, sound: 'default' } },
        apns: { headers: { 'apns-collapse-id': event.slice(0, 64),
          'apns-expiration': String(Math.floor(now / 1000) + 120) },
          payload: { aps: { sound: 'default' } } },
      };
    });
    const result = await messaging.sendEach(payloads);
    delivered += result.successCount;
    await Promise.all(result.responses.map(async (response, index) => {
      if (response.error?.code === 'messaging/registration-token-not-registered') {
        const doc = batch[index];
        await doc.ref.delete({ lastUpdateTime: doc.updateTime })
          .catch(error => { if (![5, 9].includes(error.code)) throw error; });
      } else if (response.error) {
        console.warn('Room notification failed', { code: response.error.code });
      }
    }));
  }
  return delivered;
}
