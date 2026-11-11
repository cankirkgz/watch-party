import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:watchparty/core/theme/party_theme.dart';
import 'package:watchparty/services/voice_room_service.dart';
import 'package:watchparty/shared/party_ui.dart';

class VoiceChatSheet extends StatelessWidget {
  const VoiceChatSheet(
      {super.key,
      required this.service,
      required this.roomId,
      required this.movieVolume,
      required this.onMovieVolume});
  final VoiceRoomService service;
  final String roomId;
  final ValueListenable<double> movieVolume;
  final ValueChanged<double> onMovieVolume;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: service,
        builder: (context, _) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.headphones_rounded,
                        color: PartyColors.lime),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            l(
                                context,
                                'Odanın sesi',
                                'Room voice',
                                'Голосовой чат',
                                'Raumgespräch',
                                'Voz de la sala'),
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: PartyColors.paper))),
                    IconButton(
                        tooltip: l(context, 'Kapat', 'Close', 'Закрыть',
                            'Schließen', 'Cerrar'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                      l(
                          context,
                          'Video devam ederken birlikte konuşun. Katıldığında mikrofonun kapalıdır.',
                          'Talk while the video keeps playing. You join with your microphone off.',
                          'Общайтесь, не останавливая видео. При входе микрофон выключен.',
                          'Sprecht miteinander, während das Video weiterläuft. Dein Mikrofon ist beim Beitritt aus.',
                          'Conversen mientras sigue el video. Entras con el micrófono apagado.'),
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 20),
                  if (service.errorCode != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                            service.errorCode == 'microphone'
                                ? l(
                                    context,
                                    'Mikrofon açılamadı. Uygulamanın mikrofon iznini kontrol et.',
                                    'Could not open the microphone. Check the app’s microphone permission.',
                                    'Не удалось включить микрофон. Проверьте разрешение приложения.',
                                    'Mikrofon nicht verfügbar. Prüfe die Mikrofonberechtigung.',
                                    'No se pudo abrir el micrófono. Revisa el permiso de la aplicación.')
                                : l(
                                    context,
                                    'Sesli sohbete bağlanamadık. Bağlantını kontrol edip tekrar dene. Ücretsiz sunucu kotası doluysa daha sonra katılabilirsin.',
                                    'Could not connect. Check your connection and retry. If the free server allowance is full, try again later.',
                                    'Не удалось подключиться. Проверьте соединение и повторите. Если бесплатная квота исчерпана, попробуйте позже.',
                                    'Keine Verbindung. Prüfe deine Verbindung und versuche es erneut. Bei ausgeschöpftem Freikontingent später erneut versuchen.',
                                    'No se pudo conectar. Revisa tu conexión y reintenta. Si se agotó la cuota gratuita, vuelve más tarde.'),
                            style: const TextStyle(
                                color: PartyColors.orange, fontSize: 12))),
                  if (!service.joined)
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                            key: const Key('join-voice-room'),
                            onPressed: service.busy || service.recording
                                ? null
                                : () => service.join(roomId),
                            icon: service.busy
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.headphones_rounded),
                            label: Text(service.busy
                                ? l(
                                    context,
                                    'Bağlanıyor…',
                                    'Connecting…',
                                    'Подключение…',
                                    'Verbindung…',
                                    'Conectando…')
                                : l(
                                    context,
                                    'Sesli sohbete katıl',
                                    'Join voice chat',
                                    'Войти в голосовой чат',
                                    'Sprachchat beitreten',
                                    'Unirse al chat de voz')))),
                  if (service.joined) ...[
                    Text(
                        service.reconnecting
                            ? l(
                                context,
                                'Yeniden bağlanılıyor…',
                                'Reconnecting…',
                                'Переподключение…',
                                'Verbindung wird wiederhergestellt…',
                                'Reconectando…')
                            : l(
                                context,
                                '${service.people.length} kişi sesli sohbette',
                                '${service.people.length} in voice chat',
                                'В голосовом чате: ${service.people.length}',
                                '${service.people.length} im Sprachchat',
                                '${service.people.length} en el chat de voz'),
                        style: const TextStyle(
                            color: PartyColors.lime,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final person in service.people)
                        Chip(
                            avatar: Icon(
                                person.isMicrophoneEnabled()
                                    ? Icons.mic_rounded
                                    : Icons.mic_off_outlined,
                                size: 16,
                                color: person.isSpeaking
                                    ? PartyColors.lime
                                    : Colors.white54),
                            label: Text(
                                person.name.isEmpty
                                    ? l(context, 'Misafir', 'Guest', 'Гость',
                                        'Gast', 'Invitado')
                                    : person.name,
                                style: TextStyle(
                                    color: person.isSpeaking
                                        ? PartyColors.lime
                                        : PartyColors.paper)),
                            side: BorderSide(
                                color: person.isSpeaking
                                    ? PartyColors.lime
                                    : Colors.white12)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: FilledButton.tonalIcon(
                              key: const Key('voice-microphone'),
                              onPressed: service.busy || service.recording
                                  ? null
                                  : service.toggleMicrophone,
                              icon: Icon(service.microphoneEnabled
                                  ? Icons.mic_rounded
                                  : Icons.mic_off_rounded),
                              label: Text(
                                  service.microphoneEnabled
                                      ? l(
                                          context,
                                          'Mikrofon açık',
                                          'Mic on',
                                          'Микрофон вкл.',
                                          'Mikro an',
                                          'Micro activo')
                                      : l(
                                          context,
                                          'Mikrofon kapalı',
                                          'Mic off',
                                          'Микрофон выкл.',
                                          'Mikro aus',
                                          'Micro apagado'),
                                  style: const TextStyle(fontSize: 12)))),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                          key: const Key('voice-deafen'),
                          tooltip: service.deafened
                              ? l(
                                  context,
                                  'Konuşmaları duy',
                                  'Hear voice chat',
                                  'Включить звук чата',
                                  'Sprachchat hören',
                                  'Escuchar el chat')
                              : l(
                                  context,
                                  'Konuşmaları sessize al',
                                  'Silence voice chat',
                                  'Выключить звук чата',
                                  'Sprachchat stummschalten',
                                  'Silenciar el chat'),
                          onPressed: service.toggleDeafen,
                          icon: Icon(service.deafened
                              ? Icons.headset_off_rounded
                              : Icons.headphones_rounded)),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                          key: const Key('leave-voice-room'),
                          tooltip: l(
                              context,
                              'Sesli sohbetten ayrıl',
                              'Leave voice chat',
                              'Выйти из голосового чата',
                              'Sprachchat verlassen',
                              'Salir del chat de voz'),
                          onPressed: service.leave,
                          icon: const Icon(Icons.call_end_rounded,
                              color: PartyColors.orange)),
                    ]),
                    if (service.recording)
                      Text(
                          l(
                              context,
                              'Sesli mesaj kaydederken canlı mikrofonun beklemede.',
                              'Your live microphone is paused while recording a voice note.',
                              'Во время записи сообщения микрофон чата приостановлен.',
                              'Dein Live-Mikrofon pausiert während der Sprachnachricht.',
                              'Tu micrófono en vivo está en pausa mientras grabas una nota.'),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white54)),
                  ],
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: Colors.white12)),
                  ValueListenableBuilder<double>(
                      valueListenable: movieVolume,
                      builder: (context, value, _) => _volume(context,
                          icon: Icons.movie_outlined,
                          label: l(
                              context,
                              'Video sesi',
                              'Video volume',
                              'Громкость видео',
                              'Videolautstärke',
                              'Volumen del video'),
                          value: value / 100,
                          onChanged: (v) => onMovieVolume(v * 100),
                          sliderKey: 'movie-volume')),
                  _volume(context,
                      icon: service.deafened
                          ? Icons.headset_off_rounded
                          : Icons.spatial_audio_off_rounded,
                      label: l(
                          context,
                          'Konuşma sesi',
                          'Voice volume',
                          'Громкость чата',
                          'Gesprächslautstärke',
                          'Volumen de voces'),
                      value: service.volume,
                      onChanged: service.setVolume,
                      muted: service.deafened,
                      sliderKey: 'voice-volume'),
                  const SizedBox(height: 12),
                  Text(
                      l(
                          context,
                          'Bu ayarlar yalnızca senin sesini değiştirir. Daha temiz ses için kulaklık kullanabilirsin.',
                          'These controls affect only what you hear. Headphones help avoid echo.',
                          'Настройки меняют звук только у вас. Наушники помогают избежать эха.',
                          'Diese Einstellungen ändern nur deinen Ton. Kopfhörer helfen gegen Echo.',
                          'Estos ajustes solo cambian lo que tú escuchas. Los auriculares ayudan a evitar el eco.'),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11, height: 1.5)),
                ]),
          ),
        ),
      );

  Widget _volume(BuildContext context,
          {required IconData icon,
          required String label,
          required double value,
          required ValueChanged<double> onChanged,
          required String sliderKey,
          bool muted = false}) =>
      Column(children: [
        Row(children: [
          Icon(icon, size: 18, color: Colors.white60),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 13, color: PartyColors.paper))),
          Text(
              muted
                  ? l(context, 'Sessiz', 'Muted', 'Без звука', 'Stumm',
                      'Silenciado')
                  : '${(value * 100).round()}%',
              style: const TextStyle(fontSize: 12, color: PartyColors.lime))
        ]),
        Slider(key: Key(sliderKey), value: value, onChanged: onChanged),
      ]);
}
