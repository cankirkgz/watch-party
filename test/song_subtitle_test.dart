import 'package:flutter_test/flutter_test.dart';
import 'package:watchparty/services/song_subtitle_service.dart';

void main() {
  test('uses the current playhead after seeks and clears instrumental gaps',
      () {
    const cues = [
      SongSubtitle(1800, 4200, 'Первая строка'),
      SongSubtitle(5800, 8600, 'Вторая строка'),
    ];
    expect(SongSubtitle.at(cues, 1799), isNull);
    expect(SongSubtitle.at(cues, 1800), 'Первая строка');
    expect(SongSubtitle.at(cues, 4200), isNull);
    expect(SongSubtitle.at(cues, 5800), 'Вторая строка');
    expect(SongSubtitle.at(cues, 8600), isNull);
    expect(SongSubtitle.at(cues, 2000), 'Первая строка');
  });
}
