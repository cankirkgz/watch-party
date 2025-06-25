import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:watchparty/core/utils/youtube_utils.dart';
import 'package:watchparty/feauters/home/view_model/home_view_model.dart';
import 'package:watchparty/shared/atoms/animated_play_button.dart';
import 'package:watchparty/shared/molecules/feature_item.dart';
import 'package:watchparty/shared/molecules/room_actions_panel.dart';
import 'package:watchparty/services/user_service.dart';
import 'package:watchparty/services/user_prefs_service.dart';

class HomePage extends StatefulWidget {
  final String userId;
  const HomePage({super.key, required this.userId});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _youtubeLinkController = TextEditingController();
  final TextEditingController _roomCodeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0).copyWith(top: 80, bottom: 120),
        child: Column(
          children: [
            const AnimatedPlayButton(),
            const SizedBox(height: 20),
            const Text(
              "Watch Together",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              "Enjoy videos together in sync",
              style: TextStyle(fontSize: 18, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 20),
            const Text(
              "No account needed",
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 30),

            /// 🎥 Create Room
            BlocConsumer<HomeViewModel, HomeViewState>(
              listener: (context, state) async {
                if (state is HomeViewSuccess) {
                  final userId = widget.userId;
                  final user = await UserService().getUserById(userId);
                  if (user != null &&
                      user.name != null &&
                      user.name!.isNotEmpty) {
                    context.pushReplacement(
                        '/room/${state.roomId}?videoId=${state.videoId}&name=${user.name}&mode=create');
                  } else {
                    context.pushReplacement(
                        '/enter-name?roomId=${state.roomId}&videoId=${state.videoId}&mode=create');
                  }
                } else if (state is HomeViewError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message)),
                  );
                }
              },
              builder: (context, state) {
                return RoomActionsPanel(
                  controller: _youtubeLinkController,
                  mode: RoomActionMode.create,
                  isLoading: state is HomeViewLoading,
                  onPressed: () {
                    final link = _youtubeLinkController.text.trim();
                    if (isValidYoutubeUrl(link)) {
                      context
                          .read<HomeViewModel>()
                          .createRoom(link, widget.userId);
                    }
                  },
                );
              },
            ),

            const SizedBox(height: 30),

            BlocConsumer<HomeViewModel, HomeViewState>(
              builder: (context, state) {
                return RoomActionsPanel(
                  controller: _roomCodeController,
                  mode: RoomActionMode.join,
                  isLoading: state is HomeViewLoading,
                  onPressed: () {
                    final code = _roomCodeController.text.trim();
                    if (code.length == 6) {
                      context.read<HomeViewModel>().getRoomById(code);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Room code must be 6 characters.")),
                      );
                    }
                  },
                );
              },
              listener: (context, state) async {
                if (state is HomeViewSuccess) {
                  final userId = widget.userId;
                  final user = await UserService().getUserById(userId);
                  if (user != null &&
                      user.name != null &&
                      user.name!.isNotEmpty) {
                    context.pushReplacement(
                        '/room/${state.roomId}?videoId=${state.videoId}&name=${user.name}&mode=join');
                  } else {
                    context.pushReplacement(
                        '/enter-name?roomId=${state.roomId}&videoId=${state.videoId}&mode=join');
                  }
                } else if (state is HomeViewError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message)),
                  );
                }
              },
            ),

            const SizedBox(height: 10),

            const FeatureItem(
              iconAssetPath: "assets/icons/sync-icon.png",
              text: "Perfect sync for everyone",
            ),
            const FeatureItem(
              iconAssetPath: "assets/icons/chat-icon-outlined.png",
              text: "Built-in chat",
            ),
            const FeatureItem(
              iconAssetPath: "assets/icons/share-icon.png",
              text: "Easy sharing",
            ),
            const SizedBox(height: 20),

            const Text(
              "How it works?",
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
