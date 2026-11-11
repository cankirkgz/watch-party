import 'package:youtube_player_iframe/youtube_player_iframe.dart';

// Android applicationId / iOS bundle ID, used as the native embed client identity.
const nativeYoutubeAppOrigin = 'https://com.example.watchparty';

class YoutubeStartupException implements Exception {
  const YoutubeStartupException(this.code);
  final int code;
}

/// Queue the video before initializing the iframe, as fromVideoId does.
/// A JS command completing only means it was dispatched, not that media is ready.
Future<void> initializeEmbeddedVideo({
  required YoutubePlayerController player,
  required String videoId,
  required double startSeconds,
  required bool isPlaying,
}) async {
  final ready = player.stream
      .firstWhere((value) =>
          value.hasError ||
          const [PlayerState.cued, PlayerState.playing, PlayerState.paused]
              .contains(value.playerState))
      .then<void>((value) {
    if (value.hasError) throw YoutubeStartupException(value.error.code);
  });
  final video = isPlaying
      ? player.loadVideoById(videoId: videoId, startSeconds: startSeconds)
      : player.cueVideoById(videoId: videoId, startSeconds: startSeconds);
  await Future.wait<void>(
          [ready, video, player.initWithParams(params: player.params)],
          eagerError: true)
      .timeout(const Duration(seconds: 25));
}
