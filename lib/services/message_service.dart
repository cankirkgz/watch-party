import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:watchparty/models/message_model.dart';

class MessageService {
  MessageService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Map<String, DateTime> _lastRead = {};

  Stream<Map<String, DateTime>> readReceiptsStream(String roomId) => _firestore
      .collection('rooms')
      .doc(roomId)
      .collection('readReceipts')
      .snapshots()
      .map((snapshot) => {
            for (final doc in snapshot.docs)
              if (doc.data()['readThrough'] is Timestamp)
                doc.id: (doc.data()['readThrough'] as Timestamp).toDate(),
          });

  Future<void> markRead(
      String roomId, String userId, MessageModel message) async {
    if (message.id.isEmpty ||
        message.hasPendingWrites ||
        !message.hasServerTimestamp ||
        message.senderId == userId) {
      return;
    }
    final key = '$roomId/$userId';
    if (_lastRead[key] != null && !_lastRead[key]!.isBefore(message.sentAt)) {
      return;
    }
    _lastRead[key] = message.sentAt;
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('readReceipts')
          .doc(userId)
          .set({
        'messageId': message.id,
        'readThrough': Timestamp.fromDate(message.sentAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (_lastRead[key] == message.sentAt) _lastRead.remove(key);
      rethrow;
    }
  }

  Future<void> react(
          String roomId, String messageId, String userId, String? emoji) =>
      _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .update({'reactions.$userId': emoji ?? FieldValue.delete()});

  Future<void> sendMessage(MessageModel message) async {
    final data = message.toMap()..['sentAt'] = FieldValue.serverTimestamp();
    await _firestore
        .collection('rooms')
        .doc(message.roomId)
        .collection('messages')
        .add(data);
  }

  Stream<List<MessageModel>> getMessagesStream(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(200)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromMap(
                  {...doc.data(), 'roomId': roomId},
                  id: doc.id, hasPendingWrites: doc.metadata.hasPendingWrites))
              .toList(),
        );
  }
}
