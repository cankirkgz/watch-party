class MessageModel {
  final String text;
  final String senderId;
  final String senderName;
  final DateTime sentAt;
  final String roomId;

  MessageModel({
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.sentAt,
    required this.roomId,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'sentAt': sentAt.toIso8601String(),
      'roomId': roomId,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      text: map['text'] as String,
      senderId: map['senderId'] as String,
      senderName: map['senderName'] as String,
      sentAt: DateTime.parse(map['sentAt'] as String),
      roomId: map['roomId'] as String,
    );
  }
}
