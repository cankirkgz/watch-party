import 'dart:io';
import 'dart:ui' as ui;
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchparty/core/localization/app_locale_controller.dart';
import 'package:watchparty/core/theme/party_theme.dart';
import 'package:watchparty/feauters/auth/view/auth_page.dart';
import 'package:watchparty/models/message_model.dart';
import 'package:watchparty/services/translation_service.dart';
import 'package:watchparty/shared/molecules/chat_message_bubble.dart';

const _delegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  CountryLocalizations.delegate
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final manrope = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    final serif = FontLoader('InstrumentSerif')
      ..addFont(rootBundle.load('assets/fonts/InstrumentSerif.ttf'));
    await manrope.load();
    await serif.load();
    await (FontLoader('PTSerif')
          ..addFont(rootBundle.load('assets/fonts/PTSerif.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  for (final item in <(String, String, String)>[
    ('tr', 'GPT ile çevir', 'Metni kopyala'),
    ('en', 'Translate with GPT', 'Copy text'),
    ('ru', 'Перевести с GPT', 'Копировать'),
    ('de', 'Mit GPT übersetzen', 'Text kopieren'),
    ('es', 'Traducir con GPT', 'Copiar texto'),
  ]) {
    testWidgets('message translation and action labels use ${item.$1}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(Provider<TranslationService>(
          create: (_) => TranslationService(),
          child: MaterialApp(
            locale: Locale(item.$1),
            supportedLocales: AppLocaleController.supportedLocales,
            localizationsDelegates: _delegates,
            theme: PartyTheme.dark,
            home: Scaffold(
                body: ChatMessageBubble(
              message: MessageModel(
                  senderId: 'friend',
                  senderName: 'Анастасия',
                  text: 'Этот момент просто невероятный 😂',
                  roomId: 'ABC234',
                  sentAt: DateTime(2026),
                  senderCountry: 'RU'),
              isMine: false,
              targetLanguage: item.$1,
              onReply: (_) {},
            )),
          )));
      await tester.pumpAndSettle();
      expect(find.text(item.$2), findsOneWidget);
      await tester.longPress(find.text('Этот момент просто невероятный 😂'));
      await tester.pumpAndSettle();
      expect(find.text(item.$3), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'language menu changes and persists all five languages before sign-in',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppLocaleController();
    await controller.initialize(deviceLocales: [const Locale('en', 'US')]);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final screenshotKey = GlobalKey();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: controller,
      child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => MaterialApp(
                locale: controller.locale,
                supportedLocales: AppLocaleController.supportedLocales,
                localizationsDelegates: _delegates,
                theme: PartyTheme.light,
                home: RepaintBoundary(
                    key: screenshotKey, child: const AuthPage()),
              )),
    ));
    for (final entry in [
      ('ru', 'Русский', 'Один момент.\nОбщие эмоции.'),
      ('en', 'English', 'Same moment.\nSame feeling.'),
      ('de', 'Deutsch', 'Derselbe Moment.\nDasselbe Gefühl.'),
      ('es', 'Español', 'El mismo momento.\nLa misma emoción.'),
      ('tr', 'Türkçe', 'Aynı an.\nAynı heyecan.')
    ]) {
      await tester.pumpAndSettle();
      await tester.tap(find.byType(LanguageMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.$2));
      await tester.pumpAndSettle();
      expect(find.text(entry.$3), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getString('app_language'),
          entry.$1);
      expect(tester.takeException(), isNull);
      final output = Platform.environment['WATCHPARTY_PREVIEW_DIR'];
      if (output != null) {
        final boundary = screenshotKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File('$output/auth-${entry.$1}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
