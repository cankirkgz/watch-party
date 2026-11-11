import 'dart:async';
import 'package:flutter/material.dart';
import 'package:watchparty/core/theme/party_theme.dart';
import 'package:watchparty/services/audio_recorder_service.dart';
import 'package:watchparty/services/voice_room_service.dart';
import 'package:watchparty/shared/molecules/chat_message_bubble.dart';
import 'package:watchparty/shared/party_ui.dart';

class ChatInputBar extends StatefulWidget {
  const ChatInputBar(
      {super.key,
      required this.controller,
      required this.onSendText,
      required this.onPickImage,
      required this.onSendAudio,
      this.isSending = false,
      this.voiceService,
      this.focusNode,
      this.compact = false,
      this.replyTo,
      this.onClearReply});
  final TextEditingController controller;
  final Future<void> Function(String) onSendText;
  final Future<void> Function() onPickImage;
  final Future<void> Function(String, int) onSendAudio;
  final bool isSending, compact;
  final FocusNode? focusNode;
  final VoiceRoomService? voiceService;
  final String? replyTo;
  final VoidCallback? onClearReply;
  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with WidgetsBindingObserver {
  final _recorder = AudioRecorderService();
  bool _recording = false, _paused = false, _working = false, _sending = false;
  final _elapsed = Stopwatch();
  final _levels = <double>[];
  StreamSubscription<dynamic>? _amplitude;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _recording) _record();
  }

  String? _audio;
  int _duration = 0;
  Timer? _timer;

  Future<void> _record() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      if (_recording) {
        final path = await _recorder.stopRecording();
        _timer?.cancel();
        _elapsed.stop();
        await _amplitude?.cancel();
        await widget.voiceService?.endRecording();
        if (mounted) {
          setState(() {
            _recording = false;
            _paused = false;
            _audio = _duration >= 500 ? path : null;
          });
        }
      } else {
        FocusScope.of(context).unfocus();
        await widget.voiceService?.beginRecording();
        final path = await _recorder
            .startRecording(DateTime.now().millisecondsSinceEpoch.toString());
        if (path == null) {
          await widget.voiceService?.endRecording();
          if (mounted) {
            toast(
                context,
                l(
                    context,
                    'Ses kaydı için mikrofon izni gerekli.',
                    'Allow microphone access to record.',
                    'Разрешите доступ к микрофону.',
                    "Erlaube den Mikrofonzugriff zum Aufnehmen.",
                    "Permite el acceso al micrófono para grabar."));
          }
          return;
        }
        if (!mounted) {
          await _recorder.cancelRecording();
          return;
        }
        setState(() {
          _duration = 0;
          _paused = false;
          _levels.clear();
          _recording = true;
        });
        _elapsed
          ..reset()
          ..start();
        _amplitude = _recorder.amplitude.listen((amplitude) {
          if (mounted && !_paused) {
            setState(() {
              _levels.add(
                  ((amplitude.current + 55) / 55).clamp(.06, 1).toDouble());
              if (_levels.length > 24) _levels.removeAt(0);
            });
          }
        });
        _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
          if (mounted) setState(() => _duration = _elapsed.elapsedMilliseconds);
          if (_duration >= 120000) _record();
        });
      }
    } catch (_) {
      _timer?.cancel();
      _elapsed.stop();
      await _amplitude?.cancel();
      try {
        await _recorder.cancelRecording();
      } catch (_) {}
      await widget.voiceService?.endRecording();
      if (mounted) {
        setState(() {
          _recording = false;
          _paused = false;
          _audio = null;
        });
      }
      if (mounted) {
        toast(
            context,
            l(
                context,
                'Ses kaydı başlatılamadı.',
                'Could not record audio.',
                'Не удалось записать аудио.',
                "Audio konnte nicht aufgenommen werden.",
                "No se pudo grabar el audio."));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    _elapsed.stop();
    await _amplitude?.cancel();
    await _recorder.cancelRecording();
    await widget.voiceService?.endRecording();
    if (mounted) {
      setState(() {
        _recording = false;
        _audio = null;
      });
    }
  }

  Future<void> _pause() async {
    if (_working || !_recording) return;
    setState(() => _working = true);
    try {
      if (_paused) {
        await _recorder.resume();
        _elapsed.start();
      } else {
        await _recorder.pause();
        _elapsed.stop();
      }
      if (mounted) setState(() => _paused = !_paused);
    } catch (_) {
      if (mounted) {
        toast(
            context,
            l(
                context,
                'Kayıt durumu değiştirilemedi. Kaydı bitirip tekrar deneyebilirsin.',
                'Could not change recording state. Stop and try again.',
                'Не удалось изменить запись. Остановите и повторите.',
                'Aufnahmestatus konnte nicht geändert werden. Stoppe und versuche es erneut.',
                'No se pudo cambiar la grabación. Detén e inténtalo de nuevo.'));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _send() async {
    if (_sending || widget.isSending) return;
    final text = widget.controller.text.trim();
    if (_audio == null && text.isEmpty) return;
    setState(() => _sending = true);
    try {
      if (_audio != null) {
        await widget.onSendAudio(_audio!, _duration);
        if (mounted) setState(() => _audio = null);
      } else {
        await widget.onSendText(text);
        if (widget.controller.text.trim() == text) widget.controller.clear();
      }
      widget.onClearReply?.call();
    } catch (_) {
      if (mounted) {
        toast(
            context,
            l(
                context,
                'Gönderilemedi. Mesajın burada, tekrar deneyebilirsin.',
                'Could not send. Your message is here; please retry.',
                'Не отправлено. Сообщение сохранено, повторите.',
                "Senden fehlgeschlagen. Deine Nachricht bleibt hier; versuche es erneut.",
                "No se pudo enviar. Tu mensaje sigue aquí; inténtalo de nuevo."));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _releaseRecorder() async {
    await _recorder.dispose();
    await widget.voiceService?.endRecording();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _elapsed.stop();
    _amplitude?.cancel();
    unawaited(_releaseRecorder());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.isSending || _sending || _working;
    return Container(
        decoration: const BoxDecoration(
            color: PartyColors.night,
            border: Border(top: BorderSide(color: Colors.white10))),
        child: SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (widget.replyTo != null && !widget.compact)
                    Row(children: [
                      const Icon(Icons.reply,
                          size: 17, color: PartyColors.lime),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(widget.replyTo!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white54))),
                      IconButton(
                          tooltip: l(
                              context,
                              'Yanıtı iptal et',
                              'Cancel reply',
                              'Отменить ответ',
                              "Antwort abbrechen",
                              "Cancelar respuesta"),
                          onPressed: widget.onClearReply,
                          icon: const Icon(Icons.close, size: 16))
                    ]),
                  if (_recording || _audio != null)
                    Row(children: [
                      IconButton(
                          tooltip: l(
                              context,
                              'Kaydı sil',
                              'Discard recording',
                              'Удалить запись',
                              "Aufnahme verwerfen",
                              "Descartar grabación"),
                          onPressed: busy ? null : _cancel,
                          icon: const Icon(Icons.delete_outline,
                              color: PartyColors.orange)),
                      Expanded(
                          child: _recording
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                      Row(children: [
                                        Icon(
                                            _paused
                                                ? Icons.pause_circle_outline
                                                : Icons.circle,
                                            color: PartyColors.orange,
                                            size: 10),
                                        const SizedBox(width: 6),
                                        Flexible(
                                            child: Text(
                                                '${_paused ? l(context, 'Beklemede', 'Paused', 'Пауза', 'Pausiert', 'En pausa') : l(context, 'Kaydediliyor', 'Recording', 'Запись', 'Aufnahme', 'Grabando')} · ${formatTime(_duration / 1000)} / 2:00',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    color: PartyColors.paper,
                                                    fontSize: 11))),
                                      ]),
                                      const SizedBox(height: 5),
                                      SizedBox(
                                          height: 20,
                                          child: Row(children: [
                                            for (final level in _levels)
                                              Expanded(
                                                  child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 1),
                                                      child: Container(
                                                          height:
                                                              3 + level * 17,
                                                          decoration: BoxDecoration(
                                                              color: _paused
                                                                  ? Colors
                                                                      .white30
                                                                  : PartyColors
                                                                      .lime,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          2))))),
                                          ])),
                                    ])
                              : AudioMessage(
                                  key: ValueKey(_audio),
                                  url: _audio!,
                                  durationMs: _duration,
                                  color: PartyColors.lime)),
                      if (_recording)
                        IconButton(
                            tooltip: _paused
                                ? l(
                                    context,
                                    'Kayda devam et',
                                    'Resume recording',
                                    'Продолжить запись',
                                    'Aufnahme fortsetzen',
                                    'Continuar grabando')
                                : l(
                                    context,
                                    'Kaydı duraklat',
                                    'Pause recording',
                                    'Приостановить запись',
                                    'Aufnahme pausieren',
                                    'Pausar grabación'),
                            onPressed: busy ? null : _pause,
                            icon: Icon(
                                _paused
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded,
                                color: PartyColors.paper)),
                      IconButton.filled(
                          tooltip: _recording
                              ? l(
                                  context,
                                  'Kaydı bitir ve dinle',
                                  'Stop and preview',
                                  'Остановить и прослушать',
                                  "Stoppen und anhören",
                                  "Detener y escuchar")
                              : l(
                                  context,
                                  'Sesli mesajı gönder',
                                  'Send voice note',
                                  'Отправить голосовое',
                                  "Sprachnachricht senden",
                                  "Enviar nota de voz"),
                          onPressed: busy
                              ? null
                              : _recording
                                  ? _record
                                  : _send,
                          icon: Icon(_recording
                              ? Icons.stop_rounded
                              : Icons.arrow_upward_rounded)),
                    ])
                  else
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      IconButton(
                          tooltip: l(context, 'Fotoğraf gönder', 'Send photo',
                              'Отправить фото', "Foto senden", "Enviar foto"),
                          onPressed: busy
                              ? null
                              : () async {
                                  try {
                                    await widget.onPickImage();
                                  } catch (_) {
                                    if (context.mounted) {
                                      toast(
                                          context,
                                          l(
                                              context,
                                              'Fotoğraf gönderilemedi.',
                                              'Could not send photo.',
                                              'Не удалось отправить фото.',
                                              "Foto konnte nicht gesendet werden.",
                                              "No se pudo enviar la foto."));
                                    }
                                  }
                                },
                          icon: const Icon(Icons.add_photo_alternate_outlined,
                              size: 22, color: Colors.white60)),
                      Expanded(
                          child: TextField(
                              key: const Key('chat-message-input'),
                              controller: widget.controller,
                              focusNode: widget.focusNode,
                              minLines: 1,
                              maxLines: widget.compact ? 1 : 4,
                              maxLength: 2000,
                              style: const TextStyle(
                                  fontSize: 13, color: PartyColors.paper),
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                  counterText: '',
                                  label: widget.compact && widget.replyTo != null
                                      ? Text(widget.replyTo!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis)
                                      : null,
                                  suffixIcon: widget.compact && widget.replyTo != null
                                      ? IconButton(
                                          tooltip: l(
                                              context,
                                              'Yanıtı iptal et',
                                              'Cancel reply',
                                              'Отменить ответ',
                                              'Antwort abbrechen',
                                              'Cancelar respuesta'),
                                          onPressed: widget.onClearReply,
                                          icon: const Icon(Icons.close_rounded,
                                              size: 16))
                                      : null,
                                  hintText: l(
                                      context,
                                      'Bir şey söyle…',
                                      'Say something…',
                                      'Напишите что-нибудь…',
                                      "Schreib etwas…",
                                      "Escribe algo…"),
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                              onSubmitted: (_) => _send())),
                      IconButton(
                          tooltip: l(
                              context,
                              'Sesli mesaj kaydet',
                              'Record voice note',
                              'Записать голосовое',
                              "Sprachnachricht aufnehmen",
                              "Grabar nota de voz"),
                          onPressed: busy ? null : _record,
                          icon: const Icon(Icons.mic_none_rounded,
                              size: 22, color: Colors.white60)),
                      ValueListenableBuilder(
                          valueListenable: widget.controller,
                          builder: (_, value, child) => IconButton.filled(
                              tooltip: l(context, 'Gönder', 'Send', 'Отправить',
                                  "Senden", "Enviar"),
                              style: IconButton.styleFrom(
                                  backgroundColor: PartyColors.lime,
                                  foregroundColor: PartyColors.ink),
                              onPressed: !busy && value.text.trim().isNotEmpty
                                  ? _send
                                  : null,
                              icon: busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.arrow_upward_rounded,
                                      size: 22))),
                    ]),
                ]))));
  }
}
