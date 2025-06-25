import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:watchparty/shared/atoms/playback_status_label.dart';
import 'package:watchparty/shared/atoms/video_timestamp_display.dart';

class YoutubeVideoPlayer extends StatefulWidget {
  final String videoId;
  final Duration currentPosition;
  final Duration totalDuration;
  final void Function(Duration position)? onPositionChanged;

  const YoutubeVideoPlayer({
    super.key,
    required this.videoId,
    required this.currentPosition,
    required this.totalDuration,
    this.onPositionChanged,
  });

  @override
  State<YoutubeVideoPlayer> createState() => _YoutubeVideoPlayerState();
}

class _YoutubeVideoPlayerState extends State<YoutubeVideoPlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
          autoPlay: false,
          controlsVisibleAtStart: true,
          disableDragSeek: false,
          mute: false,
          isLive: false,
          hideControls: false),
    );

    /// Eğer bir başlangıç zamanı belirlemek istersen:
    _controller.seekTo(widget.currentPosition);

    _controller.addListener(_positionListener);
  }

  void _positionListener() {
    if (widget.onPositionChanged != null) {
      widget.onPositionChanged!(_controller.value.position);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_positionListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.deepPurpleAccent,
              ),
            ),
          ),
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const PlaybackStatusLabel(),
                VideoTimestampDisplay(
                  currentPosition: widget.currentPosition,
                  totalDuration: widget.totalDuration,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
