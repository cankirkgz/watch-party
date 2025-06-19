class RoomModel {
  final String id;
  final String videoId;
  final DateTime createdAt;
  final bool isPlaying;
  final double currentTime;
  final String? createdBy;
  final List<String> participants;

  RoomModel({
    required this.id,
    required this.videoId,
    required this.createdAt,
    required this.isPlaying,
    required this.currentTime,
    this.createdBy,
    this.participants = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'createdAt': createdAt.toIso8601String(),
      'isPlaying': isPlaying,
      'currentTime': currentTime,
      'createdBy': createdBy,
      'participants': participants,
    };
  }

  factory RoomModel.fromMap(String id, Map<String, dynamic> map) {
    return RoomModel(
      id: id,
      videoId: map['videoId'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      isPlaying: map['isPlaying'] ?? false,
      currentTime: (map['currentTime'] ?? 0).toDouble(),
      createdBy: map['createdBy'],
      participants: List<String>.from(map['participants'] ?? []),
    );
  }
}
