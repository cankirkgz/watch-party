import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, audio }

class MessageModel {
  const MessageModel({
    this.id = '',
    required this.senderId,
    required this.senderName,
    required this.sentAt,
    required this.roomId,
    this.type = MessageType.text,
    this.text = '',
    this.mediaUrl,
    this.durationMs,
    this.languageCode = 'tr',
    this.senderCountry = '',
    this.videoSeconds,
    this.replyToText,
    this.replyToMessageId,
    this.replyToSenderName,
    this.reactions = const {},
    this.hasPendingWrites = false,
    this.hasServerTimestamp = true,
  });

  final String id;
  final String senderId;
  final String senderName;
  final DateTime sentAt;
  final String roomId;
  final MessageType type;
  final String text;
  final String? mediaUrl;
  final int? durationMs;
  final String languageCode;
  final String senderCountry;
  final double? videoSeconds;
  final String? replyToText;
  final String? replyToMessageId, replyToSenderName;
  final Map<String, String> reactions;
  final bool hasPendingWrites, hasServerTimestamp;

  bool isReadByPeer(String currentUserId, Map<String, DateTime> readThrough) =>
      !hasPendingWrites &&
      hasServerTimestamp &&
      readThrough.entries.any((entry) =>
          entry.key != currentUserId && !entry.value.isBefore(sentAt));

  Map<String, dynamic> toMap() => {
        'text': text,
        'senderId': senderId,
        'senderName': senderName,
        'sentAt': Timestamp.fromDate(sentAt),
        'roomId': roomId,
        'type': type.name,
        'mediaUrl': mediaUrl,
        'durationMs': durationMs,
        'languageCode': languageCode,
        'senderCountry': senderCountry,
        'videoSeconds': videoSeconds,
        'replyToText': replyToText,
        'replyToMessageId': replyToMessageId,
        'replyToSenderName': replyToSenderName,
        'reactions': reactions,
      };

  factory MessageModel.fromMap(Map<String, dynamic> map,
      {String id = '', bool hasPendingWrites = false}) {
    final typeName = map['type'] as String? ?? 'text';
    return MessageModel(
      id: id,
      hasPendingWrites: hasPendingWrites,
      hasServerTimestamp: map['sentAt'] is Timestamp,
      text: map['text'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Guest',
      sentAt: _parseDate(map['sentAt']) ?? DateTime.now(),
      roomId: map['roomId'] as String? ?? '',
      type: MessageType.values.firstWhere(
        (type) => type.name == typeName,
        orElse: () => MessageType.text,
      ),
      mediaUrl: map['mediaUrl'] as String?,
      durationMs: (map['durationMs'] as num?)?.toInt(),
      languageCode: map['languageCode'] as String? ?? 'tr',
      senderCountry: map['senderCountry'] as String? ?? '',
      videoSeconds: (map['videoSeconds'] as num?)?.toDouble(),
      replyToText: map['replyToText'] as String?,
      replyToMessageId: map['replyToMessageId'] as String?,
      replyToSenderName: map['replyToSenderName'] as String?,
      reactions: Map<String, String>.from(map['reactions'] as Map? ?? {}),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
