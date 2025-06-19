import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchparty/shared/atoms/animated_play_button.dart';
import 'package:watchparty/shared/atoms/app_button.dart';
import 'package:watchparty/shared/molecules/feature_item.dart';
import 'package:watchparty/shared/molecules/room_code_card.dart';

class RoomCreatedPage extends StatelessWidget {
  final String roomCode;
  final String videoId;
  const RoomCreatedPage(
      {super.key, required this.roomCode, required this.videoId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0).copyWith(top: 80, bottom: 120),
        child: Column(
          children: [
            AnimatedPlayButton(
              assetPath: "assets/icons/check-button.png",
            ),
            const SizedBox(height: 20),
            const Text(
              "Your room is ready!",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              "Share the code below with friends",
              style: TextStyle(fontSize: 18, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 20),
            RoomCodeCard(
              roomCode: roomCode,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: "Go To Room",
              onPressed: () {
                context.pushReplacement('/room/$roomCode?videoId=$videoId');
              },
              assetIconPath: "assets/icons/arrow-right-icon.png",
            ),
            const SizedBox(height: 20),
            const FeatureItem(
              iconAssetPath: "assets/icons/video-icon-outlined.png",
              text: "Watch together in sync",
            ),
            const FeatureItem(
              iconAssetPath: "assets/icons/chat-icon-outlined.png",
              text: "Chat with friends",
            ),
          ],
        ),
      ),
    );
  }
}
