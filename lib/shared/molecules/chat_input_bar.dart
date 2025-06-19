import 'package:flutter/material.dart';
import 'package:watchparty/shared/atoms/chat_input_field.dart';
import 'package:watchparty/shared/atoms/send_icon_button.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String> onSend;

  const ChatInputBar({super.key, this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ChatInputField(
            controller: controller ?? TextEditingController(),
          ),
        ),
        SizedBox(width: 10),
        SendIconButton(
          onPressed: () {
            if (controller != null && controller!.text.trim().isNotEmpty) {
              onSend(controller!.text.trim());
              controller!.clear();
            }
          },
        ),
      ],
    );
  }
}
