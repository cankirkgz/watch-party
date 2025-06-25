import 'package:watchparty/models/room_model.dart';
import 'package:watchparty/services/firestore_service.dart';
import 'dart:math';

String generateRoomCode({int length = 6}) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random();
  return List.generate(length, (index) => chars[rand.nextInt(chars.length)])
      .join();
}

class HomeRoomCreatorService {
  final FirestoreService firestoreService;

  const HomeRoomCreatorService({required this.firestoreService});

  Future<String> createRoom({
    required String videoId,
    required String createdBy,
    required List<String> participants,
  }) async {
    final roomId = generateRoomCode();

    final room = RoomModel(
      id: roomId,
      videoId: videoId,
      createdAt: DateTime.now(),
      isPlaying: false,
      currentTime: 0,
      videoHour: 0,
      videoMinute: 0,
      videoSecond: 0,
      createdBy: createdBy,
      participants: participants,
    );

    await firestoreService.setDocument(
      collection: 'rooms',
      docId: roomId,
      data: room.toMap(),
    );

    return roomId;
  }

  Future<RoomModel?> getRoomById(String roomId) async {
    final doc = await firestoreService.getDocument(
      collection: 'rooms',
      docId: roomId,
    );

    if (doc == null || !doc.exists) return null;

    final data = doc.data();
    if (data == null) return null;

    return (RoomModel.fromMap(roomId, data));
  }

  Future<void> updateRoomCurrentTime({
    required String roomId,
    required double currentTime,
  }) async {
    final int totalSec = currentTime.toInt();
    final int hours = totalSec ~/ 3600;
    final int minutes = (totalSec % 3600) ~/ 60;
    final int seconds = totalSec % 60;

    await firestoreService.updateDocument(
      collection: 'rooms',
      docId: roomId,
      data: {
        'currentTime': currentTime,
        'videoHour': hours,
        'videoMinute': minutes,
        'videoSecond': seconds,
      },
    );
  }
}
