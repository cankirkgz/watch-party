import 'package:flutter/material.dart';
import 'package:watchparty/shared/molecules/chat_input_bar.dart';
import 'package:watchparty/shared/molecules/chat_message_bubble.dart';

class ChatPanel extends StatelessWidget {
  final List<ChatMessageBubble> messages;
  final ValueChanged<String> onSend;
  final TextEditingController controller;
  final ScrollController? scrollController;
  final bool isLoading;

  const ChatPanel({
    super.key,
    required this.messages,
    required this.onSend,
    required this.controller,
    this.scrollController,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chat header
          _buildChatHeader(),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          // Chat messages
          Expanded(
            child: _buildMessagesList(),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          // Chat input area
          _buildInputArea(context),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView.builder(
            controller: scrollController,
            reverse: false,
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            itemCount: messages.isEmpty ? 1 : messages.length,
            itemBuilder: (context, index) {
              if (messages.isEmpty) {
                return const SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }
              return messages[index];
            },
          );
        },
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ChatInputBar(
        controller: controller,
        onSend: onSend,
      ),
    );
  }

  Widget _buildChatHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text(
            'Chat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
