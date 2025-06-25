import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watchparty/feauters/room/services/room_service.dart';
import 'package:watchparty/feauters/room/view_model/room_view_model.dart';
import 'package:watchparty/shared/molecules/room_code_badge.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:watchparty/services/firestore_service.dart';
import 'package:watchparty/shared/atoms/viewer_count_badge.dart';
import 'package:watchparty/shared/organisms/chat_panel.dart';
import 'package:watchparty/shared/molecules/chat_message_bubble.dart';

class WatchRoomPage extends StatefulWidget {
  final String roomId;
  final String videoId;

  const WatchRoomPage({Key? key, required this.roomId, required this.videoId})
      : super(key: key);

  @override
  _WatchRoomPageState createState() => _WatchRoomPageState();
}

class _WatchRoomPageState extends State<WatchRoomPage> {
  late final YoutubePlayerController _controller;
  late final RoomViewModel _viewModel;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  late final TextEditingController _chatController;
  bool _isLocalAction = false;
  bool? _lastRemoteIsPlaying;
  Duration _lastRemotePosition = Duration.zero;

  void _onVideoPlayerUpdate() {
    final playerValue = _controller.value;

    setState(() {
      _position = playerValue.position;
      _duration = playerValue.metaData.duration;
      _isPlaying = playerValue.isPlaying;
    });
  }

  @override
  void initState() {
    super.initState();

    // YouTube controller with custom controls
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        disableDragSeek: true,
        enableCaption: false,
        hideControls: true,
        controlsVisibleAtStart: false,
        useHybridComposition: true, // Performans için
      ),
    )..addListener(_onVideoPlayerUpdate);

    // ViewModel setup
    final fs = FirestoreService();
    _viewModel = RoomViewModel(RoomService(fs));
    _viewModel.joinRoom(widget.roomId);

    // Chat input
    _chatController = TextEditingController();
    _controller.addListener(_onVideoPlayerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoPlayerUpdate); // ✅ unutma
    _controller.dispose();
    _viewModel.close();
    _chatController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final current = _controller.value.position.inSeconds.toDouble();
    DateTime? _lastSyncTime;
    String? _lastUpdatedBy;

    return BlocProvider.value(
      value: _viewModel,
      child: BlocListener<RoomViewModel, RoomViewState>(
        listener: (context, state) {
          if (state is RoomViewSynced) {
            if (_isLocalAction) return; // 1️⃣ kendi güncellemeni yoksay

            final room = state.room;
            final now = room.lastUpdatedAt ?? DateTime.now();
            final elapsed = DateTime.now().difference(now).inSeconds;
            final remotePos = room.isPlaying
                ? Duration(seconds: room.currentTime.toInt() + elapsed)
                : Duration(seconds: room.currentTime.toInt());
            final diff =
                (remotePos - _controller.value.position).inSeconds.abs();
            if (room.isPlaying != _lastRemoteIsPlaying || diff > 1) {
              _lastRemoteIsPlaying = room.isPlaying;
              _lastRemotePosition = remotePos;
              if (diff > 1) {
                _controller.seekTo(remotePos);
              }
              if (room.isPlaying && !_controller.value.isPlaying) {
                _controller.play();
              } else if (!room.isPlaying && _controller.value.isPlaying) {
                _controller.pause();
              }
            }
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Watch Room', style: TextStyle(fontSize: 24)),
            actions: [
              RoomCodeBadge(roomCode: widget.roomId),
              const SizedBox(width: 12),
              ViewerCountBadge(viewerCount: 0), // TODO: bind real count
              const SizedBox(width: 12),
            ],
          ),
          body: Column(
            children: [
              // Video player - AspectRatio ekleyerek taşmayı önle
              AspectRatio(
                aspectRatio: 16 / 9,
                child: YoutubePlayer(controller: _controller),
              ),

              // Play/Pause button
              IconButton(
                padding: EdgeInsets.zero,
                iconSize: 35,
                icon: Icon(_isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill),
                onPressed: () async {
                  setState(() => _isLocalAction = true);
                  if (_isPlaying) {
                    _controller.pause();
                  } else {
                    _controller.play();
                  }
                  await _viewModel.setPlaybackState(
                    roomId: widget.roomId,
                    isPlaying: !_isPlaying,
                    currentTime:
                        _controller.value.position.inSeconds.toDouble(),
                  );
                  // küçük bir gecikmeyle yerel eylemi kapat
                  Future.delayed(const Duration(milliseconds: 100),
                      () => setState(() => _isLocalAction = false));
                },
              ),

              // Slider with timestamps
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(_formatDuration(_position)),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: _duration.inSeconds.toDouble(),
                        value: _position.inSeconds
                            .toDouble()
                            .clamp(0, _duration.inSeconds.toDouble()),
                        onChanged: (v) {
                          setState(
                              () => _position = Duration(seconds: v.toInt()));
                        },
                        onChangeEnd: (v) {
                          // 3️⃣ debounce: kullanıcı hemen birkaç kez sürükleyebilir
                          _isLocalAction = true;
                          _controller.seekTo(Duration(seconds: v.toInt()));
                          _viewModel
                              .setPlaybackState(
                            roomId: widget.roomId,
                            isPlaying: _isPlaying,
                            currentTime: v,
                          )
                              .whenComplete(() {
                            Future.delayed(const Duration(milliseconds: 100),
                                () => setState(() => _isLocalAction = false));
                          });
                        },
                      ),
                    ),
                    Text(_formatDuration(_duration)),
                  ],
                ),
              ),

              const Divider(),

              // Chat panel - Expanded ile sarmalayarak kalan alanı kaplamasını sağla
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ChatPanel(
                    messages: const [
                      ChatMessageBubble(
                          username: 'Alice', time: '00:10', message: 'Hey! 👋'),
                      ChatMessageBubble(
                          username: 'Bob', time: '00:15', message: 'Hi there!'),
                    ],
                    controller: _chatController,
                    onSend: (msg) {
                      // TODO: implement sending chat message
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
