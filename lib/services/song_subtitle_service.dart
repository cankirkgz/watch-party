import 'package:cloud_functions/cloud_functions.dart';

class SongSubtitle {
  const SongSubtitle(this.startMs, this.endMs, this.text);

  final int startMs, endMs;
  final String text;

  static String? at(List<SongSubtitle> cues, int milliseconds) {
    var low = 0;
    var high = cues.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      final cue = cues[mid];
      if (milliseconds < cue.startMs) {
        high = mid;
      } else if (milliseconds >= cue.endMs) {
        low = mid + 1;
      } else {
        return cue.text;
      }
    }
    return null;
  }
}

class SongSubtitleService {
  const SongSubtitleService();

  Future<List<SongSubtitle>> prepare(
      String roomId, String videoId, String language) async {
    final response = await FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('prepareSongSubtitles',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 24)))
        .call<Map<String, dynamic>>({
      'roomId': roomId,
      'videoId': videoId,
      'targetLanguage': language,
    });
    return (response.data['cues'] as List)
        .map((cue) => SongSubtitle((cue['startMs'] as num).toInt(),
            (cue['endMs'] as num).toInt(), cue['text'] as String))
        .toList(growable: false);
  }
}
