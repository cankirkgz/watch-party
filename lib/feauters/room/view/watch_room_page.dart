import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watchparty/feauters/room/services/room_service.dart';
import 'package:watchparty/feauters/room/view_model/room_view_model.dart';
import 'package:watchparty/shared/molecules/room_code_badge.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:watchparty/services/firestore_service.dart';
import 'package:watchparty/shared/atoms/viewer_count_badge.dart';
import 'package:watchparty/shared/organisms/chat_panel.dart';
import 'package:watchparty/services/user_prefs_service.dart';
import 'package:watchparty/services/message_service.dart';
import 'package:watchparty/models/message_model.dart';
import 'package:watchparty/services/user_service.dart';
import 'package:watchparty/shared/molecules/chat_message_bubble.dart';

class WatchRoomPage extends StatefulWidget {
  final String roomId;
  final String videoId;

  const WatchRoomPage({Key? key, required this.roomId, required this.videoId})
      : super(key: key);

  @override
  _WatchRoomPageState createState() => _WatchRoomPageState();
}

class _WatchRoomPageState extends State<WatchRoomPage>
    with WidgetsBindingObserver {
  late final YoutubePlayerController _controller;
  late final RoomViewModel _viewModel;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  late final TextEditingController _chatController;
  bool _isLocalAction = false;
  bool? _lastRemoteIsPlaying;
  Duration _lastRemotePosition = Duration.zero;
  bool _showControls = false;

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
    WidgetsBinding.instance.addObserver(this);

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

    _addSelfToParticipants();
  }

  Future<void> _addSelfToParticipants() async {
    final userId = await UserPrefsService.getOrCreateUserId();
    await RoomService(FirestoreService()).addParticipant(widget.roomId, userId);
  }

  Future<void> _removeSelfFromParticipants() async {
    final userId = await UserPrefsService.getOrCreateUserId();
    await RoomService(FirestoreService())
        .removeParticipant(widget.roomId, userId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeSelfFromParticipants();
    _controller.removeListener(_onVideoPlayerUpdate);
    _controller.dispose();
    _viewModel.close();
    _chatController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _removeSelfFromParticipants();
    } else if (state == AppLifecycleState.resumed) {
      _addSelfToParticipants();
    }
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  void handleMessage(String content) {
    if (content.startsWith('[audio]:')) {
      final path = content.replaceFirst('[audio]:', '');
      // TODO: Ses mesajı oynatıcı ekle
      print('Sesli mesaj: ' + path);
    } else {
      // Normal yazılı mesaj
      print('Yazılı mesaj: ' + content);
    }
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
              BlocBuilder<RoomViewModel, RoomViewState>(
                builder: (context, state) {
                  int count = 0;
                  if (state is RoomViewSynced) {
                    count = state.room.participants.length;
                  }
                  return ViewerCountBadge(viewerCount: count);
                },
              ),
              const SizedBox(width: 12),
            ],
          ),
          resizeToAvoidBottomInset: true,
          body: Column(
            children: [
              // Video player
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  children: [
                    YoutubePlayer(controller: _controller),
                    // Karartma ve kontroller
                    AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _showControls = false;
                          });
                        },
                        child: Container(
                          color: Colors.black.withOpacity(0.4),
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 32,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      iconSize: 60,
                                      icon: Icon(
                                        _isPlaying
                                            ? Icons.pause_circle_filled
                                            : Icons.play_circle_fill,
                                        color: Colors.white,
                                      ),
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
                                          currentTime: _controller
                                              .value.position.inSeconds
                                              .toDouble(),
                                        );
                                        Future.delayed(
                                            const Duration(milliseconds: 100),
                                            () => setState(
                                                () => _isLocalAction = false));
                                      },
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Row(
                                        children: [
                                          Text(_formatDuration(_position),
                                              style: TextStyle(
                                                  color: Colors.white)),
                                          Expanded(
                                            child: Slider(
                                              min: 0,
                                              max: _duration.inSeconds
                                                  .toDouble(),
                                              value: _position.inSeconds
                                                  .toDouble()
                                                  .clamp(
                                                      0,
                                                      _duration.inSeconds
                                                          .toDouble()),
                                              onChanged: (v) {
                                                setState(() => _position =
                                                    Duration(
                                                        seconds: v.toInt()));
                                              },
                                              onChangeEnd: (v) {
                                                _isLocalAction = true;
                                                _controller.seekTo(Duration(
                                                    seconds: v.toInt()));
                                                _viewModel
                                                    .setPlaybackState(
                                                  roomId: widget.roomId,
                                                  isPlaying: _isPlaying,
                                                  currentTime: v,
                                                )
                                                    .whenComplete(() {
                                                  Future.delayed(
                                                      const Duration(
                                                          milliseconds: 100),
                                                      () => setState(() =>
                                                          _isLocalAction =
                                                              false));
                                                });
                                              },
                                            ),
                                          ),
                                          Text(_formatDuration(_duration),
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Tıklama alanı (kontrolleri açmak için)
                    if (!_showControls)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            setState(() {
                              _showControls = true;
                            });
                          },
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(),

              // Chat panel - Ekranın kalanını tamamen kaplasın
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: StreamBuilder<List<MessageModel>>(
                    stream: MessageService().getMessagesStream(widget.roomId),
                    builder: (context, snapshot) {
                      final messages = snapshot.data ?? [];
                      final chatBubbles = messages
                          .map((msg) => ChatMessageBubble(
                                username: msg.senderName,
                                time: _formatTime(msg.sentAt),
                                message: msg.text,
                              ))
                          .toList();
                      return ChatPanel(
                        messages: chatBubbles,
                        controller: _chatController,
                        onSend: (text) async {
                          handleMessage(text);
                          if (text.trim().isEmpty) return;
                          final userId =
                              await UserPrefsService.getOrCreateUserId();
                          String userName = "";
                          try {
                            final user =
                                await UserService().getUserById(userId);
                            userName = user?.name ?? "Anonim";
                          } catch (_) {
                            userName = "Anonim";
                          }
                          final message = MessageModel(
                            text: text,
                            senderId: userId,
                            senderName: userName,
                            sentAt: DateTime.now(),
                            roomId: widget.roomId,
                          );
                          await MessageService().sendMessage(message);
                        },
                      );
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
