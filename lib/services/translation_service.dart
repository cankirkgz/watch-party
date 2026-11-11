import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

class TranslationService {
  final Map<String, String> _cache = {};
  Future<String> translateMessage(
      {required String roomId,
      required String messageId,
      required String targetLanguageCode}) async {
    final key = '$roomId/$messageId/$targetLanguageCode';
    if (_cache.containsKey(key)) return _cache[key]!;
    final response = await FirebaseFunctions.instanceFor(region: 'europe-west1')
        .httpsCallable('translateMessage',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)))
        .call<Map<String, dynamic>>({
      'roomId': roomId,
      'messageId': messageId,
      'targetLanguage': targetLanguageCode
    });
    final translated = response.data['text'] as String;
    _cache[key] = translated;
    return translated;
  }

  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<String> detectLanguage(String text, {String fallback = 'en'}) async {
    if (!isSupported || text.trim().length < 3) return fallback;
    final identifier = LanguageIdentifier(confidenceThreshold: 0.35);
    try {
      final code = await identifier.identifyLanguage(text);
      return code == 'und' ? fallback : code.split('-').first;
    } catch (_) {
      return fallback;
    } finally {
      await identifier.close();
    }
  }

  Future<String> translate({
    required String text,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    if (text.trim().isEmpty || sourceLanguageCode == targetLanguageCode) {
      return text;
    }
    if (!isSupported) {
      throw UnsupportedError('Translation is available on Android and iOS.');
    }

    final source = _language(sourceLanguageCode);
    final target = _language(targetLanguageCode);
    await Future.wait([
      _modelManager.downloadModel(source.bcpCode, isWifiRequired: false),
      _modelManager.downloadModel(target.bcpCode, isWifiRequired: false),
    ]);

    final translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );
    try {
      return await translator.translateText(text);
    } finally {
      await translator.close();
    }
  }

  TranslateLanguage _language(String code) {
    for (final language in TranslateLanguage.values) {
      if (language.bcpCode == code) return language;
    }
    throw UnsupportedError('Device translation does not support $code.');
  }
}
