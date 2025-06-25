import 'package:flutter/material.dart';
import 'package:watchparty/services/audio_recorder_service.dart';
import 'package:watchparty/shared/atoms/chat_input_field.dart';
import 'package:watchparty/shared/atoms/mic_icon_button.dart';
import 'package:watchparty/shared/atoms/send_icon_button.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String> onSend;
  final VoidCallback? onMicPressed;

  const ChatInputBar({
    super.key,
    this.controller,
    required this.onSend,
    this.onMicPressed,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final recorder = AudioRecorderService();
  bool isRecording = false;
  String? filePath;

  Future<void> toggleRecording() async {
    // Mikrofon izni kontrolü ve isteme
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mikrofon izni gerekli!')),
          );
        }
        return;
      }
    }
    if (isRecording) {
      final path = await recorder.stopRecording();
      if (path != null) {
        widget.onSend('[audio]:' + path);
      }
    } else {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      await recorder.startRecording(fileName);
    }
    setState(() => isRecording = !isRecording);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller ?? TextEditingController();
    return Row(
      children: [
        Expanded(
          child: ChatInputField(controller: controller),
        ),
        const SizedBox(width: 10),
        MicIconButton(
          onPressed: toggleRecording,
          isRecording: isRecording,
        ),
        const SizedBox(width: 10),
        SendIconButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              widget.onSend(controller.text.trim());
              controller.clear();
            }
          },
        ),
      ],
    );
  }
}
