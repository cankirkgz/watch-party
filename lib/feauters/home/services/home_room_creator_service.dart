import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:watchparty/models/room_model.dart';
import 'package:watchparty/services/firestore_service.dart';
import 'package:watchparty/services/video_info_service.dart';

String generateRoomCode({int length = 6}) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}

class HomeRoomCreatorService {
  const HomeRoomCreatorService({required this.firestoreService});

  final FirestoreService firestoreService;

  Future<String> createRoom({
    required String videoId,
    required String createdBy,
    required List<String> participants,
  }) async {
    final title = await VideoInfoService().title(videoId);
    for (var attempt = 0; attempt < 12; attempt++) {
      final roomId = generateRoomCode();
      final reference =
          firestoreService.firestore.collection('rooms').doc(roomId);
      try {
        await firestoreService.firestore.runTransaction((transaction) async {
          final existing = await transaction.get(reference);
          if (existing.exists) throw StateError('room-code-collision');
          final room = RoomModel(
            id: roomId,
            videoId: videoId,
            createdAt: DateTime.now(),
            isPlaying: false,
            currentTime: 0,
            createdBy: createdBy,
            participants: participants,
            videoTitle: title,
          );
          transaction.set(reference, {
            ...room.toMap(),
            'lastUpdatedAt': FieldValue.serverTimestamp(),
            'updatedBy': createdBy,
            'syncEventId': 'initial',
          });
        });
        return roomId;
      } on StateError {
        continue;
      }
    }
    throw StateError('Benzersiz oda kodu üretilemedi.');
  }

  Future<RoomModel?> getRoomById(String roomId) async {
    final normalized = roomId.trim().toUpperCase();
    final doc = await firestoreService.getDocument(
      collection: 'rooms',
      docId: normalized,
    );
    final data = doc.data();
    return !doc.exists || data == null
        ? null
        : RoomModel.fromMap(normalized, data);
  }
}
