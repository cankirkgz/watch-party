import 'package:flutter/material.dart';

class MicIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isRecording;

  const MicIconButton({
    required this.onPressed,
    this.isRecording = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(isRecording ? Icons.stop : Icons.mic),
      onPressed: onPressed,
      color: isRecording ? Colors.red : Colors.grey,
    );
  }
}
