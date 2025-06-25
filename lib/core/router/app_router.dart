import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchparty/feauters/enter_name/view/enter_name_page.dart';
import 'package:watchparty/feauters/home/view/home_page.dart';
import 'package:watchparty/feauters/how_it_works/view/how_it_works_page.dart';
import 'package:watchparty/feauters/room/view/watch_room_page.dart';
import 'package:watchparty/feauters/room_created/view/room_created_page.dart';

class AppRouter {
  static GoRouter createRouter(String userId) {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => HomePage(userId: userId),
        ),
        GoRoute(
          path: '/room/:roomId',
          name: 'room',
          builder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            final videoId = state.uri.queryParameters['videoId'] ?? '';
            return WatchRoomPage(roomId: roomId, videoId: videoId);
          },
        ),
        GoRoute(
          path: '/room-created/:roomCode',
          name: 'room-created',
          builder: (context, state) {
            final roomCode = state.pathParameters['roomCode']!;
            final videoId = state.uri.queryParameters['videoId'] ?? '';
            return RoomCreatedPage(roomCode: roomCode, videoId: videoId);
          },
        ),
        GoRoute(
          path: '/enter-name',
          name: 'enter-name',
          builder: (context, state) {
            final roomId = state.uri.queryParameters['roomId'] ?? '';
            final videoId = state.uri.queryParameters['videoId'] ?? '';
            final mode = state.uri.queryParameters['mode'] ?? '';
            return EnterNamePage(roomId: roomId, videoId: videoId, mode: mode);
          },
        ),
        /*GoRoute(
          path: '/join',
          name: 'splash',
          builder: (context, state) {
            final roomId = state.uri.queryParameters['roomId'];
            return SplashPage(roomId: roomId);
          },
        ),*/
        GoRoute(
          path: '/how-it-works',
          name: 'howItWorks',
          builder: (context, state) => const HowItWorksPage(),
        ),
      ],
    );
  }
}
