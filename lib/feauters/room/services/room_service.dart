import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:watchparty/models/room_model.dart';
import 'package:watchparty/services/firestore_service.dart';

class RoomService {
  final FirestoreService _fs;
  const RoomService(this._fs);

  Stream<RoomModel> roomStream(String roomId) {
    return _fs
        .documentStream(collection: 'rooms', docId: roomId)
        .where((snap) => snap.exists)
        .map((snap) => RoomModel.fromMap(snap.id, snap.data()!));
  }

  /// 🔄 Bu metot hem durumu hem zamanı aynı anda günceller
  Future<void> setPlaybackState({
    required String roomId,
    required bool isPlaying,
    required double currentTime,
  }) async {
    await _fs.updateDocument(
      collection: 'rooms',
      docId: roomId,
      data: {
        'currentTime': currentTime,
        'isPlaying': isPlaying,
        // Burayı client zamanı yerine Firestore'un serverTimestamp()'ı ile değiştir
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> addParticipant(String roomId, String userId) async {
    await _fs.updateDocument(
      collection: 'rooms',
      docId: roomId,
      data: {
        'participants': FieldValue.arrayUnion([userId]),
      },
    );
  }

  Future<void> removeParticipant(String roomId, String userId) async {
    await _fs.updateDocument(
      collection: 'rooms',
      docId: roomId,
      data: {
        'participants': FieldValue.arrayRemove([userId]),
      },
    );
  }
}
