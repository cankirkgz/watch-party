import 'package:flutter/material.dart';

class PlaybackStatusLabel extends StatelessWidget {
  const PlaybackStatusLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          "assets/icons/play-icon.png",
          width: 16,
          height: 16,
        ),
        SizedBox(width: 12),
        Text(
          "Synced with room",
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }
}
