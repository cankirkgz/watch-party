String? extractYoutubeVideoId(String url) {
  try {
    final uri = Uri.parse(url);
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.first;
    } else if (uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v'];
    }
    return null;
  } catch (e) {
    return null;
  }
}

bool isValidYoutubeUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;

  final host = uri.host;
  final hasVideoId =
      uri.queryParameters.containsKey('v') || uri.pathSegments.isNotEmpty;

  return (host.contains("youtube.com") || host.contains("youtu.be")) &&
      hasVideoId;
}
