import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:watchparty/models/room_model.dart';
import 'package:watchparty/models/user_model.dart';
import 'package:watchparty/services/firestore_service.dart';
import 'package:watchparty/services/video_info_service.dart';

class RoomService {
  const RoomService(this._firestore);
  final FirestoreService _firestore;
  DocumentReference<Map<String, dynamic>> _room(String id) =>
      _firestore.firestore.collection('rooms').doc(id);

  Stream<RoomModel> roomStream(String id) => _room(id)
      .snapshots(includeMetadataChanges: true)
      .where((s) => s.exists)
      .map((s) => RoomModel.fromMap(s.id, s.data()!,
          isFromCache: s.metadata.isFromCache,
          hasPendingWrites: s.metadata.hasPendingWrites));
  Future<RoomModel?> getRoom(String id) async {
    final s = await _room(id).get();
    return s.exists ? RoomModel.fromMap(id, s.data()!) : null;
  }

  Future<void> setPlaybackState(
          {required String roomId,
          required bool isPlaying,
          required double currentTime,
          required String updatedBy,
          required String syncEventId}) =>
      _room(roomId).update({
        'isPlaying': isPlaying,
        'currentTime': currentTime.clamp(0, 864000),
        'updatedBy': updatedBy,
        'syncEventId': syncEventId,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> addParticipant(String roomId, String userId) =>
      _room(roomId).update({
        'participants': FieldValue.arrayUnion([userId])
      });
  Future<void> heartbeat(String roomId, UserModel profile,
          {bool active = true, String? subtitlesReadyFor}) =>
      _room(roomId).collection('presence').doc(profile.id).set({
        'userId': profile.id,
        'name': profile.name,
        'countryCode': profile.countryCode,
        'languageCode': profile.preferredLanguage,
        'active': active,
        'lastSeenAt': FieldValue.serverTimestamp(),
        if (subtitlesReadyFor != null) 'subtitlesReadyFor': subtitlesReadyFor,
      }, SetOptions(merge: true));
  Future<void> removeParticipant(String roomId, String userId) async {
    final batch = _firestore.firestore.batch();
    batch.delete(_room(roomId).collection('presence').doc(userId));
    batch.update(_room(roomId), {
      'participants': FieldValue.arrayRemove([userId])
    });
    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> presenceStream(String roomId,
          {bool serverOnly = false}) =>
      _room(roomId)
          .collection('presence')
          .where('active', isEqualTo: true)
          .snapshots(includeMetadataChanges: serverOnly)
          .where((snapshot) => !serverOnly || !snapshot.metadata.isFromCache)
          .map(
              (s) => s.docs.map((d) => {...d.data(), 'userId': d.id}).toList());
  Stream<int> participantCountStream(String roomId) =>
      presenceStream(roomId).map((p) => p.length);

  Future<void> addToQueue(String roomId, String videoId, String userId) async {
    final title = await VideoInfoService().title(videoId);
    await _firestore.firestore.runTransaction((tx) async {
      final snap = await tx.get(_room(roomId));
      final queue = List<Map<String, dynamic>>.from(
          (snap.data()?['queue'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e)));
      if (queue.length >= 30) throw StateError('queue-full');
      queue.add({
        'id': const Uuid().v4(),
        'videoId': videoId,
        'title': title,
        'addedBy': userId
      });
      tx.update(_room(roomId), {'queue': queue});
    });
  }

  Future<void> removeFromQueue(String roomId, String itemId) =>
      _firestore.firestore.runTransaction((tx) async {
        final s = await tx.get(_room(roomId));
        final queue = (s.data()?['queue'] as List? ?? [])
            .where((e) => e['id'] != itemId)
            .toList();
        tx.update(_room(roomId), {'queue': queue});
      });

  Future<void> startPreparedVideo(RoomModel room, String userId) =>
      _firestore.firestore.runTransaction((tx) async {
        final ref = _room(room.id);
        final latest = (await tx.get(ref)).data();
        if (latest == null ||
            latest['videoId'] != room.videoId ||
            latest['syncEventId'] != room.syncEventId ||
            latest['updatedBy'] != userId ||
            latest['isPlaying'] != false) {
          return;
        }
        tx.update(ref, {
          'isPlaying': true,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
          'syncEventId': const Uuid().v4(),
        });
      });

  Future<void> playQueued(String roomId, String itemId, String userId) =>
      _firestore.firestore.runTransaction((tx) async {
        final s = await tx.get(_room(roomId));
        final queue = List<Map<String, dynamic>>.from(
            (s.data()?['queue'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e)));
        final index = queue.indexWhere((e) => e['id'] == itemId);
        if (index < 0) return;
        final item = queue.removeAt(index);
        tx.update(_room(roomId), {
          'videoId': item['videoId'],
          'videoTitle': item['title'],
          'queue': queue,
          'currentTime': 0.0,
          'isPlaying': false,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
          'updatedBy': userId,
          'syncEventId': 'subtitle-prepare:${const Uuid().v4()}'
        });
      });
}
