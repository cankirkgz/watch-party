import 'dart:convert';
import 'package:http/http.dart' as http;

class VideoInfoService {
  Future<String> title(String videoId) async {
    try {
      final response = await http
          .get(Uri.https('www.youtube.com', '/oembed', {
            'url': 'https://www.youtube.com/watch?v=$videoId',
            'format': 'json'
          }))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as Map)['title'] as String;
      }
    } catch (_) {
      /* Metadata is optional; video playback does not depend on oEmbed. */
    }
    return 'YouTube · $videoId';
  }
}
