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
    final TextEditingController _nameController = TextEditingController();

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 100),
            const Text(
              "Enter Your Name",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              "Enter your name so that your friends can see you",
              style: TextStyle(fontSize: 18, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 100),
            RoomActionsPanel(
              controller: _nameController,
              mode: RoomActionMode.custom,
              customLabel: "Your Name",
              customHint: "Please enter your name",
              onPressed: () async {
                final name = _nameController.text.trim();
                if (name.isNotEmpty) {
                  // Kullanıcı id'sini al
                  final userId = await UserPrefsService.getOrCreateUserId();
                  // Firestore'da ismi güncelle
                  await UserService().updateUserName(userId, name);
                  // WatchRoomPage'e yönlendir
                  context.go(
                      '/room/$roomId?videoId=$videoId&name=$name&mode=$mode');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Lütfen adınızı girin.")),
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
