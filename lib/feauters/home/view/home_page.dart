import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:watchparty/core/theme/party_theme.dart';
import 'package:watchparty/feauters/home/view_model/home_view_model.dart';
import 'package:watchparty/models/user_model.dart';
import 'package:watchparty/services/user_service.dart';
import 'package:watchparty/shared/party_ui.dart';
import 'package:watchparty/feauters/auth/view/auth_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.userId});
  final String userId;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _youtube = TextEditingController();
  UserModel? _profile;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await UserService().getUserById(widget.userId);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}
  }

  @override
  void dispose() {
    _youtube.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = TextEditingController();
    final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (c) => Padding(
            padding: EdgeInsets.fromLTRB(
                24, 12, 24, MediaQuery.viewInsetsOf(c).bottom + 24),
            child: SafeArea(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Eyebrow(l(
                      c,
                      'BİLETİN HAZIR MI?',
                      'GOT YOUR TICKET?',
                      'ЕСТЬ ПРИГЛАШЕНИЕ?',
                      "HAST DU DEIN TICKET?",
                      "¿TIENES TU ENTRADA?")),
                  const SizedBox(height: 12),
                  Text(
                      l(
                          c,
                          'Seni bekleyen bir oda var.',
                          'A room is waiting for you.',
                          'Вас уже ждут.',
                          "Ein Raum wartet auf dich.",
                          "Hay una sala esperándote."),
                      style: const TextStyle(
                          fontFamily: 'InstrumentSerif',
                          fontFamilyFallback: ['PTSerif', 'Manrope'],
                          fontSize: 34)),
                  const SizedBox(height: 8),
                  Text(
                      l(
                          c,
                          'Arkadaşının paylaştığı 6 haneli kodu gir.',
                          'Enter the 6-character code from your friend.',
                          'Введите код из 6 символов от друга.',
                          "Gib den 6-stelligen Code ein, den du bekommen hast.",
                          "Introduce el código de 6 caracteres que te compartieron."),
                      style: const TextStyle(
                          color: PartyColors.muted, fontSize: 13)),
                  const SizedBox(height: 22),
                  TextField(
                      controller: code,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]'))
                      ],
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 9),
                      decoration: const InputDecoration(
                          hintText: 'ABC123', counterText: ''),
                      onSubmitted: (v) {
                        if (v.trim().length == 6) Navigator.pop(c, v);
                      }),
                  const SizedBox(height: 18),
                  ValueListenableBuilder(
                      valueListenable: code,
                      builder: (_, value, child) => PartyButton(
                          label: l(
                              c,
                              'Odaya katıl',
                              'Join room',
                              'Войти в комнату',
                              "Raum beitreten",
                              "Entrar en la sala"),
                          onPressed: value.text.trim().length == 6
                              ? () => Navigator.pop(c, code.text)
                              : null,
                          orange: true)),
                ]))));
    // A sheet's closing animation can still use its controller.
    Future.delayed(const Duration(seconds: 1), code.dispose);
    if (result != null && mounted) {
      context.read<HomeViewModel>().getRoomById(result);
    }
  }

  Future<void> _profilePage() async {
    await context.push('/profile');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: PartyColors.line)),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _nav(
                          Icons.chair_alt_rounded,
                          l(context, 'Birlikte izle', 'Watch together',
                              'Смотреть', "Gemeinsam", "Ver juntos"),
                          () {},
                          true),
                      _nav(
                          Icons.auto_stories_outlined,
                          l(context, 'Rehber', 'Guide', 'Как это работает',
                              "Anleitung", "Guía"),
                          () => context.push('/how-it-works'),
                          false),
                      _nav(
                          Icons.face_outlined,
                          l(context, 'Profilim', 'My profile', 'Профиль',
                              "Mein Profil", "Mi perfil"),
                          _profilePage,
                          false),
                    ]))),
        body: SafeArea(
            child: BlocConsumer<HomeViewModel, HomeViewState>(
          listener: (context, state) async {
            if (state is HomeViewSuccess) {
              context.read<HomeViewModel>().reset();
              FocusScope.of(context).unfocus();
              await context.push('/room/${state.roomId}');
              if (mounted) _load();
            } else if (state is HomeViewError) {
              toast(
                  context,
                  switch (state.message) {
                    'invalid-video' => l(
                        context,
                        'Geçerli bir YouTube bağlantısı gir.',
                        'Enter a valid YouTube link.',
                        'Введите действительную ссылку YouTube.',
                        'Gib einen gültigen YouTube-Link ein.',
                        'Introduce un enlace válido de YouTube.'),
                    'room-not-found' => l(
                        context,
                        'Oda bulunamadı. Kodu kontrol et.',
                        'Room not found. Check the code.',
                        'Комната не найдена. Проверьте код.',
                        'Raum nicht gefunden. Prüfe den Code.',
                        'No se encontró la sala. Comprueba el código.'),
                    'create-failed' => l(
                        context,
                        'Oda oluşturulamadı. Tekrar dene.',
                        'Could not create the room. Try again.',
                        'Не удалось создать комнату. Попробуйте ещё раз.',
                        'Raum konnte nicht erstellt werden. Versuche es erneut.',
                        'No se pudo crear la sala. Inténtalo de nuevo.'),
                    _ => l(
                        context,
                        'Odaya bağlanılamadı. Bağlantını kontrol et.',
                        'Could not join the room. Check your connection.',
                        'Не удалось войти. Проверьте соединение.',
                        'Beitritt fehlgeschlagen. Prüfe deine Verbindung.',
                        'No se pudo entrar en la sala. Comprueba tu conexión.'),
                  });
            }
          },
          builder: (context, state) => Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 570),
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                      children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(child: Brand()),
                              Row(children: [
                                const LanguageMenu(),
                                PartyAvatar(
                                    name: _profile?.name ?? '?',
                                    countryCode: _profile?.countryCode ?? '',
                                    onTap: _profilePage)
                              ])
                            ]),
                        const SizedBox(height: 30),
                        Eyebrow(l(
                            context,
                            'HOŞ GELDİN, ${_profile?.name.toUpperCase() ?? 'ARKADAŞIM'}.',
                            'WELCOME, ${_profile?.name.toUpperCase() ?? 'FRIEND'}.',
                            'ПРИВЕТ, ${_profile?.name.toUpperCase() ?? 'ДРУГ'}.',
                            "WILLKOMMEN, ${_profile?.name.toUpperCase() ?? 'FREUND'}.",
                            "HOLA, ${_profile?.name.toUpperCase() ?? 'AMIGO'}.")),
                        const SizedBox(height: 10),
                        Text(
                            l(
                                context,
                                'Bu akşam\nbirlikte ne izliyoruz?',
                                'What are we\nwatching together?',
                                'Что посмотрим\nвместе сегодня?',
                                "Was schauen wir\nheute zusammen?",
                                "¿Qué vamos a\nver juntos hoy?"),
                            style: const TextStyle(
                                fontFamily: 'InstrumentSerif',
                                fontFamilyFallback: ['PTSerif', 'Manrope'],
                                fontSize: 45,
                                height: 1.03,
                                letterSpacing: -1)),
                        const SizedBox(height: 5),
                        const TogetherArtwork(),
                        const SizedBox(height: 16),
                        Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                                color: PartyColors.ink,
                                borderRadius: BorderRadius.circular(28)),
                            child: Theme(
                                data: PartyTheme.dark,
                                child: Builder(
                                    builder:
                                        (c) => Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(children: [
                                                    const Icon(
                                                        Icons
                                                            .add_circle_outline_rounded,
                                                        color: PartyColors.lime,
                                                        size: 22),
                                                    const SizedBox(width: 9),
                                                    Expanded(
                                                        child: Text(
                                                            l(
                                                                c,
                                                                'Bir oda, birlikte bir an.',
                                                                'One room. A shared moment.',
                                                                'Одна комната. Общий момент.',
                                                                "Ein Raum. Ein gemeinsamer Moment.",
                                                                "Una sala. Un momento compartido."),
                                                            style: const TextStyle(
                                                                color:
                                                                    PartyColors
                                                                        .paper,
                                                                fontSize: 17,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800)))
                                                  ]),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                      l(
                                                          c,
                                                          'YouTube bağlantısını bırak, herkesi aynı ana alalım.',
                                                          'Drop a YouTube link. Get everyone in the same moment.',
                                                          'Вставьте ссылку YouTube. Смотрите синхронно.',
                                                          "Füge einen YouTube-Link ein und schaut gemeinsam los.",
                                                          "Pega un enlace de YouTube y comparte el momento."),
                                                      style: const TextStyle(
                                                          color: Colors.white54,
                                                          fontSize: 12,
                                                          height: 1.6)),
                                                  const SizedBox(height: 18),
                                                  TextField(
                                                      controller: _youtube,
                                                      keyboardType:
                                                          TextInputType.url,
                                                      textInputAction:
                                                          TextInputAction.go,
                                                      autocorrect: false,
                                                      style: const TextStyle(
                                                          color:
                                                              PartyColors.paper,
                                                          fontSize: 13),
                                                      onSubmitted: (_) {
                                                        if (state
                                                            is! HomeViewLoading) {
                                                          context
                                                              .read<
                                                                  HomeViewModel>()
                                                              .createRoom(
                                                                  _youtube.text,
                                                                  widget
                                                                      .userId);
                                                        }
                                                      },
                                                      decoration:
                                                          InputDecoration(
                                                              hintText: l(
                                                                  c,
                                                                  'YouTube bağlantısını yapıştır',
                                                                  'Paste a YouTube link',
                                                                  'Вставьте ссылку YouTube',
                                                                  "YouTube-Link einfügen",
                                                                  "Pega un enlace de YouTube"),
                                                              prefixIcon:
                                                                  const Icon(Icons.link_rounded,
                                                                      color: Colors
                                                                          .white54),
                                                              suffixIcon:
                                                                  IconButton(
                                                                      tooltip: l(
                                                                          c,
                                                                          'Panodan yapıştır',
                                                                          'Paste from clipboard',
                                                                          'Вставить из буфера',
                                                                          "Aus der Zwischenablage einfügen",
                                                                          "Pegar del portapapeles"),
                                                                      icon: const Icon(
                                                                          Icons.content_paste_rounded,
                                                                          size: 18,
                                                                          color: Colors.white54),
                                                                      onPressed: () async {
                                                                        final data =
                                                                            await Clipboard.getData(Clipboard.kTextPlain);
                                                                        if (mounted) {
                                                                          _youtube.text =
                                                                              data?.text ?? '';
                                                                        }
                                                                      }))),
                                                  const SizedBox(height: 12),
                                                  PartyButton(
                                                      label: l(
                                                          c,
                                                          'İzleme odası aç',
                                                          'Start a watch party',
                                                          'Создать комнату',
                                                          "Gemeinsam losschauen",
                                                          "Empezar a ver juntos"),
                                                      loading: state
                                                          is HomeViewLoading,
                                                      onPressed: () => context
                                                          .read<HomeViewModel>()
                                                          .createRoom(
                                                              _youtube.text,
                                                              widget.userId),
                                                      orange: true),
                                                ])))),
                        const SizedBox(height: 14),
                        Material(
                            color: const Color(0xFFE8EADD),
                            borderRadius: BorderRadius.circular(23),
                            child: InkWell(
                                borderRadius: BorderRadius.circular(23),
                                onTap: state is HomeViewLoading ? null : _join,
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 20),
                                    child: Row(children: [
                                      const Icon(
                                          Icons.confirmation_number_outlined,
                                          size: 28),
                                      const SizedBox(width: 14),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(
                                                l(
                                                    context,
                                                    'Davetin mi var?',
                                                    'Have an invitation?',
                                                    'Вас пригласили?',
                                                    "Hast du eine Einladung?",
                                                    "¿Tienes una invitación?"),
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15)),
                                            const SizedBox(height: 3),
                                            Text(
                                                l(
                                                    context,
                                                    'Oda koduyla arkadaşına katıl',
                                                    'Join your friend with a room code',
                                                    'Присоединитесь по коду',
                                                    "Mit einem Raumcode beitreten",
                                                    "Únete con un código de sala"),
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: PartyColors.muted))
                                          ])),
                                      const Icon(Icons.arrow_outward_rounded,
                                          size: 20),
                                    ])))),
                        const SizedBox(height: 25),
                        Row(children: [
                          const Icon(Icons.public_rounded,
                              size: 17, color: PartyColors.muted),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  l(
                                      context,
                                      'Aynı videoda buluş. Kendi dilinde konuş.',
                                      'Meet in the same video. Chat in your language.',
                                      'Смотрите вместе. Общайтесь на своём языке.',
                                      "Dasselbe Video. Gespräche in deiner Sprache.",
                                      "El mismo video. Conversaciones en tu idioma."),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: PartyColors.muted,
                                      height: 1.5)))
                        ]),
                      ]))),
        )),
      );
  Widget _nav(IconData icon, String label, VoidCallback onTap, bool selected) =>
      Expanded(
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon,
                        color:
                            selected ? PartyColors.orange : PartyColors.muted,
                        size: 22),
                    const SizedBox(height: 4),
                    Text(label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 9,
                            color:
                                selected ? PartyColors.ink : PartyColors.muted,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w500))
                  ]))));
}
