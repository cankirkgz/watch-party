import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:watchparty/shared/organisms/voice_chat_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchparty/main.dart' as app;
import 'package:watchparty/firebase_options.dart';
import 'package:watchparty/shared/molecules/inline_youtube_surface.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> until(WidgetTester tester, bool Function() condition,
      {int seconds = 60}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (!condition() && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(condition(), true);
  }

  testWidgets(
      'late join plays, keyboard preserves the composer, visible chat sends read receipts',
      (tester) async {
    expect(const bool.fromEnvironment('USE_FIREBASE_EMULATORS'), true);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('app_language', 'tr');
    await preferences.setBool('voice_deafened', false);
    await preferences.setDouble('voice_volume', 1);
    await preferences.setDouble('movie_volume', 100);
    await app.main();
    await FirebaseAuth.instance.signOut();
    await until(tester,
        () => find.text('Hadi birlikte izleyelim').evaluate().isNotEmpty);
    await tester.enterText(find.byType(TextField).first, 'Can QA');
    await tester.ensureVisible(find.text('Hadi birlikte izleyelim'));
    await tester.tap(find.text('Hadi birlikte izleyelim'));
    await until(
        tester, () => find.text('İzleme odası aç').evaluate().isNotEmpty);

    final peerApp = await Firebase.initializeApp(
        name: 'room-regression-peer',
        options: DefaultFirebaseOptions.currentPlatform);
    final auth = FirebaseAuth.instanceFor(app: peerApp),
        db = FirebaseFirestore.instanceFor(app: peerApp);
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST',
        defaultValue: '10.0.2.2');
    await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
    db.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
    final peer = (await auth.signInAnonymously()).user!;
    final room = db.collection('rooms').doc('QA2345');
    await room.set({
      'videoId': 'XTdU5RSodZ4',
      'videoTitle': 'YouTube · late join regression',
      'createdBy': peer.uid,
      'participants': [peer.uid],
      'currentTime': 0,
      'isPlaying': false,
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'syncEventId': 'initial',
      'queue': []
    });
    await room.update({
      'isPlaying': true,
      'currentTime': 15,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'syncEventId': 'already-playing'
    });
    GoRouter.of(tester.element(find.text('İzleme odası aç')))
        .go('/room/QA2345');
    await until(
        tester, () => find.byType(InlineYoutubeSurface).evaluate().isNotEmpty);
    YoutubePlayerController activePlayer() => tester
        .widget<InlineYoutubeSurface>(find.byType(InlineYoutubeSurface))
        .controller;
    await until(
        tester, () => activePlayer().value.playerState == PlayerState.playing,
        seconds: 90);
    final player = activePlayer();
    expect(await player.duration, greaterThan(60));
    expect(await player.currentTime, greaterThanOrEqualTo(14));
    debugPrint('PASS late join actual YouTube playback');

    await room.update({
      'isPlaying': false,
      'currentTime': 60,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'syncEventId': 'pause-at-60'
    });
    await until(tester, () => player.value.playerState == PlayerState.paused);
    expect((await player.currentTime - 60).abs(), lessThan(3));

    await tester.tap(find.text('Sıradaki'));
    await tester.pump(const Duration(milliseconds: 500));
    final incoming = await room.collection('messages').add({
      'senderId': peer.uid,
      'senderName': 'Friend QA',
      'text': 'Visible incoming message',
      'type': 'text',
      'sentAt': FieldValue.serverTimestamp(),
      'reactions': {},
      'roomId': 'QA2345'
    });
    final mine = FirebaseAuth.instance.currentUser!.uid;
    await tester.pump(const Duration(seconds: 1));
    expect(
        (await room.collection('readReceipts').doc(mine).get()).exists, false);
    await tester.tap(find.text('Sohbet'));
    await until(tester,
        () => find.text('Visible incoming message').evaluate().isNotEmpty);
    String? readId;
    final readSub = room
        .collection('readReceipts')
        .doc(mine)
        .snapshots()
        .listen((s) => readId = s.data()?['messageId'] as String?);
    await until(tester, () => readId == incoming.id);
    debugPrint('PASS visible incoming message receipt');

    await room.update({
      'isPlaying': true,
      'currentTime': 60,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'syncEventId': 'typing-play'
    });
    await until(tester, () => player.value.playerState == PlayerState.playing);
    final input = find.byKey(const Key('chat-message-input'));
    await tester.tap(input);
    await until(tester, () => tester.view.viewInsets.bottom > 100);
    await tester.enterText(input, 'Klavye açıkken yazdığımı görüyorum');
    await tester.pump(const Duration(milliseconds: 700));
    final bottom = tester.getRect(input).bottom;
    final keyboardTop =
        (tester.view.physicalSize.height - tester.view.viewInsets.bottom) /
            tester.view.devicePixelRatio;
    expect(bottom, lessThanOrEqualTo(keyboardTop));
    expect(find.text('Klavye açıkken yazdığımı görüyorum'), findsOneWidget);
    final stage = find.byKey(const Key('room-video-stage'));
    expect(tester.getRect(stage).height, closeTo(200, .1));
    expect(tester.getRect(stage).bottom, lessThan(tester.getRect(input).top));
    expect(
        tester
            .widget<InlineYoutubeSurface>(find.byType(InlineYoutubeSurface))
            .controller,
        same(player));
    final typingTime = await player.currentTime;
    await tester.pump(const Duration(seconds: 3));
    expect(await player.currentTime, greaterThan(typingTime + 1));
    expect(player.value.playerState, PlayerState.playing);
    debugPrint(
        'PASS native video stays visible and playing above actual Android keyboard and input');
    debugPrint('CAPTURE keyboard-visible-input');

    await tester.tap(find
        .byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Gönder'));
    await until(
        tester, () => find.byIcon(Icons.check_rounded).evaluate().isNotEmpty);
    final ownMessages = await room
        .collection('messages')
        .where('senderId', isEqualTo: mine)
        .get();
    final own = ownMessages.docs.single;
    await room.collection('readReceipts').doc(peer.uid).set({
      'messageId': own.id,
      'readThrough': own.data()['sentAt'],
      'updatedAt': FieldValue.serverTimestamp()
    });
    await until(tester,
        () => find.byIcon(Icons.done_all_rounded).evaluate().isNotEmpty);
    debugPrint('PASS double check after peer read');

    FocusManager.instance.primaryFocus?.unfocus();
    await until(tester, () => tester.view.viewInsets.bottom == 0);
    await tester.tap(find
        .byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Tam ekran'));
    await until(tester,
        () => find.byIcon(Icons.fullscreen_exit_rounded).evaluate().isNotEmpty);
    await tester.tap(find.byIcon(Icons.fullscreen_exit_rounded));
    await until(tester, () => find.text('Sohbet').evaluate().isNotEmpty);
    debugPrint('PASS inline/fullscreen keeps native player');
    player.update(error: YoutubeError.notEmbeddable);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Bu videonun sahibi'), findsNothing);
    await until(
        tester,
        () =>
            tester
                .widget<InlineYoutubeSurface>(find.byType(InlineYoutubeSurface))
                .controller !=
            player);
    final recovered = tester
        .widget<InlineYoutubeSurface>(find.byType(InlineYoutubeSurface))
        .controller;
    await until(
        tester, () => recovered.value.playerState == PlayerState.playing,
        seconds: 90);
    debugPrint(
        'PASS transient embedding error recovers automatically without misleading owner warning');

    if (!const bool.fromEnvironment('SKIP_LIVE_VOICE_QA')) {
      await tester.tap(find.byKey(const Key('open-voice-chat')));
      await tester.pump(const Duration(milliseconds: 400));
      final voice =
          tester.widget<VoiceChatSheet>(find.byType(VoiceChatSheet)).service;
      final peerFunctions =
          FirebaseFunctions.instanceFor(app: peerApp, region: 'europe-west1');
      peerFunctions.useFunctionsEmulator(host, 5001,
          automaticHostMapping: false);
      try {
        await peerFunctions
            .httpsCallable('joinVoiceRoom')
            .call({'roomId': 'NOPE12'});
        fail('Non-member room must be denied');
      } on FirebaseFunctionsException catch (e) {
        expect(e.code, 'permission-denied');
      }
      final peerAccess = await peerFunctions
          .httpsCallable('joinVoiceRoom')
          .call<Map<String, dynamic>>({'roomId': 'QA2345'});
      final peerVoice = lk.Room();
      try {
        final beforeVoice = await recovered.currentTime;
        await tester.tap(find.byKey(const Key('join-voice-room')));
        await until(tester, () => voice.joined || voice.errorCode != null,
            seconds: 35);
        expect(voice.errorCode, isNull);
        expect(voice.joined, true);
        debugPrint('PASS voice joined with microphone off');
        expect(voice.microphoneEnabled, false);
        await peerVoice.connect(peerAccess.data['url'] as String,
            peerAccess.data['token'] as String);
        await peerVoice.localParticipant!
            .setMicrophoneEnabled(true)
            .timeout(const Duration(seconds: 15));
        debugPrint('PASS peer microphone published');
        await until(tester, () => voice.people.length == 2, seconds: 20);
        lk.RemoteAudioTrack? remoteTrack;
        await until(tester, () {
          for (final person in voice.people.whereType<lk.RemoteParticipant>()) {
            for (final pub in person.audioTrackPublications) {
              if (pub.track is lk.RemoteAudioTrack) {
                remoteTrack = pub.track as lk.RemoteAudioTrack;
              }
            }
          }
          return remoteTrack != null;
        }, seconds: 20);
        await tester.pump(const Duration(seconds: 3));
        final stats = await remoteTrack!.getReceiverStats();
        expect(stats!.packetsReceived, greaterThan(0));
        debugPrint('PASS received real remote audio RTP');
        expect(recovered.value.playerState, isNot(PlayerState.paused));
        await until(
            tester, () => recovered.value.playerState == PlayerState.playing,
            seconds: 20);
        expect(await recovered.currentTime, greaterThan(beforeVoice + 2));
        await tester.tap(find.byKey(const Key('voice-microphone')));
        await until(tester, () => voice.microphoneEnabled);
        await voice.setVolume(.35);
        await voice.toggleDeafen();
        expect(voice.deafened, true);
        await tester.pump(const Duration(seconds: 2));
        expect(recovered.value.playerState, isNot(PlayerState.paused));
        await until(
            tester, () => recovered.value.playerState == PlayerState.playing,
            seconds: 20);
        debugPrint('CAPTURE live-voice-and-volume');
        await tester.pump(const Duration(seconds: 2));
        await tester.tap(find.byKey(const Key('leave-voice-room')));
        await until(tester, () => !voice.joined && !voice.busy);
        expect(voice.microphoneEnabled, false);
        expect(recovered.value.playerState, isNot(PlayerState.paused));
        await until(
            tester, () => recovered.value.playerState == PlayerState.playing,
            seconds: 20);
        debugPrint(
            'PASS live cloud voice: member token, two peers, received RTP, mic, independent mute/volume, video uninterrupted, leave');
      } finally {
        await voice.leave();
        await peerVoice.disconnect();
        await peerVoice.dispose();
      }
      await tester.tap(find.byTooltip('Kapat'));
      await until(tester, () => find.byType(VoiceChatSheet).evaluate().isEmpty);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.byTooltip('Sesli mesaj kaydet'));
    await until(
        tester, () => find.byTooltip('Kaydı duraklat').evaluate().isNotEmpty);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Kaydı duraklat'));
    await until(
        tester, () => find.byTooltip('Kayda devam et').evaluate().isNotEmpty);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Kayda devam et'));
    await tester.pump(const Duration(seconds: 1));
    expect(recovered.value.playerState, PlayerState.playing);
    await tester.tap(find.byTooltip('Kaydı bitir ve dinle'));
    await until(tester,
        () => find.byTooltip('Sesli mesajı gönder').evaluate().isNotEmpty);
    await tester.tap(find.byTooltip('Sesli mesajı oynat / duraklat'));
    await tester.pump(const Duration(seconds: 1));
    expect(recovered.value.playerState, PlayerState.playing);
    expect(find.text('Ses yüklenemedi.'), findsNothing);
    debugPrint('CAPTURE voice-note-preview');
    await tester.tap(find.byTooltip('Kaydı sil'));
    await until(tester,
        () => find.byTooltip('Sesli mesaj kaydet').evaluate().isNotEmpty);
    debugPrint(
        'PASS native voice note pause/resume, local preview and discard keep video playing');

    await tester.ensureVisible(find.text('Visible incoming message'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.timedDrag(find.text('Visible incoming message'),
        const Offset(130, 0), const Duration(milliseconds: 180));
    await tester.pump(const Duration(milliseconds: 400));
    debugPrint('QA_CAPTURE swipe-diagnostic');
    debugPrint(
        'QA swipe reply shown: ${find.textContaining('Friend QA: Visible incoming message').evaluate().isNotEmpty}; focus: ${tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus}');
    await until(tester, () => tester.view.viewInsets.bottom > 100, seconds: 10);
    await tester.enterText(input, 'Swipe reply QA');
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find
        .byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Gönder'));
    await until(
        tester,
        () =>
            tester.widget<TextField>(input).controller!.text.isEmpty &&
            find.text('Swipe reply QA').evaluate().isNotEmpty);
    final reply = await room
        .collection('messages')
        .where('text', isEqualTo: 'Swipe reply QA')
        .get();
    expect(reply.docs.single.data()['replyToMessageId'], incoming.id);
    expect(reply.docs.single.data()['replyToSenderName'], 'Friend QA');
    debugPrint('PASS swipe replies preserve referenced message identity');
    FocusManager.instance.primaryFocus?.unfocus();
    await until(tester, () => tester.view.viewInsets.bottom == 0);
    await tester.longPress(find.text('Swipe reply QA'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Daha fazla emoji'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('🍿'));
    await until(tester, () => find.text('🍿 1').evaluate().isNotEmpty);
    debugPrint('PASS expanded reaction persists through Firestore rules');

    await readSub.cancel();
    await auth.signOut();
    await peerApp.delete();
  });
}
