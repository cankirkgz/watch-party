import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchparty/feauters/auth/view/auth_gate.dart';
import 'package:watchparty/feauters/home/view/home_page.dart';
import 'package:watchparty/feauters/how_it_works/view/how_it_works_page.dart';
import 'package:watchparty/feauters/room/view/watch_room_page.dart';
import 'package:watchparty/feauters/profile/view/profile_page.dart';
import 'package:watchparty/shared/party_ui.dart';

class AppRouter {
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
            path: '/profile',
            builder: (context, state) =>
                AuthGate(builder: (_, user) => ProfilePage(userId: user.uid))),
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) =>
              AuthGate(builder: (_, user) => HomePage(userId: user.uid)),
        ),
        GoRoute(
          path: '/room/:roomId',
          name: 'room',
          builder: (context, state) {
            final roomId = state.pathParameters['roomId']!.toUpperCase();
            final videoId = state.uri.queryParameters['videoId'] ?? '';
            return AuthGate(
              builder: (_, user) => WatchRoomPage(
                roomId: roomId,
                videoId: videoId,
                userId: user.uid,
              ),
            );
          },
        ),
        GoRoute(
          path: '/how-it-works',
          name: 'howItWorks',
          builder: (context, state) => const HowItWorksPage(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
            child: Text(l(
                context,
                'Sayfa bulunamadı.',
                'Page not found.',
                'Страница не найдена.',
                'Seite nicht gefunden.',
                'Página no encontrada.'))),
      ),
    );
  }
}
