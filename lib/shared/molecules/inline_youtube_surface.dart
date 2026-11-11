import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Keeps the native video inside the room's actual layout, including IME resize.
/// Initialization and playback belong to the room, rather than an overlay portal.
class InlineYoutubeSurface extends StatelessWidget {
  const InlineYoutubeSurface({super.key, required this.controller});
  final YoutubePlayerController controller;

  @override
  Widget build(BuildContext context) {
    PlatformWebViewWidgetCreationParams params =
        PlatformWebViewWidgetCreationParams(
      controller: controller.webViewController.platform,
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      params = AndroidWebViewWidgetCreationParams
          .fromPlatformWebViewWidgetCreationParams(
        params,
        displayWithHybridComposition: true,
      );
    }
    return ColoredBox(
        color: Colors.black,
        child: WebViewWidget.fromPlatformCreationParams(
            key: ValueKey(controller), params: params));
  }
}
