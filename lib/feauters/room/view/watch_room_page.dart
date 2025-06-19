import 'package:flutter/material.dart';
import 'package:watchparty/shared/atoms/viewer_count_badge.dart';
import 'package:watchparty/shared/molecules/chat_message_bubble.dart';
import 'package:watchparty/shared/molecules/room_code_badge.dart';
import 'package:watchparty/shared/molecules/room_link_box.dart';
import 'package:watchparty/shared/molecules/youtube_video_player.dart';
import 'package:watchparty/shared/organisms/chat_panel.dart';

class WatchRoomPage extends StatelessWidget {
  final String roomId;
  final String videoId;

  const WatchRoomPage({
    super.key,
    required this.roomId,
    required this.videoId,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: videoId);
    print("LALALA" + videoId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Watch Room",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
        actions: [
          RoomCodeBadge(roomCode: roomId),
          const SizedBox(width: 12),
          const ViewerCountBadge(viewerCount: 12),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 📺 YouTube Video Player
            if (videoId.isEmpty) ...[
              const Text(
                'Geçerli bir video bulunamadı.',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 20),
              YoutubeVideoPlayer(
                videoId: 'dQw4w9WgXcQ', // Örnek geçerli bir videoId
                currentPosition: const Duration(minutes: 2, seconds: 21),
                totalDuration: const Duration(minutes: 5, seconds: 31),
              ),
            ] else ...[
              YoutubeVideoPlayer(
                videoId: videoId,
                currentPosition: const Duration(minutes: 2, seconds: 21),
                totalDuration: const Duration(minutes: 5, seconds: 31),
              ),
            ],
            const SizedBox(height: 20),

            // Geri kalan içerik ve Chat Panel
            Expanded(
              child: Stack(
                children: [
                  // Diğer içerikler buraya gelebilir (eğer varsa)
                  // Chat Panel
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ChatPanel(
                      messages: const [
                        ChatMessageBubble(
                          username: "Katenka",
                          time: "2:41",
                          message: "I love you Mert!",
                        ),
                        ChatMessageBubble(
                          username: "Mert",
                          time: '3:02',
                          message: "I love you too Honey!",
                        ),
                      ],
                      onSend: (String message) {
                        // TODO: Mesaj gönderme mantığı buraya eklenecek
                      },
                      controller: controller,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
