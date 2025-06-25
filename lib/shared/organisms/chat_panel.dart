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
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * 0.5, // Maksimum yükseklik ekle
      ),
      child: Column(
        children: [
          // Chat header
          _buildChatHeader(),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          // Chat messages - Expanded ile sarmala
          Expanded(
            child: _buildMessagesList(),
          ),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          // Chat input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: scrollController,
            reverse: messages.isEmpty,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
                maxHeight: double.infinity, // Maksimum yükseklik kaldırıldı
              ),
              child: Column(
                mainAxisAlignment: messages.isEmpty
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (messages.isEmpty)
                    const Text(
                      'No messages yet',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    )
                  else
                    ...messages, // ListView yerine doğrudan children kullanıldı
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      height: 90,
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
