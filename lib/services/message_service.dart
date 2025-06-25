import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:watchparty/models/message_model.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendMessage(MessageModel message) async {
    await _firestore
        .collection('rooms')
        .doc(message.roomId)
        .collection('messages')
        .add(message.toMap());
  }

  Stream<List<MessageModel>> getMessagesStream(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                MessageModel.fromMap(doc.data() as Map<String, dynamic>))
            .toList());
  }
}
