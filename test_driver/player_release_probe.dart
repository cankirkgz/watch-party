import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:watchparty/shared/molecules/inline_youtube_surface.dart';
import 'package:watchparty/core/utils/youtube_player_startup.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

// Isolated release-mode player probe: no Firebase or OpenAI requests.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AndroidWebViewController.enableDebugging(true);
  runApp(const MaterialApp(home: PlayerReleaseProbe()));
}

class PlayerReleaseProbe extends StatefulWidget {
  const PlayerReleaseProbe({super.key});
  @override
  State<PlayerReleaseProbe> createState() => _PlayerReleaseProbeState();
}

class _PlayerReleaseProbeState extends State<PlayerReleaseProbe> {
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _sub;
  Timer? _timer;
  int _mode = 0;
  String _status = '';
  final _reports = <String>[];
  static const _video =
      String.fromEnvironment('PROBE_VIDEO', defaultValue: 'XTdU5RSodZ4');
  static const _origin = String.fromEnvironment('PROBE_ORIGIN',
      defaultValue: 'https://watch-party-d4610.web.app');

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _sub?.cancel();
    final old = _controller;
    final params = YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        enableKeyboard: false,
        enableCaption: true,
        captionLanguage: 'tr',
        pointerEvents: PointerEvents.auto,
        origin: _mode == 1 ? 'https://com.example.watchparty' : _origin);
    final player = YoutubePlayerController(params: params, key: _video);
    setState(() {
      _controller = player;
      _status = 'loading';
    });
    _sub = player.listen((value) {
      if (!mounted || _controller != player) return;
      final status =
          'mode=$_mode state=${value.playerState.name} error=${value.error.code} duration=${value.metaData.duration.inSeconds}';
      if (status == _status) return;
      debugPrint('PLAYER_PROBE $status');
      setState(() => _status = status);
    });
    await old?.close();
    try {
      await initializeEmbeddedVideo(
          player: player,
          videoId: _video,
          startSeconds: 26,
          isPlaying: _mode == 2);
      await player.playVideo();
    } catch (e) {
      debugPrint('PLAYER_PROBE mode=$_mode init=$e');
    }
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 18), () async {
      if (!mounted || _controller != player) return;
      final summary = 'mode=$_mode $_status time=${await player.currentTime}';
      debugPrint('PLAYER_PROBE RESULT $summary');
      setState(() => _reports.add(summary));
      if (_mode < 2) {
        _mode++;
        await _start();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Release player probe')),
        body: Column(children: [
          Text('video=$_video | mode=$_mode'),
          if (_controller != null)
            SizedBox(
                height: 260,
                child: InlineYoutubeSurface(
                    key: ValueKey(_controller), controller: _controller!)),
          Text(_status),
          FilledButton(
              onPressed: () => _controller?.playVideo(),
              child: const Text('Play')),
          Expanded(
              child: SingleChildScrollView(child: Text(_reports.join('\n')))),
        ]),
      );
}
