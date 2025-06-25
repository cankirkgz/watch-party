import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  final String id;
  final String videoId;
  final DateTime createdAt;
  final bool isPlaying;
  final double currentTime;
  final int videoHour;
  final int videoMinute;
  final int videoSecond;
  final String? createdBy;
  final List<String> participants;
  final DateTime? lastUpdatedAt;

  RoomModel({
    required this.id,
    required this.videoId,
    required this.createdAt,
    required this.isPlaying,
    required this.currentTime,
    this.createdBy,
    this.participants = const [],
    this.videoHour = 0,
    this.videoMinute = 0,
    this.videoSecond = 0,
    this.lastUpdatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'createdAt': createdAt.toIso8601String(),
      'isPlaying': isPlaying,
      'currentTime': currentTime,
      'createdBy': createdBy,
      'participants': participants,
      'videoHour': videoHour,
      'videoMinute': videoMinute,
      'videoSecond': videoSecond,
      'lastUpdatedAt': lastUpdatedAt?.toIso8601String(),
    };
  }

  factory RoomModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime? parsedUpdatedAt;
    if (map['lastUpdatedAt'] is Timestamp) {
      parsedUpdatedAt = (map['lastUpdatedAt'] as Timestamp).toDate();
    } else if (map['lastUpdatedAt'] != null) {
      parsedUpdatedAt = DateTime.parse(map['lastUpdatedAt']);
    }
    return RoomModel(
      id: id,
      videoId: map['videoId'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      isPlaying: map['isPlaying'] ?? false,
      currentTime: (map['currentTime'] ?? 0).toDouble(),
      createdBy: map['createdBy'],
      participants: List<String>.from(map['participants'] ?? []),
      videoHour: map['videoHour'] ?? 0,
      videoMinute: map['videoMinute'] ?? 0,
      videoSecond: map['videoSecond'] ?? 0,
      lastUpdatedAt: parsedUpdatedAt,
    );
  }
}
