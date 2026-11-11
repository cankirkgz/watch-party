import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchparty/firebase_options.dart';
import 'package:watchparty/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native swipe reply and expanded reaction persist',
      (tester) async {
    Future<void> until(bool Function() ready) async {
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (!ready() && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(ready(), true);
    }

    expect(const bool.fromEnvironment('USE_FIREBASE_EMULATORS'), true);
    await (await SharedPreferences.getInstance())
        .setString('app_language', 'tr');
    await app.main();
    await FirebaseAuth.instance.signOut();
    await until(
        () => find.text('Hadi birlikte izleyelim').evaluate().isNotEmpty);
    await tester.enterText(find.byType(TextField).first, 'Can QA');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Hadi birlikte izleyelim'));
    await tester.tap(find.text('Hadi birlikte izleyelim'));
    await until(() => find.text('İzleme odası aç').evaluate().isNotEmpty);

    final peer = await Firebase.initializeApp(
        name: 'chat-reply-peer',
        options: DefaultFirebaseOptions.currentPlatform);
    final auth = FirebaseAuth.instanceFor(app: peer);
    final db = FirebaseFirestore.instanceFor(app: peer);
    const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST',
        defaultValue: '127.0.0.1');
    await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);
    db.useFirestoreEmulator(host, 8080, automaticHostMapping: false);
    final user = (await auth.signInAnonymously()).user!;
    final room = db.doc('rooms/QA5678');
    await room.set({
      'createdBy': user.uid,
      'participants': [user.uid],
      'videoId': 'XTdU5RSodZ4',
      'videoTitle': 'Chat QA',
      'currentTime': 0,
      'isPlaying': false,
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
      'queue': []
    });
    GoRouter.of(tester.element(find.text('İzleme odası aç')))
        .go('/room/QA5678');
    final input = find.byKey(const Key('chat-message-input'));
    await until(() => input.evaluate().isNotEmpty);
    final incoming = await room.collection('messages').add({
      'senderId': user.uid,
      'senderName': 'Friend QA',
      'text': 'Reply to this message',
      'type': 'text',
      'sentAt': FieldValue.serverTimestamp(),
      'reactions': {}
    });
    await until(() => find.text('Reply to this message').evaluate().isNotEmpty);
    await tester.timedDrag(find.text('Reply to this message'),
        const Offset(130, 0), const Duration(milliseconds: 180));
    await until(() => tester.view.viewInsets.bottom > 100);
    await tester.enterText(input, 'Native reply QA');
    // Let the keyboard layout and the controller's send-button listener rebuild.
    await tester.pump(const Duration(milliseconds: 900));
    final send =
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Gönder');
    expect(tester.widget<IconButton>(send).onPressed, isNotNull);
    await tester.tap(send);
    await until(() =>
        tester.widget<TextField>(input).controller!.text.isEmpty &&
        find.text('Native reply QA').evaluate().isNotEmpty);
    final reply = (await room
            .collection('messages')
            .where('text', isEqualTo: 'Native reply QA')
            .get())
        .docs
        .single;
    expect(reply.data()['replyToMessageId'], incoming.id);
    expect(reply.data()['replyToSenderName'], 'Friend QA');
    debugPrint(
        'PASS native swipe reply is committed with original message and sender');
    FocusManager.instance.primaryFocus?.unfocus();
    await until(() => tester.view.viewInsets.bottom == 0);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.longPress(find.text('Native reply QA'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Daha fazla emoji'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('🍿'));
    await until(() => find.text('🍿 1').evaluate().isNotEmpty);
    final committed =
        await reply.reference.get(const GetOptions(source: Source.server));
    expect((committed.data()!['reactions'] as Map).values, contains('🍿'));
    debugPrint(
        'PASS native expanded emoji reaction is committed through server rules');
    await auth.signOut();
    await peer.delete();
  });
}
