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
        children: [
          // Chat header
          _buildChatHeader(),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          // Chat messages
          _buildMessagesList(),
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          // Chat input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatHeader() {
    return SizedBox(
      height: 60,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Live Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return Container(
      height: 250,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: scrollController,
            reverse: messages.isEmpty,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: messages.length,
                      itemBuilder: (context, index) => messages[index],
                    ),
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
}
