import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocaleController extends ChangeNotifier {
  AppLocaleController({this.onLanguageChanged});
  final Future<void> Function(String languageCode)? onLanguageChanged;
  static const _preferenceKey = 'app_language';
  static const supportedLanguageCodes = ['tr', 'en', 'ru', 'de', 'es'];
  static const supportedLocales = [
    Locale('tr'),
    Locale('en'),
    Locale('ru'),
    Locale('de'),
    Locale('es')
  ];
  static const _spanishCountries = {
    'ES',
    '419',
    'MX',
    'AR',
    'BO',
    'CL',
    'CO',
    'CR',
    'CU',
    'DO',
    'EC',
    'SV',
    'GQ',
    'GT',
    'HN',
    'NI',
    'PA',
    'PY',
    'PE',
    'PR',
    'UY',
    'VE'
  };

  Locale _locale = const Locale('en');
  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;

  static String languageForCountry(String countryCode) {
    final country = countryCode.toUpperCase();
    if (country == 'TR') return 'tr';
    if (country == 'RU') return 'ru';
    if (country == 'DE') return 'de';
    return _spanishCountries.contains(country) ? 'es' : 'en';
  }

  static String initialLanguage(List<Locale> deviceLocales) {
    if (deviceLocales.isEmpty) return 'en';
    final locale = deviceLocales.first;
    final country = locale.countryCode;
    if (country != null && country.isNotEmpty) {
      return languageForCountry(country);
    }
    return supportedLanguageCodes.contains(locale.languageCode)
        ? locale.languageCode
        : 'en';
  }

  Future<void> initialize({List<Locale>? deviceLocales}) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_preferenceKey);
    if (saved != null && supportedLanguageCodes.contains(saved)) {
      _locale = Locale(saved);
    } else {
      _locale = Locale(initialLanguage(
          deviceLocales ?? WidgetsBinding.instance.platformDispatcher.locales));
      await prefs.setString(_preferenceKey, languageCode);
    }
  }

  Future<void> setLanguage(String languageCode,
      {bool saveToAccount = true}) async {
    if (!supportedLanguageCodes.contains(languageCode) ||
        languageCode == _locale.languageCode) {
      return;
    }
    _locale = Locale(languageCode);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, languageCode);
    if (saveToAccount) await onLanguageChanged?.call(languageCode);
  }
}
