import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YoutubeVideoPlayer extends StatefulWidget {
  const YoutubeVideoPlayer(
      {super.key,
      required this.videoId,
      required this.currentPosition,
      required this.totalDuration,
      this.onPositionChanged});
  final String videoId;
  final Duration currentPosition, totalDuration;
  final ValueChanged<Duration>? onPositionChanged;
  @override
  State<YoutubeVideoPlayer> createState() => _YoutubeVideoPlayerState();
}

class _YoutubeVideoPlayerState extends State<YoutubeVideoPlayer> {
  late final YoutubePlayerController _controller;
  StreamSubscription<YoutubeVideoState>? _subscription;
  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: false,
        startSeconds: widget.currentPosition.inMilliseconds / 1000);
    _subscription = _controller.videoStateStream
        .listen((s) => widget.onPositionChanged?.call(s.position));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => YoutubePlayer(controller: _controller);
}
