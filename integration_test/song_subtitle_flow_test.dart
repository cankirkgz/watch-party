import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchparty/feauters/home/view/home_page.dart';
import 'package:watchparty/firebase_options.dart';
import 'package:watchparty/main.dart' as app;
import 'package:watchparty/shared/molecules/inline_youtube_surface.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> until(WidgetTester tester, bool Function() condition,
      {required String reason, int seconds = 35}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (!condition() && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(condition(), true, reason: reason);
  }

  testWidgets(
      'room waits for subtitles and shows the local language after seek',
      (tester) async {
    expect(const bool.fromEnvironment('USE_FIREBASE_EMULATORS'), isTrue);
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST',
        defaultValue: '10.0.2.2');
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('app_language', 'ru');
    await preferences.setBool('show_song_subtitles', true);
    await app.main();

    final auth = FirebaseAuth.instance;
    await auth.signOut();
    final hostUser = (await auth.signInAnonymously()).user!;
    final db = FirebaseFirestore.instance;
    await db.collection('users').doc(hostUser.uid).set({
      'name': 'Subtitle QA',
      'preferredLanguage': 'ru',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await until(tester, () => find.byType(HomePage).evaluate().isNotEmpty,
        reason: 'The Russian viewer reaches the home screen');

    final peerApp = await Firebase.initializeApp(
      name: 'subtitle-peer',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final peerAuth = FirebaseAuth.instanceFor(app: peerApp);
    final peerDb = FirebaseFirestore.instanceFor(app: peerApp);
    await peerAuth.useAuthEmulator(host, 9099, automaticHostMapping: false);
    peerDb.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
    final peer = (await peerAuth.signInAnonymously()).user!;
    final suffix = (DateTime.now().microsecondsSinceEpoch % 60466176)
        .toRadixString(36)
        .toUpperCase()
        .padLeft(5, '0');
    final roomCode = 'S$suffix';
    const videoId = 'XTdU5RSodZ4';
    final room = db.collection('rooms').doc(roomCode);
    final peerRoom = peerDb.collection('rooms').doc(roomCode);
    await room.set({
      'videoId': videoId,
      'videoTitle': 'Subtitle QA',
      'createdBy': hostUser.uid,
      'updatedBy': hostUser.uid,
      'participants': [hostUser.uid],
      'currentTime': 0,
      'isPlaying': false,
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'syncEventId': 'initial',
      'queue': [],
    });
    await peerRoom.update({
      'participants': FieldValue.arrayUnion([peer.uid])
    });
    final peerPresence = peerRoom.collection('presence').doc(peer.uid);
    await peerPresence.set({
      'userId': peer.uid,
      'name': 'Peer QA',
      'active': true,
      'lastSeenAt': FieldValue.serverTimestamp(),
    });

    GoRouter.of(tester.element(find.byType(HomePage))).go('/room/$roomCode');
    final waiting = find.byKey(const Key('song-subtitle-wait'));
    final toggle = find.byKey(const Key('song-subtitle-toggle'));
    await until(tester, () => waiting.evaluate().isNotEmpty,
        reason: 'The room shows the preparation state');
    expect(find.byType(InlineYoutubeSurface), findsNothing);
    expect(tester.widget<IconButton>(toggle).onPressed, isNull);
    expect((await room.get()).data()?['isPlaying'], false);
    await peerPresence.update({'subtitlesReadyFor': '$videoId/initial'});

    final firstLine = find.text('Проверка субтитров: начало.');
    await until(tester, () => firstLine.evaluate().isNotEmpty,
        reason:
            'The real callable loads the Russian fixture and starts playback',
        seconds: 70);
    expect(waiting, findsNothing);
    final player = tester
        .widget<InlineYoutubeSurface>(find.byType(InlineYoutubeSurface))
        .controller;
    await until(tester, () => player.value.playerState == PlayerState.playing,
        reason: 'The host automatically starts the prepared video');

    await peerRoom.update({
      'currentTime': 20,
      'isPlaying': false,
      'updatedBy': peer.uid,
      'syncEventId': 'peer-seek',
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
    final secondLine = find.text('Проверка субтитров: перемотка.');
    await until(tester, () => secondLine.evaluate().isNotEmpty,
        reason: 'A seek from another participant changes the active subtitle');
    await tester.tap(toggle);
    await tester.pump();
    expect(secondLine, findsNothing);
    await tester.tap(toggle);
    await tester.pump();
    expect(secondLine, findsOneWidget);
    debugPrint(
        'PASS Russian subtitles, preparation, shared seek and CC toggle');
  });
}
