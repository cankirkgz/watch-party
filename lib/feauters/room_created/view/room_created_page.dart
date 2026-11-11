import 'package:watchparty/shared/party_ui.dart';
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
            Text(
              l(
                  context,
                  "Odan hazır!",
                  "Your room is ready!",
                  "Ваша комната готова!",
                  "Dein Raum ist bereit!",
                  "¡Tu sala está lista!"),
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              l(
                  context,
                  "Aşağıdaki kodu arkadaşlarınla paylaş",
                  "Share the code below with friends",
                  "Поделитесь кодом с друзьями",
                  "Teile den Code mit deinen Freunden",
                  "Comparte el código con tus amigos"),
              style: TextStyle(fontSize: 18, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 20),
            RoomCodeCard(
              roomCode: roomCode,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: l(context, "Odaya git", "Go To Room", "Войти в комнату",
                  "Zum Raum", "Ir a la sala"),
              onPressed: () {
                context.pushReplacement('/room/$roomCode?videoId=$videoId');
              },
              assetIconPath: "assets/icons/arrow-right-icon.png",
            ),
            const SizedBox(height: 20),
            FeatureItem(
              iconAssetPath: "assets/icons/video-icon-outlined.png",
              text: l(
                  context,
                  "Birlikte senkron izle",
                  "Watch together in sync",
                  "Смотрите синхронно",
                  "Synchron zusammen schauen",
                  "Ver juntos en sincronía"),
            ),
            FeatureItem(
              iconAssetPath: "assets/icons/chat-icon-outlined.png",
              text: l(
                  context,
                  "Arkadaşlarınla sohbet et",
                  "Chat with friends",
                  "Общайтесь с друзьями",
                  "Mit Freunden chatten",
                  "Chatea con tus amigos"),
            ),
          ],
        ),
      ),
    );
  }
}
