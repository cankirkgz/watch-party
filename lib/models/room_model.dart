import 'package:cloud_firestore/cloud_firestore.dart';

class RoomModel {
  const RoomModel({
    required this.id,
    required this.videoId,
    required this.createdAt,
    required this.isPlaying,
    required this.currentTime,
    this.createdBy,
    this.participants = const [],
    this.lastUpdatedAt,
    this.updatedBy,
    this.syncEventId,
    this.videoTitle = '',
    this.queue = const [],
    this.isFromCache = false,
    this.hasPendingWrites = false,
  });

  final String id;
  final String videoId;
  final DateTime createdAt;
  final bool isPlaying;
  final double currentTime;
  final String? createdBy;
  final List<String> participants;
  final DateTime? lastUpdatedAt;
  final String? updatedBy;
  final String? syncEventId;
  final String videoTitle;
  final List<Map<String, dynamic>> queue;
  final bool isFromCache;
  final bool hasPendingWrites;

  Map<String, dynamic> toMap() => {
        'videoId': videoId,
        'createdAt': Timestamp.fromDate(createdAt),
        'isPlaying': isPlaying,
        'currentTime': currentTime,
        'createdBy': createdBy,
        'participants': participants,
        'lastUpdatedAt':
            lastUpdatedAt == null ? null : Timestamp.fromDate(lastUpdatedAt!),
        'updatedBy': updatedBy,
        'syncEventId': syncEventId,
        'videoTitle': videoTitle,
        'queue': queue,
      };

  factory RoomModel.fromMap(String id, Map<String, dynamic> map,
      {bool isFromCache = false, bool hasPendingWrites = false}) {
    return RoomModel(
      id: id,
      isFromCache: isFromCache,
      hasPendingWrites: hasPendingWrites,
      videoId: map['videoId'] as String? ?? '',
      createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
      isPlaying: map['isPlaying'] as bool? ?? false,
      currentTime: (map['currentTime'] as num? ?? 0).toDouble(),
      createdBy: map['createdBy'] as String?,
      participants: List<String>.from(map['participants'] as List? ?? const []),
      lastUpdatedAt: _parseDate(map['lastUpdatedAt']),
      updatedBy: map['updatedBy'] as String?,
      syncEventId: map['syncEventId'] as String?,
      videoTitle: map['videoTitle'] as String? ?? '',
      queue: (map['queue'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
