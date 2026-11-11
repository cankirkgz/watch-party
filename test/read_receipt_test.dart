import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchparty/models/message_model.dart';
import 'package:watchparty/shared/molecules/chat_message_bubble.dart';

void main() {
  final sentAt = DateTime.utc(2026, 11, 2, 12);
  MessageModel message({bool pending = false}) => MessageModel(
        id: 'one',
        senderId: 'me',
        senderName: 'Can',
        roomId: 'ABC234',
        sentAt: sentAt,
        text: 'Hello',
        hasPendingWrites: pending,
      );
  test('a double check requires another reader at or after this message', () {
    expect(message().isReadByPeer('me', {'me': sentAt}), false);
    expect(
        message().isReadByPeer(
            'me', {'friend': sentAt.subtract(const Duration(microseconds: 1))}),
        false);
    expect(message().isReadByPeer('me', {'friend': sentAt}), true);
    expect(
        message(pending: true).isReadByPeer('me', {'friend': sentAt}), false);
  });
  test('local and unresolved server timestamps cannot be marked read', () {
    final unresolved = MessageModel.fromMap(
        {'senderId': 'friend', 'senderName': 'Friend', 'sentAt': null});
    expect(unresolved.hasServerTimestamp, false);
    expect(unresolved.isReadByPeer('me', {'friend': DateTime(2100)}), false);
    final resolved = MessageModel.fromMap(
        {'sentAt': Timestamp.fromDate(sentAt)},
        hasPendingWrites: true);
    expect(resolved.hasPendingWrites, true);
  });
  testWidgets('sent changes from one check to two when the receipt arrives',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ChatMessageBubble(
      message: message(),
      isMine: true,
      currentUserId: 'me',
    ))));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.done_all_rounded), findsNothing);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ChatMessageBubble(
      message: message(),
      isMine: true,
      currentUserId: 'me',
      isRead: true,
    ))));
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
    expect(find.byTooltip('Read'), findsOneWidget);
  });
}
