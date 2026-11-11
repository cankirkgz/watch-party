import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchparty/core/theme/party_theme.dart';
import 'package:watchparty/services/voice_room_service.dart';
import 'package:watchparty/models/message_model.dart';
import 'package:watchparty/shared/molecules/chat_message_bubble.dart';
import 'package:watchparty/shared/molecules/swipe_to_reply.dart';
import 'package:watchparty/shared/organisms/voice_chat_sheet.dart';

class _JoinedVoice extends VoiceRoomService {
  @override
  bool get joined => true;
}

void main() {
  for (final language in ['tr', 'en', 'ru', 'de', 'es']) {
    testWidgets('voice controls fit a narrow screen in $language',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final voice = _JoinedVoice(), movie = ValueNotifier<double>(50);
      await tester.pumpWidget(MaterialApp(
          theme: PartyTheme.dark,
          locale: Locale(language),
          supportedLocales: const [
            Locale('tr'),
            Locale('en'),
            Locale('ru'),
            Locale('de'),
            Locale('es')
          ],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!),
          home: Scaffold(
              body: VoiceChatSheet(
                  service: voice,
                  roomId: 'QA2345',
                  movieVolume: movie,
                  onMovieVolume: (v) => movie.value = v))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('voice-microphone')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      voice.dispose();
      movie.dispose();
    });
  }

  testWidgets('a message bubble with its own gestures can be swiped to reply',
      (tester) async {
    var replies = 0;
    await tester.pumpWidget(MaterialApp(
        theme: PartyTheme.dark,
        home: Scaffold(
            body: SwipeToReply(
                onReply: () => replies++,
                child: ChatMessageBubble(
                  message: MessageModel(
                      senderId: 'friend',
                      senderName: 'Friend',
                      roomId: 'QA2345',
                      sentAt: DateTime(2026),
                      text: 'Visible incoming message'),
                  isMine: false,
                  onReply: (_) {},
                )))));
    await tester.drag(
        find.text('Visible incoming message'), const Offset(110, 0));
    await tester.pumpAndSettle();
    expect(replies, 1);
  });

  testWidgets('only a deliberate right swipe replies and the message stays',
      (tester) async {
    var replies = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SwipeToReply(
                onReply: () => replies++,
                child: const SizedBox(
                    width: 300, height: 100, child: Text('Hello'))))));
    await tester.drag(find.text('Hello'), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(replies, 0);
    await tester.drag(find.text('Hello'), const Offset(110, 0));
    await tester.pumpAndSettle();
    expect(replies, 1);
    expect(find.text('Hello'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('movie and voice volumes are independent and opt-in is preserved',
      (tester) async {
    SharedPreferences.setMockInitialValues({'voice_volume': .4});
    final voice = VoiceRoomService(), movie = ValueNotifier<double>(70);
    await tester.pumpWidget(MaterialApp(
        theme: PartyTheme.dark,
        home: Scaffold(
            body: VoiceChatSheet(
                service: voice,
                roomId: 'QA2345',
                movieVolume: movie,
                onMovieVolume: (v) => movie.value = v))));
    await tester.pumpAndSettle();
    expect(voice.joined, false);
    expect(voice.microphoneEnabled, false);
    await tester.tap(find.byKey(const Key('movie-volume')));
    await tester.pumpAndSettle();
    expect(movie.value, closeTo(50, 3));
    expect(voice.volume, .4);
    await tester.tap(find.byKey(const Key('voice-volume')));
    await tester.pumpAndSettle();
    expect(voice.volume, closeTo(.5, .03));
    await voice.toggleDeafen();
    await tester.pumpAndSettle();
    expect(voice.deafened, true);
    expect(movie.value, closeTo(50, 3));
    expect(voice.joined, false);
    await tester.pumpWidget(const SizedBox());
    voice.dispose();
    movie.dispose();
  });
}
