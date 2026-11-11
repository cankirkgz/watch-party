import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:watchparty/core/localization/app_locale_controller.dart';
import 'package:watchparty/core/theme/party_theme.dart';
import 'package:watchparty/feauters/auth/view/auth_page.dart';
import 'package:watchparty/feauters/how_it_works/view/how_it_works_page.dart';
import 'package:watchparty/models/message_model.dart';
import 'package:watchparty/models/user_model.dart';
import 'package:watchparty/shared/molecules/chat_message_bubble.dart';

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(844, 390)
  ]) {
    for (final language in AppLocaleController.supportedLanguageCodes) {
      testWidgets('auth and guide fit $size in $language', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final locale = AppLocaleController();
        for (final page in [const AuthPage(), const HowItWorksPage()]) {
          await tester.pumpWidget(ChangeNotifierProvider.value(
              value: locale,
              child: MaterialApp(
                  theme: PartyTheme.light,
                  locale: Locale(language),
                  supportedLocales: AppLocaleController.supportedLocales,
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate
                  ],
                  home: page)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
  testWidgets('a long Russian message and timestamp fit a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: PartyTheme.dark,
        home: Scaffold(
            body: ChatMessageBubble(
                message: MessageModel(
                    senderId: 'friend',
                    senderName: 'Анастасия',
                    senderCountry: 'RU',
                    sentAt: DateTime(2026),
                    roomId: 'ABC234',
                    text:
                        'Этот момент просто невероятный 😂 '.padRight(300, '!'),
                    videoSeconds: 123),
                isMine: false,
                onSeek: (_) {},
                currentUserId: 'me'))));
    expect(tester.takeException(), isNull);
    expect(find.text('GPT ile çevir'), findsNothing);
    expect(find.text('Translate with GPT'), findsOneWidget);
  });
  test('legacy profiles keep language and do not invent a country', () {
    final profile = UserModel.fromMap(
        {'id': 'legacy', 'name': 'Can', 'preferredLanguage': 'ru'});
    expect(profile.countryCode, '');
    expect(profile.translationLanguage, 'ru');
    expect(profile.autoTranslate, false);
  });
}
