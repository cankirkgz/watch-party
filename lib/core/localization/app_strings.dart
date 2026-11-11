import 'package:flutter/widgets.dart';

/// Every UI string must explicitly provide all five supported languages.
String l(BuildContext context, String tr, String en, String ru, String de,
        String es) =>
    switch (Localizations.localeOf(context).languageCode) {
      'tr' => tr,
      'ru' => ru,
      'de' => de,
      'es' => es,
      _ => en,
    };

String guestName(BuildContext context) =>
    l(context, 'Misafir', 'Guest', 'Гость', 'Gast', 'Invitado');
