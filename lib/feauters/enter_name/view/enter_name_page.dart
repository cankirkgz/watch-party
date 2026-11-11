import 'package:watchparty/shared/party_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchparty/shared/molecules/room_actions_panel.dart';
import 'package:watchparty/services/user_prefs_service.dart';
import 'package:watchparty/services/user_service.dart';

class EnterNamePage extends StatelessWidget {
  final String roomId;
  final String videoId;
  final String mode; // 'create' veya 'join'

  const EnterNamePage({
    super.key,
    required this.roomId,
    required this.videoId,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController nameController = TextEditingController();

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 100),
            Text(
              l(context, "Adını yaz", "Enter Your Name", "Введите имя",
                  "Gib deinen Namen ein", "Escribe tu nombre"),
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              l(
                  context,
                  "Arkadaşlarının göreceği adını yaz",
                  "Enter your name so that your friends can see you",
                  "Введите имя, которое увидят друзья",
                  "Gib den Namen ein, den deine Freunde sehen",
                  "Escribe el nombre que verán tus amigos"),
              style: TextStyle(fontSize: 18, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 100),
            RoomActionsPanel(
              controller: nameController,
              mode: RoomActionMode.custom,
              customLabel: l(context, "Adın", "Your Name", "Ваше имя",
                  "Dein Name", "Tu nombre"),
              customHint: l(context, "Adını yaz", "Please enter your name",
                  "Введите имя", "Gib deinen Namen ein", "Escribe tu nombre"),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  // Kullanıcı kimliğini al.
                  final userId = await UserPrefsService.getOrCreateUserId();
                  // Firestore profilini güncelle.
                  await UserService().updateUserName(userId, name);
                  // İzleme odasına yönlendir.
                  if (!context.mounted) return;
                  context.go(
                      '/room/$roomId?videoId=$videoId&name=$name&mode=$mode');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(l(
                            context,
                            "Lütfen adını yaz.",
                            "Lütfen adınızı girin.",
                            "Введите имя.",
                            "Gib bitte deinen Namen ein.",
                            "Escribe tu nombre."))),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
