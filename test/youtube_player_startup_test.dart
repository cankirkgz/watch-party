import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:watchparty/core/utils/youtube_player_startup.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class _Player extends Fake implements YoutubePlayerController {
  final events = StreamController<YoutubePlayerValue>.broadcast();
  final calls = <String>[];
  final initialized = Completer<void>();
  @override
  Stream<YoutubePlayerValue> get stream => events.stream;
  @override
  YoutubePlayerParams get params => const YoutubePlayerParams();
  @override
  Future<void> initWithParams(
      {required YoutubePlayerParams params, String? baseUrl}) async {
    calls.add('init');
    initialized.complete();
  }

  @override
  Future<void> cueVideoById(
      {required String videoId, double? startSeconds, double? endSeconds}) {
    calls.add('cue:$videoId:$startSeconds');
    return initialized.future;
  }

  @override
  Future<void> loadVideoById(
      {required String videoId, double? startSeconds, double? endSeconds}) {
    calls.add('load:$videoId:$startSeconds');
    return initialized.future;
  }
}

void main() {
  test(
      'queues the paused video before init and waits for the actual cued event',
      () async {
    final player = _Player();
    var completed = false;
    final result = initializeEmbeddedVideo(
            player: player,
            videoId: 'XTdU5RSodZ4',
            startSeconds: 26,
            isPlaying: false)
        .then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(player.calls, ['cue:XTdU5RSodZ4:26.0', 'init']);
    expect(completed, false);
    player.events
        .add(YoutubePlayerValue(playerState: PlayerState.unStarted));
    await Future<void>.delayed(Duration.zero);
    expect(completed, false);
    player.events.add(YoutubePlayerValue(playerState: PlayerState.cued));
    await result;
    expect(completed, true);
    await player.events.close();
  });
  test('a late join loads a playing video at the shared position', () async {
    final player = _Player();
    final result = initializeEmbeddedVideo(
        player: player,
        videoId: 'XTdU5RSodZ4',
        startSeconds: 42,
        isPlaying: true);
    player.events
        .add(YoutubePlayerValue(playerState: PlayerState.playing));
    await result;
    expect(player.calls.first, 'load:XTdU5RSodZ4:42.0');
    await player.events.close();
  });
  test('YouTube errors retain their code instead of becoming VPN errors',
      () async {
    final player = _Player();
    final result = initializeEmbeddedVideo(
        player: player,
        videoId: 'XTdU5RSodZ4',
        startSeconds: 0,
        isPlaying: false);
    final failure = expectLater(
        result,
        throwsA(
            isA<YoutubeStartupException>().having((e) => e.code, 'code', 2)));
    player.events
        .add(YoutubePlayerValue(error: YoutubeError.invalidParam));
    await failure;
    expect(player.calls.length, 2);
    await player.events.close();
  });
}
