import 'package:flutter/material.dart';
import 'package:watchparty/shared/atoms/user_avatar.dart';
import 'package:watchparty/shared/molecules/chat_input_bar.dart';

class ChatMessageBubble extends StatelessWidget {
  final String username;
  final String time;
  final String message;

  const ChatMessageBubble({
    super.key,
    required this.username,
    required this.time,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        UserAvatar(),
        SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  username,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  time,
                  style: TextStyle(
                    color: Color(
                      0xFF6B7280,
                    ),
                  ),
                ),
              ],
            ),
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFFD1D5DB),
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        )
      ],
    );
  }
}
