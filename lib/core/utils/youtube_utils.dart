String? extractYoutubeVideoId(String input) {
  final value = input.trim();
  if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(value)) return value;

  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasAuthority) return null;
  final host = uri.host.toLowerCase().replaceFirst('www.', '');
  String? candidate;

  if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
    candidate = uri.pathSegments.first;
  } else if (host == 'youtube.com' ||
      host == 'm.youtube.com' ||
      host == 'music.youtube.com') {
    candidate = uri.queryParameters['v'];
    if (candidate == null && uri.pathSegments.length >= 2) {
      const supportedPaths = {'shorts', 'embed', 'live'};
      if (supportedPaths.contains(uri.pathSegments.first)) {
        candidate = uri.pathSegments[1];
      }
    }
  }

  return candidate != null && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(candidate)
      ? candidate
      : null;
}

bool isValidYoutubeUrl(String url) => extractYoutubeVideoId(url) != null;
