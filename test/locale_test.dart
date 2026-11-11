import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchparty/core/localization/app_locale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first launch uses the device region before its language', () async {
    for (final scenario in <(Locale, String)>[
      (const Locale('en', 'RU'), 'ru'),
      (const Locale('en', 'DE'), 'de'),
      (const Locale('en', 'TR'), 'tr'),
      (const Locale('en', 'ES'), 'es'),
      (const Locale('en', 'MX'), 'es'),
      (const Locale('en', 'AR'), 'es'),
      (const Locale('en', 'CO'), 'es'),
      (const Locale('ru', 'FR'), 'en'),
      (const Locale('de', 'BR'), 'en'),
      (const Locale('es'), 'es'),
      (const Locale('fr'), 'en'),
    ]) {
      SharedPreferences.setMockInitialValues({});
      final controller = AppLocaleController();
      await controller.initialize(deviceLocales: [scenario.$1]);
      expect(controller.languageCode, scenario.$2, reason: '${scenario.$1}');
      expect((await SharedPreferences.getInstance()).getString('app_language'),
          scenario.$2);
      controller.dispose();
    }
    expect(AppLocaleController.initialLanguage([]), 'en');
  });

  test('saved choice survives relaunch and a different region', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppLocaleController();
    await controller.initialize(deviceLocales: [const Locale('en', 'RU')]);
    await controller.setLanguage('de');
    final reopened = AppLocaleController();
    await reopened.initialize(deviceLocales: [const Locale('en', 'ES')]);
    expect(reopened.languageCode, 'de');
    controller.dispose();
    reopened.dispose();
  });

  test('account preference restore does not write back or trigger a loop',
      () async {
    SharedPreferences.setMockInitialValues({});
    final savedToAccount = <String>[];
    final controller = AppLocaleController(onLanguageChanged: (language) async {
      savedToAccount.add(language);
    });
    await controller.initialize(deviceLocales: [const Locale('en', 'US')]);
    await controller.setLanguage('ru', saveToAccount: false);
    expect(savedToAccount, isEmpty);
    await controller.setLanguage('es');
    expect(savedToAccount, ['es']);
    await controller.setLanguage('invalid');
    expect(controller.languageCode, 'es');
    controller.dispose();
  });
}
