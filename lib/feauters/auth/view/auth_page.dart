import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watchparty/core/localization/app_locale_controller.dart';
import 'package:watchparty/core/theme/party_theme.dart';
import 'package:watchparty/services/auth_service.dart';
import 'package:watchparty/shared/party_ui.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _guestMode = true;
  bool _loading = false;
  bool _hidden = true;
  Country? _country;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({bool guest = false}) async {
    FocusScope.of(context).unfocus();
    if ((guest || _register) && _name.text.trim().isEmpty) {
      toast(
          context,
          l(
              context,
              'Sohbette görünecek adını yaz.',
              'Enter a name for the chat.',
              'Введите имя для чата.',
              "Gib einen Namen für den Chat ein.",
              "Escribe un nombre para el chat."));
      return;
    }
    if (!guest && (_email.text.trim().isEmpty || _password.text.length < 6)) {
      toast(
          context,
          l(
              context,
              'E-posta ve en az 6 karakterli bir şifre gir.',
              'Enter your email and a password of at least 6 characters.',
              'Введите почту и пароль от 6 символов.',
              "Gib deine E-Mail-Adresse und ein Passwort mit mindestens 6 Zeichen ein.",
              "Introduce tu correo y una contraseña de al menos 6 caracteres."));
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthService>();
      final language = context.read<AppLocaleController>().languageCode;
      if (guest) {
        await auth.signInAsGuest(
            name: _name.text,
            languageCode: language,
            countryCode: _country?.countryCode ?? '');
      } else if (_register) {
        await auth.register(
            name: _name.text,
            email: _email.text,
            password: _password.text,
            languageCode: language,
            countryCode: _country?.countryCode ?? '');
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      toast(
          context,
          switch (e.code) {
            'invalid-credential' || 'wrong-password' || 'user-not-found' => l(
                context,
                'E-posta veya şifre hatalı.',
                'Email or password is incorrect.',
                'Неверная почта или пароль.',
                "E-Mail-Adresse oder Passwort ist falsch.",
                "El correo o la contraseña no son correctos."),
            'email-already-in-use' => l(
                context,
                'Bu e-posta zaten kayıtlı.',
                'This email is already registered.',
                'Эта почта уже зарегистрирована.',
                "Diese E-Mail-Adresse ist bereits registriert.",
                "Este correo ya está registrado."),
            'operation-not-allowed' => l(
                context,
                'Bu giriş yöntemi şu anda kullanılamıyor.',
                'This sign-in method is unavailable.',
                'Этот способ входа недоступен.',
                "Diese Anmeldemethode ist derzeit nicht verfügbar.",
                "Este método de acceso no está disponible."),
            'network-request-failed' => l(
                context,
                'Bağlantını kontrol edip tekrar dene.',
                'Check your connection and try again.',
                'Проверьте соединение.',
                "Prüfe deine Verbindung und versuche es erneut.",
                "Comprueba tu conexión e inténtalo de nuevo."),
            _ => l(
                context,
                'Giriş yapılamadı. Bilgilerini kontrol et.',
                'Could not sign in. Check your details.',
                'Не удалось войти. Проверьте данные.',
                "Anmeldung fehlgeschlagen. Prüfe deine Angaben.",
                "No se pudo iniciar sesión. Revisa tus datos."),
          });
    } catch (_) {
      if (mounted) {
        toast(
            context,
            l(
                context,
                'Bağlanılamadı. Birazdan tekrar dene.',
                'Could not connect. Please try again.',
                'Не удалось подключиться. Попробуйте ещё раз.',
                "Keine Verbindung. Versuche es gleich noch einmal.",
                "No se pudo conectar. Inténtalo de nuevo."));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_email.text.trim().isEmpty) {
      toast(
          context,
          l(
              context,
              'Önce e-posta adresini yaz.',
              'Enter your email first.',
              'Сначала введите почту.',
              "Gib zuerst deine E-Mail-Adresse ein.",
              "Primero introduce tu correo."));
      return;
    }
    try {
      await FirebaseAuth.instance
          .setLanguageCode(context.read<AppLocaleController>().languageCode);
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _email.text.trim());
      if (mounted) {
        toast(
            context,
            l(
                context,
                'Hesap varsa sıfırlama bağlantısı gönderildi.',
                'If an account exists, a reset link has been sent.',
                'Если аккаунт существует, ссылка отправлена.',
                "Falls ein Konto existiert, wurde ein Link zum Zurücksetzen gesendet.",
                "Si existe una cuenta, se ha enviado un enlace para restablecer la contraseña."));
      }
    } catch (_) {
      if (mounted) {
        toast(
            context,
            l(
                context,
                'E-posta gönderilemedi.',
                'Could not send email.',
                'Не удалось отправить письмо.',
                "Die E-Mail konnte nicht gesendet werden.",
                "No se pudo enviar el correo."));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
                      children: [
                        const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Brand()),
                              LanguageMenu()
                            ]),
                        const SizedBox(height: 30),
                        Eyebrow(l(
                            context,
                            'BİRLİKTE OLMANIN BİR YOLU DA BU.',
                            'A LITTLE CLOSER, WHEREVER YOU ARE.',
                            'БЛИЖЕ ДРУГ К ДРУГУ.',
                            "EIN STÜCK NÄHER. EGAL, WO IHR SEID.",
                            "UN POCO MÁS CERCA, ESTÉS DONDE ESTÉS.")),
                        const SizedBox(height: 12),
                        Text(
                            l(
                                context,
                                'Aynı an.\nAynı heyecan.',
                                'Same moment.\nSame feeling.',
                                'Один момент.\nОбщие эмоции.',
                                "Derselbe Moment.\nDasselbe Gefühl.",
                                "El mismo momento.\nLa misma emoción."),
                            style: const TextStyle(
                                fontFamily: 'InstrumentSerif',
                                fontFamilyFallback: ['PTSerif', 'Manrope'],
                                fontSize: 52,
                                height: 1.03,
                                letterSpacing: -1.2)),
                        const SizedBox(height: 8),
                        Text(
                            l(
                                context,
                                'Bir video aç. Arkadaşını çağır. Gerisi birlikte.',
                                'Pick a video. Invite your person. Share the moment.',
                                'Выберите видео. Позовите друга. Смотрите вместе.',
                                "Such ein Video aus. Lade jemanden ein. Teilt den Moment.",
                                "Elige un video. Invita a alguien. Comparte el momento."),
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.6,
                                color: PartyColors.muted)),
                        const TogetherArtwork(),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                              child: Text(
                                  l(
                                      context,
                                      _guestMode
                                          ? 'Önce tanışalım.'
                                          : _register
                                              ? 'Aramıza katıl'
                                              : 'Yeniden merhaba',
                                      _guestMode
                                          ? 'First, say hello.'
                                          : _register
                                              ? 'Make yourself at home'
                                              : 'Welcome back',
                                      _guestMode
                                          ? 'Давайте знакомиться.'
                                          : _register
                                              ? 'Присоединяйтесь'
                                              : 'С возвращением',
                                      _guestMode
                                          ? 'Lernen wir uns kennen.'
                                          : _register
                                              ? 'Schön, dass du dabei bist'
                                              : 'Willkommen zurück',
                                      _guestMode
                                          ? 'Primero, nos presentamos.'
                                          : _register
                                              ? 'Siéntete como en casa'
                                              : 'Qué bueno verte de nuevo'),
                                  style: const TextStyle(
                                      fontSize: 23,
                                      letterSpacing: -.6,
                                      fontWeight: FontWeight.w800))),
                          TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => setState(() {
                                        _register = !_register;
                                        _guestMode = false;
                                      }),
                              child: Text(l(
                                  context,
                                  _register ? 'Giriş yap' : 'Hesap oluştur',
                                  _register ? 'Sign in' : 'Create account',
                                  _register ? 'Войти' : 'Регистрация',
                                  _register ? 'Anmelden' : 'Konto erstellen',
                                  _register
                                      ? 'Iniciar sesión'
                                      : 'Crear cuenta')))
                        ]),
                        const SizedBox(height: 10),
                        if (_guestMode || _register)
                          TextField(
                              controller: _name,
                              maxLength: 40,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.nickname],
                              decoration: InputDecoration(
                                  counterText: '',
                                  hintText: l(
                                      context,
                                      'Sohbetteki adın',
                                      'Your chat name',
                                      'Ваше имя в чате',
                                      "Dein Name im Chat",
                                      "Tu nombre en el chat"),
                                  prefixIcon: const Icon(Icons.face_outlined))),
                        const SizedBox(height: 10),
                        if (!_guestMode) ...[
                          TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.email],
                              decoration: InputDecoration(
                                  hintText: l(
                                      context,
                                      'E-posta adresin',
                                      'Your email address',
                                      'Ваша почта',
                                      "Deine E-Mail-Adresse",
                                      "Tu correo electrónico"),
                                  prefixIcon: const Icon(
                                      Icons.alternate_email_rounded))),
                          const SizedBox(height: 10),
                          TextField(
                              controller: _password,
                              obscureText: _hidden,
                              autofillHints: [
                                _register
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password
                              ],
                              onSubmitted: (_) {
                                if (!_loading) _submit();
                              },
                              decoration: InputDecoration(
                                  hintText: l(
                                      context,
                                      'Şifren',
                                      'Your password',
                                      'Пароль',
                                      "Dein Passwort",
                                      "Tu contraseña"),
                                  prefixIcon:
                                      const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                      tooltip: l(
                                          context,
                                          'Şifreyi göster / gizle',
                                          'Show / hide password',
                                          'Показать / скрыть пароль',
                                          "Passwort anzeigen / verbergen",
                                          "Mostrar / ocultar contraseña"),
                                      onPressed: () =>
                                          setState(() => _hidden = !_hidden),
                                      icon: Icon(_hidden
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined)))),
                        ],
                        const SizedBox(height: 6),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_guestMode || _register)
                                TextButton.icon(
                                    onPressed: _loading
                                        ? null
                                        : () => showCountryPicker(
                                            context: context,
                                            showPhoneCode: false,
                                            onSelect: (c) =>
                                                setState(() => _country = c)),
                                    icon: Text(_country?.flagEmoji ?? '🌍',
                                        style: const TextStyle(fontSize: 20)),
                                    label: Text(
                                        (_country == null
                                                ? null
                                                : CountryLocalizations.of(
                                                        context)
                                                    ?.countryName(
                                                        countryCode: _country!
                                                            .countryCode)) ??
                                            l(
                                                context,
                                                'Ülkeni seç (isteğe bağlı)',
                                                'Choose country (optional)',
                                                'Страна (необязательно)',
                                                "Land wählen (optional)",
                                                "Elegir país (opcional)"),
                                        overflow: TextOverflow.ellipsis)),
                              if (!_guestMode && !_register)
                                TextButton(
                                    onPressed: _loading ? null : _resetPassword,
                                    child: Text(
                                        l(
                                            context,
                                            'Şifremi unuttum',
                                            'Forgot password?',
                                            'Забыли пароль?',
                                            "Passwort vergessen?",
                                            "¿Olvidaste tu contraseña?"),
                                        style: const TextStyle(fontSize: 11)))
                            ]),
                        const SizedBox(height: 6),
                        PartyButton(
                            label: l(
                                context,
                                _guestMode
                                    ? 'Hadi birlikte izleyelim'
                                    : _register
                                        ? 'Hesabımı oluştur'
                                        : 'Giriş yap',
                                _guestMode
                                    ? 'Let’s watch together'
                                    : _register
                                        ? 'Create my account'
                                        : 'Sign in',
                                _guestMode
                                    ? 'Начнём смотреть вместе'
                                    : _register
                                        ? 'Создать аккаунт'
                                        : 'Войти',
                                _guestMode
                                    ? 'Schauen wir zusammen'
                                    : _register
                                        ? 'Mein Konto erstellen'
                                        : 'Anmelden',
                                _guestMode
                                    ? 'Veamos algo juntos'
                                    : _register
                                        ? 'Crear mi cuenta'
                                        : 'Iniciar sesión'),
                            loading: _loading,
                            onPressed: () => _submit(guest: _guestMode),
                            orange: true),
                        const SizedBox(height: 10),
                        OutlinedButton(
                            onPressed: _loading
                                ? null
                                : () => setState(() {
                                      _guestMode = !_guestMode;
                                      _register = false;
                                    }),
                            child: Text(l(
                                context,
                                _guestMode
                                    ? 'Hesabımla giriş yap'
                                    : 'Misafir olarak devam et',
                                _guestMode
                                    ? 'Sign in to my account'
                                    : 'Continue as a guest',
                                _guestMode
                                    ? 'Войти в аккаунт'
                                    : 'Продолжить как гость',
                                _guestMode
                                    ? 'Bei meinem Konto anmelden'
                                    : 'Als Gast fortfahren',
                                _guestMode
                                    ? 'Entrar en mi cuenta'
                                    : 'Continuar como invitado'))),
                        const SizedBox(height: 14),
                        Text(
                            l(
                                context,
                                'Misafir hesabı bu cihazda kalır. Cihaz değiştirirken kayıtlı hesabını kullan.',
                                'Guest accounts stay on this device. Use an account to switch devices.',
                                'Гостевой аккаунт хранится на этом устройстве.',
                                "Gastkonten bleiben auf diesem Gerät. Mit einem Konto kannst du das Gerät wechseln.",
                                "Las cuentas de invitado se guardan en este dispositivo. Crea una cuenta para usar otros dispositivos."),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: PartyColors.muted,
                                fontSize: 10,
                                height: 1.5)),
                      ])))));
}

class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key});
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
      tooltip: l(context, 'Uygulama dili', 'App language', 'Язык приложения',
          'App-Sprache', 'Idioma de la aplicación'),
      onSelected: context.read<AppLocaleController>().setLanguage,
      itemBuilder: (_) => const [
            PopupMenuItem(value: 'tr', child: Text('Türkçe')),
            PopupMenuItem(value: 'en', child: Text('English')),
            PopupMenuItem(value: 'ru', child: Text('Русский')),
            PopupMenuItem(value: 'de', child: Text('Deutsch')),
            PopupMenuItem(value: 'es', child: Text('Español'))
          ],
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Text(Localizations.localeOf(context).languageCode.toUpperCase(),
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            const Icon(Icons.expand_more, size: 16)
          ])));
}
