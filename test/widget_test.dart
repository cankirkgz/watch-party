import 'package:flutter_test/flutter_test.dart';
import 'package:watchparty/core/utils/playback_sync.dart';
import 'package:watchparty/core/utils/youtube_utils.dart';

void main() {
  group('YouTube URL parsing', () {
    test('extracts standard watch URLs', () {
      expect(
        extractYoutubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('extracts short, Shorts and embed URLs', () {
      expect(
        extractYoutubeVideoId('https://youtu.be/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
      expect(
        extractYoutubeVideoId(
          'https://youtube.com/shorts/dQw4w9WgXcQ?feature=share',
        ),
        'dQw4w9WgXcQ',
      );
      expect(
        extractYoutubeVideoId('https://youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('rejects unsupported URLs and malformed IDs', () {
      expect(
        extractYoutubeVideoId('https://example.com/watch?v=dQw4w9WgXcQ'),
        isNull,
      );
      expect(
        extractYoutubeVideoId('https://youtube.com/watch?v=short'),
        isNull,
      );
      expect(isValidYoutubeUrl('not a url'), isFalse);
    });
  });

  group('Playback synchronization', () {
    final updateTime = DateTime.utc(2026, 1, 1, 12);

    test('adds server elapsed time while video is playing', () {
      expect(
        calculateTargetPlaybackSeconds(
          storedSeconds: 60,
          isPlaying: true,
          updatedAt: updateTime,
          now: updateTime.add(const Duration(milliseconds: 2500)),
        ),
        62.5,
      );
    });

    test('keeps stored position while paused', () {
      expect(
        calculateTargetPlaybackSeconds(
          storedSeconds: 60,
          isPlaying: false,
          updatedAt: updateTime,
          now: updateTime.add(const Duration(seconds: 20)),
        ),
        60,
      );
    });

    test('never subtracts time for clock skew', () {
      expect(
        calculateTargetPlaybackSeconds(
          storedSeconds: 60,
          isPlaying: true,
          updatedAt: updateTime,
          now: updateTime.subtract(const Duration(seconds: 2)),
        ),
        60,
      );
    });
  });
}
