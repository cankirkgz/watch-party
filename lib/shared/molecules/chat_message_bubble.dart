import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:watchparty/core/theme/party_theme.dart';
import 'package:watchparty/core/utils/message_reactions.dart';
import 'package:watchparty/models/message_model.dart';
import 'package:watchparty/services/message_service.dart';
import 'package:watchparty/services/translation_service.dart';
import 'package:watchparty/shared/party_ui.dart';

class ChatMessageBubble extends StatefulWidget {
  const ChatMessageBubble(
      {super.key,
      required this.message,
      required this.isMine,
      this.currentUserId = '',
      this.targetLanguage = 'tr',
      this.autoTranslate = false,
      this.isRead = false,
      this.onReply,
      this.onSeek});
  final MessageModel message;
  final bool isMine, autoTranslate, isRead;
  final String currentUserId, targetLanguage;
  final ValueChanged<MessageModel>? onReply;
  final ValueChanged<double>? onSeek;
  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  String? _translation;
  String _provider = 'GPT';
  bool _busy = false, _show = true;
  @override
  void initState() {
    super.initState();
    if (widget.autoTranslate &&
        !widget.isMine &&
        widget.message.type == MessageType.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _translate(silent: true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ChatMessageBubble old) {
    super.didUpdateWidget(old);
    if (old.targetLanguage != widget.targetLanguage) {
      _translation = null;
      _show = false;
    }
  }

  Future<void> _translate({bool device = false, bool silent = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final service = context.read<TranslationService>();
      final target = widget.targetLanguage;
      final result = device
          ? await service.translate(
              text: widget.message.text,
              sourceLanguageCode: await service.detectLanguage(
                  widget.message.text,
                  fallback: widget.message.languageCode),
              targetLanguageCode: target)
          : await service.translateMessage(
              roomId: widget.message.roomId,
              messageId: widget.message.id,
              targetLanguageCode: target);
      if (mounted && target == widget.targetLanguage) {
        setState(() {
          _translation = result;
          _provider = device ? 'Google · ML Kit' : 'GPT';
          _show = true;
        });
      }
    } catch (_) {
      if (mounted && !silent) {
        toast(
            context,
            l(
                context,
                device
                    ? 'Cihaz çevirisi kullanılamıyor. İnternet bağlantını kontrol et.'
                    : 'GPT şu anda çeviremiyor. Tekrar dene veya mesaja basılı tutup cihazda çevir.',
                device
                    ? 'Device translation unavailable. Check your connection.'
                    : 'GPT is unavailable. Retry, or long-press for device translation.',
                device
                    ? 'Перевод на устройстве недоступен.'
                    : 'GPT недоступен. Повторите или выберите перевод на устройстве.',
                device
                    ? 'Übersetzung auf dem Gerät nicht verfügbar. Prüfe deine Verbindung.'
                    : 'GPT ist nicht verfügbar. Versuche es erneut oder halte die Nachricht für die Geräteübersetzung gedrückt.',
                device
                    ? 'La traducción en el dispositivo no está disponible. Comprueba tu conexión.'
                    : 'GPT no está disponible. Reintenta o mantén pulsado el mensaje para traducir en el dispositivo.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _react(String emoji) async {
    try {
      await context.read<MessageService>().react(
          widget.message.roomId,
          widget.message.id,
          widget.currentUserId,
          widget.message.reactions[widget.currentUserId] == emoji
              ? null
              : emoji);
    } catch (_) {
      if (mounted) {
        toast(
            context,
            l(
                context,
                'Tepki gönderilemedi.',
                'Could not send reaction.',
                'Не удалось отправить реакцию.',
                "Reaktion konnte nicht gesendet werden.",
                "No se pudo enviar la reacción."));
      }
    }
  }

  Future<void> _actions() async {
    var expanded = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
          builder: (c, update) => SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(c).height * .8),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Wrap(alignment: WrapAlignment.center, children: [
                        for (final emoji in expanded
                            ? messageReactions
                            : messageReactions.take(5))
                          IconButton(
                              tooltip: emoji,
                              onPressed: () {
                                Navigator.pop(c);
                                _react(emoji);
                              },
                              icon: Text(emoji,
                                  style: const TextStyle(fontSize: 26))),
                        if (!expanded)
                          IconButton(
                              tooltip: l(
                                  c,
                                  'Daha fazla emoji',
                                  'More reactions',
                                  'Больше реакций',
                                  'Mehr Reaktionen',
                                  'Más reacciones'),
                              onPressed: () => update(() => expanded = true),
                              icon:
                                  const Icon(Icons.add_circle_outline_rounded)),
                      ]),
                      if (widget.onReply != null)
                        ListTile(
                            leading: const Icon(Icons.reply_rounded),
                            title: Text(l(c, 'Yanıtla', 'Reply', 'Ответить',
                                'Antworten', 'Responder')),
                            onTap: () {
                              Navigator.pop(c);
                              widget.onReply!(widget.message);
                            }),
                      if (widget.message.type == MessageType.text) ...[
                        ListTile(
                            leading: const Icon(Icons.auto_awesome_rounded),
                            title: Text(l(
                                c,
                                'GPT ile doğal çeviri',
                                'Translate naturally with GPT',
                                'Перевести с GPT',
                                'Natürlich übersetzen mit GPT',
                                'Traducción natural con GPT')),
                            onTap: () {
                              Navigator.pop(c);
                              _translate();
                            }),
                        if (context.read<TranslationService>().isSupported)
                          ListTile(
                              leading: const Icon(
                                  Icons.download_for_offline_outlined),
                              title: Text(l(
                                  c,
                                  'Cihazda çevir',
                                  'Translate on device',
                                  'Перевести на устройстве',
                                  'Auf dem Gerät übersetzen',
                                  'Traducir en el dispositivo')),
                              subtitle: Text(l(
                                  c,
                                  'Dil modeli ilk kullanımda indirilir',
                                  'Downloads a language model on first use',
                                  'При первом запуске загружается модель',
                                  'Beim ersten Mal wird ein Sprachmodell heruntergeladen',
                                  'Descarga un modelo de idioma la primera vez')),
                              onTap: () {
                                Navigator.pop(c);
                                _translate(device: true);
                              }),
                        ListTile(
                            leading: const Icon(Icons.copy_rounded),
                            title: Text(l(c, 'Metni kopyala', 'Copy text',
                                'Копировать', 'Text kopieren', 'Copiar texto')),
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: widget.message.text));
                              Navigator.pop(c);
                            }),
                      ],
                    ]),
                  ),
                ),
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final foreground = widget.isMine ? PartyColors.ink : PartyColors.paper;
    final muted =
        widget.isMine ? PartyColors.ink.withValues(alpha: .5) : Colors.white38;
    final counts = <String, int>{};
    for (final emoji in m.reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return Align(
        alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 9),
            child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * .79 > 430
                        ? 430
                        : MediaQuery.sizeOf(context).width * .79),
                child: Column(
                    crossAxisAlignment: widget.isMine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (!widget.isMine)
                        Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 5),
                            child: Text(
                                '${flagFor(m.senderCountry)}  ${m.senderName}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white54,
                                    fontWeight: FontWeight.w700))),
                      GestureDetector(
                          onLongPress: _actions,
                          onDoubleTap: () => _react('❤️'),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 9),
                            decoration: BoxDecoration(
                                color: widget.isMine
                                    ? PartyColors.lime
                                    : PartyColors.panel,
                                borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(19),
                                    topRight: const Radius.circular(19),
                                    bottomLeft:
                                        Radius.circular(widget.isMine ? 19 : 4),
                                    bottomRight: Radius.circular(
                                        widget.isMine ? 4 : 19))),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (m.replyToText != null)
                                    Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.only(left: 8),
                                        decoration: const BoxDecoration(
                                            border: Border(
                                                left: BorderSide(
                                                    color: PartyColors.orange,
                                                    width: 2))),
                                        child: Text(
                                            [
                                              if (m.replyToSenderName != null)
                                                m.replyToSenderName!,
                                              m.replyToText!
                                            ].join('\n'),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 11, color: muted))),
                                  if (m.type == MessageType.text)
                                    Text(m.text,
                                        style: TextStyle(
                                            fontSize: 14,
                                            height: 1.5,
                                            color: foreground)),
                                  if (m.type == MessageType.image &&
                                      m.mediaUrl != null)
                                    GestureDetector(
                                        onTap: () => showDialog<void>(
                                            context: context,
                                            builder: (c) => Dialog.fullscreen(
                                                backgroundColor: Colors.black,
                                                child: Stack(children: [
                                                  Center(
                                                      child: InteractiveViewer(
                                                          minScale: .5,
                                                          maxScale: 5,
                                                          child: Image.network(
                                                              m.mediaUrl!,
                                                              errorBuilder: (_,
                                                                      e, s) =>
                                                                  const Icon(Icons
                                                                      .broken_image_outlined)))),
                                                  SafeArea(
                                                      child: IconButton(
                                                          tooltip: l(
                                                              c,
                                                              'Kapat',
                                                              'Close',
                                                              'Закрыть',
                                                              "Schließen",
                                                              "Cerrar"),
                                                          onPressed: () =>
                                                              Navigator.pop(c),
                                                          icon: const Icon(
                                                              Icons.close,
                                                              color: Colors
                                                                  .white)))
                                                ]))),
                                        child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Image.network(m.mediaUrl!,
                                                width: 240,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (_, child,
                                                        progress) =>
                                                    progress == null
                                                        ? child
                                                        : const SizedBox(
                                                            width: 240,
                                                            height: 150,
                                                            child: Center(
                                                                child: CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2))),
                                                errorBuilder: (_, e, s) =>
                                                    const SizedBox(
                                                        width: 240,
                                                        height: 100,
                                                        child: Icon(Icons.broken_image_outlined))))),
                                  if (m.type == MessageType.audio &&
                                      m.mediaUrl != null)
                                    AudioMessage(
                                        url: m.mediaUrl!,
                                        durationMs: m.durationMs ?? 0,
                                        color: foreground),
                                  if (_show && _translation != null) ...[
                                    Divider(
                                        color:
                                            foreground.withValues(alpha: .15),
                                        height: 20),
                                    Text(_translation!,
                                        style: TextStyle(
                                            color: foreground,
                                            fontSize: 14,
                                            height: 1.5)),
                                    const SizedBox(height: 6),
                                    Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.auto_awesome,
                                              size: 10, color: muted),
                                          const SizedBox(width: 4),
                                          Text(
                                              '$_provider · ${widget.targetLanguage.toUpperCase()}',
                                              style: TextStyle(
                                                  fontSize: 9, color: muted))
                                        ]),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (m.videoSeconds != null &&
                                            widget.onSeek != null)
                                          InkWell(
                                              onTap: () => widget
                                                  .onSeek!(m.videoSeconds!),
                                              child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 12,
                                                          top: 3,
                                                          bottom: 3),
                                                  child: Text(
                                                      '▶ ${formatTime(m.videoSeconds!)}',
                                                      style: TextStyle(
                                                          fontSize: 9,
                                                          color: muted)))),
                                        Text(
                                            '${m.sentAt.hour.toString().padLeft(2, '0')}:${m.sentAt.minute.toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                                fontSize: 9, color: muted)),
                                        if (widget.isMine)
                                          Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 5),
                                              child: Tooltip(
                                                  message: widget.isRead
                                                      ? l(
                                                          context,
                                                          'Okundu',
                                                          'Read',
                                                          'Прочитано',
                                                          'Gelesen',
                                                          'Leído')
                                                      : m.hasPendingWrites
                                                          ? l(
                                                              context,
                                                              'Gönderiliyor',
                                                              'Sending',
                                                              'Отправка',
                                                              'Wird gesendet',
                                                              'Enviando')
                                                          : l(
                                                              context,
                                                              'Gönderildi',
                                                              'Sent',
                                                              'Отправлено',
                                                              'Gesendet',
                                                              'Enviado'),
                                                  child: Icon(
                                                      m.hasPendingWrites
                                                          ? Icons
                                                              .schedule_rounded
                                                          : widget.isRead
                                                              ? Icons
                                                                  .done_all_rounded
                                                              : Icons
                                                                  .check_rounded,
                                                      size: 14,
                                                      color: widget.isRead
                                                          ? PartyColors.ink
                                                          : muted))),
                                      ]),
                                ]),
                          )),
                      if (m.type == MessageType.text && !widget.isMine)
                        InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _busy
                                ? null
                                : () {
                                    if (_translation != null) {
                                      setState(() => _show = !_show);
                                    } else {
                                      _translate();
                                    }
                                  },
                            child: Padding(
                                padding: const EdgeInsets.fromLTRB(3, 7, 8, 4),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_busy)
                                        const SizedBox.square(
                                            dimension: 10,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 1.5))
                                      else
                                        const Icon(Icons.auto_awesome_rounded,
                                            size: 11, color: PartyColors.lime),
                                      const SizedBox(width: 5),
                                      Text(
                                          _busy
                                              ? l(
                                                  context,
                                                  'Çevriliyor…',
                                                  'Translating…',
                                                  'Перевод…',
                                                  "Übersetzung…",
                                                  "Traduciendo…")
                                              : _translation == null
                                                  ? l(
                                                      context,
                                                      'GPT ile çevir',
                                                      'Translate with GPT',
                                                      'Перевести с GPT',
                                                      "Mit GPT übersetzen",
                                                      "Traducir con GPT")
                                                  : _show
                                                      ? l(
                                                          context,
                                                          'Çeviriyi gizle',
                                                          'Hide translation',
                                                          'Скрыть перевод',
                                                          "Übersetzung verbergen",
                                                          "Ocultar traducción")
                                                      : l(
                                                          context,
                                                          'Çeviriyi göster',
                                                          'Show translation',
                                                          'Показать перевод',
                                                          "Übersetzung anzeigen",
                                                          "Mostrar traducción"),
                                          style: const TextStyle(
                                              color: PartyColors.lime,
                                              fontSize: 10)),
                                    ]))),
                      if (counts.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                                spacing: 4,
                                children: counts.entries
                                    .map((e) => InkWell(
                                        onTap: () => _react(e.key),
                                        child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                                color: PartyColors.panel,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                    color:
                                                        m.reactions[widget.currentUserId] ==
                                                                e.key
                                                            ? PartyColors.lime
                                                            : Colors.white10)),
                                            child: Text('${e.key} ${e.value}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        PartyColors.paper)))))
                                    .toList())),
                    ]))));
  }
}

String formatTime(double seconds) {
  final d = Duration(seconds: seconds.clamp(0, 864000).floor());
  return '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}

class AudioMessage extends StatefulWidget {
  const AudioMessage(
      {super.key,
      required this.url,
      required this.durationMs,
      required this.color});
  final String url;
  final int durationMs;
  final Color color;
  @override
  State<AudioMessage> createState() => _AudioMessageState();
}

class _AudioMessageState extends State<AudioMessage> {
  final _player = AudioPlayer(
      handleAudioSessionActivation: false, handleInterruptions: false);
  bool _loaded = false, _loading = false;
  Future<void> _toggle() async {
    if (_loading) return;
    try {
      if (!_loaded) {
        setState(() => _loading = true);
        if (widget.url.startsWith('https:') ||
            widget.url.startsWith('http:') ||
            widget.url.startsWith('blob:')) {
          await _player.setUrl(widget.url);
        } else {
          await _player.setFilePath(widget.url);
        }
        _loaded = true;
      }
      if (_player.playing) {
        await _player.pause();
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        unawaited(_player.play().catchError((Object e) {
          if (mounted) {
            toast(
                context,
                l(
                    context,
                    'Ses oynatılamadı.',
                    'Could not play audio.',
                    'Не удалось воспроизвести аудио.',
                    "Audio konnte nicht abgespielt werden.",
                    "No se pudo reproducir el audio."));
          }
        }));
      }
    } catch (_) {
      if (mounted) {
        toast(
            context,
            l(
                context,
                'Ses yüklenemedi.',
                'Could not load audio.',
                'Не удалось загрузить аудио.',
                "Audio konnte nicht geladen werden.",
                "No se pudo cargar el audio."));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      width: 220,
      child: Row(children: [
        StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (_, snapshot) => IconButton(
                tooltip: l(
                    context,
                    'Sesli mesajı oynat / duraklat',
                    'Play / pause voice note',
                    'Воспроизвести / пауза',
                    "Sprachnachricht abspielen / pausieren",
                    "Reproducir / pausar nota de voz"),
                onPressed: _toggle,
                icon: _loading
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                            color: widget.color, strokeWidth: 2))
                    : Icon(
                        snapshot.data?.playing == true &&
                                snapshot.data?.processingState !=
                                    ProcessingState.completed
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: widget.color,
                        size: 30))),
        Expanded(
            child: StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (_, snapshot) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                              value: widget.durationMs > 0
                                  ? ((snapshot.data?.inMilliseconds ?? 0) /
                                          widget.durationMs)
                                      .clamp(0, 1)
                                  : 0,
                              color: widget.color,
                              backgroundColor:
                                  widget.color.withValues(alpha: .16),
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(4)),
                          const SizedBox(height: 8),
                          Text(
                              '${formatTime((snapshot.data?.inMilliseconds ?? 0) / 1000)} / ${formatTime(widget.durationMs / 1000)}',
                              style:
                                  TextStyle(color: widget.color, fontSize: 10)),
                        ]))),
      ]));
}
