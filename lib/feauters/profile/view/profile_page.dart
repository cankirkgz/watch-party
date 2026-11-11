import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:watchparty/core/localization/app_locale_controller.dart';
import 'package:watchparty/core/theme/party_theme.dart';
import 'package:watchparty/services/auth_service.dart';
import 'package:watchparty/services/user_service.dart';
import 'package:watchparty/shared/party_ui.dart';

const translationLanguages = {
  'tr': 'Türkçe',
  'en': 'English',
  'ru': 'Русский',
  'de': 'Deutsch',
  'fr': 'Français',
  'es': 'Español',
  'it': 'Italiano',
  'pt': 'Português',
  'ar': 'العربية',
  'ja': '日本語',
  'ko': '한국어',
  'zh': '中文',
  'uk': 'Українська',
  'nl': 'Nederlands',
  'pl': 'Polski',
  'hi': 'हिन्दी',
  'fa': 'فارسی',
  'id': 'Bahasa Indonesia',
  'az': 'Azərbaycan',
  'el': 'Ελληνικά'
};

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.userId});
  final String userId;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _name = TextEditingController();
  bool _loading = true, _saving = false, _auto = false;
  String _country = '', _target = 'tr';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await UserService().getUserById(widget.userId);
      if (!mounted) return;
      setState(() {
        _name.text = profile?.name ??
            FirebaseAuth.instance.currentUser?.displayName ??
            '';
        _country = profile?.countryCode ?? '';
        _target = profile?.translationLanguage ??
            context.read<AppLocaleController>().languageCode;
        _auto = profile?.autoTranslate ?? false;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      toast(
          context,
          l(context, 'Adını yaz.', 'Enter your name.', 'Введите имя.',
              "Gib deinen Namen ein.", "Escribe tu nombre."));
      return;
    }
    setState(() => _saving = true);
    try {
      await UserService().updateProfile(widget.userId,
          name: _name.text,
          countryCode: _country,
          languageCode: context.read<AppLocaleController>().languageCode,
          translationLanguage: _target,
          autoTranslate: _auto);
      await FirebaseAuth.instance.currentUser
          ?.updateDisplayName(_name.text.trim());
      if (mounted) {
        toast(
            context,
            l(
                context,
                'Profilin güncellendi.',
                'Profile saved.',
                'Профиль сохранён.',
                "Profil gespeichert.",
                "Perfil guardado."));
        context.pop(true);
      }
    } catch (_) {
      if (mounted) {
        toast(
            context,
            l(
                context,
                'Profil kaydedilemedi. Tekrar dene.',
                'Could not save profile. Try again.',
                'Не удалось сохранить профиль.',
                "Profil konnte nicht gespeichert werden. Versuche es erneut.",
                "No se pudo guardar el perfil. Inténtalo de nuevo."));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(l(context, 'Sana ait bir köşe', 'Your little corner',
                'Ваш уголок', "Deine kleine Ecke", "Tu rincón"))),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child:
                        ListView(padding: const EdgeInsets.all(24), children: [
                      Center(
                          child: PartyAvatar(
                              name: _name.text,
                              countryCode: _country,
                              size: 80)),
                      const SizedBox(height: 12),
                      Center(
                          child: Eyebrow(
                              FirebaseAuth.instance.currentUser?.isAnonymous ==
                                      true
                                  ? l(
                                      context,
                                      'MİSAFİR PROFİLİ',
                                      'GUEST PROFILE',
                                      'ГОСТЕВОЙ ПРОФИЛЬ',
                                      "GASTPROFIL",
                                      "PERFIL DE INVITADO")
                                  : l(
                                      context,
                                      'WATCHPARTY PROFİLİN',
                                      'YOUR WATCHPARTY PROFILE',
                                      'ВАШ ПРОФИЛЬ WATCHPARTY',
                                      "DEIN WATCHPARTY-PROFIL",
                                      "TU PERFIL DE WATCHPARTY"))),
                      const SizedBox(height: 32),
                      TextField(
                          controller: _name,
                          maxLength: 40,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                              labelText: l(
                                  context,
                                  'Sohbetteki adın',
                                  'Chat name',
                                  'Имя в чате',
                                  "Name im Chat",
                                  "Nombre en el chat"),
                              counterText: '')),
                      const SizedBox(height: 16),
                      ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(color: PartyColors.line)),
                          leading: Text(flagFor(_country),
                              style: const TextStyle(fontSize: 28)),
                          title: Text(l(context, 'Ülken', 'Your country',
                              'Ваша страна', "Dein Land", "Tu país")),
                          subtitle: Text(_country.isEmpty
                              ? l(context, 'İsteğe bağlı', 'Optional',
                                  'Необязательно', "Optional", "Opcional")
                              : CountryLocalizations.of(context)
                                      ?.countryName(countryCode: _country) ??
                                  _country),
                          trailing: const Icon(Icons.unfold_more_rounded),
                          onTap: () => showCountryPicker(
                              context: context,
                              onSelect: (c) => setState(() => _country = c.countryCode))),
                      const SizedBox(height: 28),
                      Eyebrow(l(
                          context,
                          'KONUŞTUĞUMUZ DİLLER FARKLI OLSA DA.',
                          'SAME CONVERSATION. DIFFERENT LANGUAGES.',
                          'ОДИН РАЗГОВОР. РАЗНЫЕ ЯЗЫКИ.',
                          "EIN GESPRÄCH. VERSCHIEDENE SPRACHEN.",
                          "UNA CONVERSACIÓN. DISTINTOS IDIOMAS.")),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          initialValue:
                              context.read<AppLocaleController>().languageCode,
                          decoration: InputDecoration(
                              labelText: l(
                                  context,
                                  'Uygulama dili',
                                  'App language',
                                  'Язык приложения',
                                  "App-Sprache",
                                  "Idioma de la aplicación")),
                          items: const [
                            DropdownMenuItem(
                                value: 'tr', child: Text('Türkçe')),
                            DropdownMenuItem(
                                value: 'en', child: Text('English')),
                            DropdownMenuItem(
                                value: 'ru', child: Text('Русский')),
                            DropdownMenuItem(
                                value: 'de', child: Text('Deutsch')),
                            DropdownMenuItem(
                                value: 'es', child: Text('Español'))
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              context
                                  .read<AppLocaleController>()
                                  .setLanguage(v);
                            }
                          }),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                          initialValue:
                              translationLanguages.containsKey(_target)
                                  ? _target
                                  : 'en',
                          decoration: InputDecoration(
                              labelText: l(
                                  context,
                                  'Mesajları bu dile çevir',
                                  'Translate messages into',
                                  'Переводить сообщения на',
                                  "Nachrichten übersetzen in",
                                  "Traducir mensajes al")),
                          items: translationLanguages.entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _target = v ?? 'en')),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              l(
                                  context,
                                  'Gelen mesajları otomatik çevir',
                                  'Auto-translate incoming messages',
                                  'Автоперевод входящих сообщений',
                                  "Eingehende Nachrichten automatisch übersetzen",
                                  "Traducir automáticamente los mensajes recibidos"),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              l(
                                  context,
                                  'Açıkken gelen metinler GPT ile çevrilir.',
                                  'New text messages are translated with GPT.',
                                  'Новые сообщения переводятся с GPT.',
                                  "Neue Textnachrichten werden mit GPT übersetzt.",
                                  "Los nuevos mensajes de texto se traducen con GPT."),
                              style: const TextStyle(fontSize: 11)),
                          value: _auto,
                          onChanged: (v) => setState(() => _auto = v)),
                      Text(
                          l(
                              context,
                              'Çevirmeyi seçtiğin metin OpenAI ile işlenir. Fotoğraf ve ses kayıtları çeviri için gönderilmez.',
                              'Text you choose to translate is processed by OpenAI. Photos and voice notes are not sent for translation.',
                              'Выбранный текст обрабатывает OpenAI. Фото и голосовые сообщения не отправляются для перевода.',
                              "Der zur Übersetzung gewählte Text wird von OpenAI verarbeitet. Fotos und Sprachnachrichten werden nicht zur Übersetzung gesendet.",
                              "OpenAI procesa el texto que eliges traducir. Las fotos y notas de voz no se envían para traducir."),
                          style: const TextStyle(
                              fontSize: 11,
                              height: 1.6,
                              color: PartyColors.muted)),
                      const SizedBox(height: 26),
                      PartyButton(
                          label: l(
                              context,
                              'Değişiklikleri kaydet',
                              'Save changes',
                              'Сохранить',
                              "Änderungen speichern",
                              "Guardar cambios"),
                          onPressed: _save,
                          loading: _saving,
                          orange: true,
                          icon: Icons.check_rounded),
                      const SizedBox(height: 18),
                      TextButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                        title: Text(l(
                                            c,
                                            'Çıkış yapılsın mı?',
                                            'Sign out?',
                                            'Выйти?',
                                            "Abmelden?",
                                            "¿Cerrar sesión?")),
                                        content: Text(l(
                                            c,
                                            'Misafir hesaplarına çıkıştan sonra tekrar erişilemeyebilir.',
                                            'You may lose access to a guest account after signing out.',
                                            'После выхода доступ к гостевому аккаунту может быть потерян.',
                                            "Nach dem Abmelden kannst du den Zugriff auf ein Gastkonto verlieren.",
                                            "Podrías perder el acceso a una cuenta de invitado al cerrar sesión.")),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, false),
                                              child: Text(l(
                                                  c,
                                                  'Vazgeç',
                                                  'Cancel',
                                                  'Отмена',
                                                  "Abbrechen",
                                                  "Cancelar"))),
                                          FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, true),
                                              child: Text(l(
                                                  c,
                                                  'Çıkış yap',
                                                  'Sign out',
                                                  'Выйти',
                                                  "Abmelden",
                                                  "Cerrar sesión")))
                                        ]));
                            if (confirmed == true && context.mounted) {
                              await context.read<AuthService>().signOut();
                              if (context.mounted) context.go('/');
                            }
                          },
                          icon: const Icon(Icons.logout, size: 18),
                          label: Text(l(
                              context,
                              'Hesaptan çıkış yap',
                              'Sign out of account',
                              'Выйти из аккаунта',
                              "Vom Konto abmelden",
                              "Cerrar sesión en la cuenta"))),
                    ]))),
      );
}
