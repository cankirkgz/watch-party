import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:watchparty/main.dart' as app;
import 'package:watchparty/firebase_options.dart';
import 'package:watchparty/feauters/room/view/watch_room_page.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:watchparty/shared/molecules/inline_youtube_surface.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> until(WidgetTester tester, bool Function() condition,
      {int seconds = 50}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (!condition() && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (!condition()) {
      debugPrint(
          'QA UI text: ${tester.allWidgets.whereType<Text>().map((w) => w.data).whereType<String>().join(' | ')}');
      debugPrint(
          'QA auth session present: ${FirebaseAuth.instance.currentUser != null}');
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await binding.takeScreenshot('failure');
    }
    expect(condition(), true, reason: 'The expected mobile UI did not appear.');
  }

  testWidgets(
      'guest, shared YouTube controls, GPT bubble translation, media and queue',
      (tester) async {
    expect(const bool.fromEnvironment('USE_FIREBASE_EMULATORS'), true,
        reason: 'Run mobile QA with USE_FIREBASE_EMULATORS=true.');
    await app.main();
    await FirebaseAuth.instance.signOut();
    await until(tester,
        () => find.text('Hadi birlikte izleyelim').evaluate().isNotEmpty);
    await tester.enterText(find.byType(TextField).first, 'Can');
    await tester.ensureVisible(find.text('Hadi birlikte izleyelim'));
    await tester.tap(find.text('Hadi birlikte izleyelim'));
    await until(
        tester, () => find.text('İzleme odası aç').evaluate().isNotEmpty);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('home');
    await tester.enterText(find.byType(TextField).first,
        'https://www.youtube.com/watch?v=M7lc1UVf-VE');
    await tester.ensureVisible(find.text('İzleme odası aç'));
    await tester.tap(find.text('İzleme odası aç'));
    await until(tester, () => find.byType(WatchRoomPage).evaluate().isNotEmpty);
    final roomId =
        tester.widget<WatchRoomPage>(find.byType(WatchRoomPage)).roomId;
    debugPrint('MOBILE_QA_ROOM=$roomId');
    await until(tester, () => find.text('Sohbet').evaluate().isNotEmpty);

    final peerApp = await Firebase.initializeApp(
        name: 'qa-peer', options: DefaultFirebaseOptions.currentPlatform);
    final auth = FirebaseAuth.instanceFor(app: peerApp);
    final db = FirebaseFirestore.instanceFor(app: peerApp);
    final storage = FirebaseStorage.instanceFor(app: peerApp);
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST',
        defaultValue: '10.0.2.2');
    await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
    db.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
    await storage.useStorageEmulator(host, 9199, automaticHostMapping: false);
    final peer = (await auth.signInAnonymously()).user!;
    await db.collection('users').doc(peer.uid).set({
      'id': peer.uid,
      'name': 'Anastasia',
      'countryCode': 'RU',
      'preferredLanguage': 'ru',
      'createdAt': FieldValue.serverTimestamp()
    });
    final room = db.collection('rooms').doc(roomId);
    await room.update({
      'participants': FieldValue.arrayUnion([peer.uid])
    });
    await room.collection('presence').doc(peer.uid).set({
      'userId': peer.uid,
      'name': 'Anastasia',
      'countryCode': 'RU',
      'languageCode': 'ru',
      'active': true,
      'lastSeenAt': FieldValue.serverTimestamp()
    });
    final message = {
      'senderId': peer.uid,
      'senderName': 'Anastasia',
      'senderCountry': 'RU',
      'type': 'text',
      'text': 'Этот момент просто невероятный 😂',
      'roomId': roomId,
      'sentAt': FieldValue.serverTimestamp(),
      'languageCode': 'ru',
      'reactions': <String, String>{},
      'videoSeconds': 36.0
    };
    await room.collection('messages').add(message);
    await until(tester, () => find.text('GPT ile çevir').evaluate().isNotEmpty);
    await tester.tap(find.text('GPT ile çevir').first);
    await until(tester, () => find.text('GPT · TR').evaluate().isNotEmpty);
    expect(find.text('Этот момент просто невероятный 😂'), findsOneWidget);
    await binding.takeScreenshot('room-translation');

    final controls = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Herkes için oynat / duraklat');
    await until(
        tester,
        () =>
            controls.evaluate().isNotEmpty &&
            tester.widget<IconButton>(controls).onPressed != null,
        seconds: 70);
    final controller = tester
        .widget<InlineYoutubeSurface>(find.byType(InlineYoutubeSurface))
        .controller;
    await tester.tap(controls);
    await until(
        tester, () => controller.value.playerState == PlayerState.playing);
    expect((await room.get()).data()!['isPlaying'], true);
    await room.update({
      'isPlaying': false,
      'currentTime': 36.0,
      'updatedBy': peer.uid,
      'syncEventId': 'peer-pause',
      'lastUpdatedAt': FieldValue.serverTimestamp()
    });
    await until(
        tester, () => controller.value.playerState == PlayerState.paused);
    await room.update({
      'currentTime': 60.0,
      'syncEventId': 'peer-seek',
      'lastUpdatedAt': FieldValue.serverTimestamp()
    });
    var actual = await controller.currentTime;
    final end = DateTime.now().add(const Duration(seconds: 20));
    while ((actual - 60).abs() > 2 && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 500));
      actual = await controller.currentTime;
    }
    expect((actual - 60).abs(), lessThan(2));

    final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==');
    final media = storage.ref('room_media/$roomId/${peer.uid}/photo.png');
    await media.putData(bytes, SettableMetadata(contentType: 'image/png'));
    await room.collection('messages').add({
      ...message,
      'type': 'image',
      'text': '',
      'mediaUrl': await media.getDownloadURL(),
      'sentAt': FieldValue.serverTimestamp()
    });
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Sıradaki'));
    await until(tester, () => find.text('Ekle').evaluate().isNotEmpty);
    await tester.tap(find.text('Ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).last, 'https://youtu.be/aqz-KE-bpKQ');
    await tester.tap(find.text('Sıraya ekle'));
    await until(tester,
        () => find.text('Dokun, herkes için oynat').evaluate().isNotEmpty);
    expect((await room.get()).data()!['queue'], isNotEmpty);
    await binding.takeScreenshot('queue');
    await tester.tap(find.text('Birlikte'));
    await until(tester, () => find.text('Anastasia').evaluate().isNotEmpty);
    await binding.takeScreenshot('people');
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
