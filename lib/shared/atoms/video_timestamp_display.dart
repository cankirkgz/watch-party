import 'package:flutter/material.dart';

class VideoTimestampDisplay extends StatelessWidget {
  final Duration currentPosition;
  final Duration totalDuration;

  const VideoTimestampDisplay({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
  });

  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${formatDuration(currentPosition)} / ${formatDuration(totalDuration)}',
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
