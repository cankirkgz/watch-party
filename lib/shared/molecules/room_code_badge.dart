import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RoomCodeBadge extends StatelessWidget {
  final String roomCode;

  const RoomCodeBadge({super.key, required this.roomCode});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: roomCode));
      },
      child: Container(
        padding: EdgeInsets.all(7),
        height: 32,
        decoration: BoxDecoration(
          color: Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          children: [
            SizedBox(width: 6),
            Text(
              "Room: #$roomCode",
              style: TextStyle(
                color: Color(
                  0xFFD1D5DB,
                ),
              ),
            ),
            SizedBox(width: 6),
            Image.asset(
              "assets/icons/copy-icon.png",
              width: 12,
              height: 24,
              color: Color(0xFF8B5CF6),
            ),
            SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}
