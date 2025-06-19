import 'package:flutter/material.dart';
import 'package:watchparty/shared/atoms/copy_button.dart';
import 'package:flutter/services.dart';

class RoomLinkBox extends StatelessWidget {
  final String roomLink;

  const RoomLinkBox({
    super.key,
    required this.roomLink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2A2A2A),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            roomLink.length > 35 ? roomLink.substring(0, 25) + '...' : roomLink,
            style: const TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          CopyButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: roomLink));
            },
          )
        ],
      ),
    );
  }
}
