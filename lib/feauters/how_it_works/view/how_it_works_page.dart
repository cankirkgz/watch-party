import 'package:flutter/material.dart';
import 'package:watchparty/core/theme/party_theme.dart';
import 'package:watchparty/shared/party_ui.dart';

class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Brand()),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(padding: const EdgeInsets.all(24), children: [
                Eyebrow(l(
                    context,
                    'BİRKAÇ DOKUNUŞTA, YAN YANA.',
                    'A FEW TAPS CLOSER.',
                    'БЛИЖЕ В ПАРУ КАСАНИЙ.',
                    "NUR EIN PAAR TIPPS ENTFERNT.",
                    "MÁS CERCA EN UNOS TOQUES.")),
                const SizedBox(height: 14),
                Text(
                    l(
                        context,
                        'Mesafeyi kapatalım.',
                        'Close the distance.',
                        'Сократим расстояние.',
                        "Überbrückt die Entfernung.",
                        "Acortemos la distancia."),
                    style: const TextStyle(
                        fontFamily: 'InstrumentSerif',
                        fontFamilyFallback: ['PTSerif', 'Manrope'],
                        fontSize: 46)),
                const TogetherArtwork(),
                for (final item in [
                  (
                    Icons.link_rounded,
                    l(context, 'Bir video seç', 'Pick a video',
                        'Выберите видео', "Wähle ein Video", "Elige un video"),
                    l(
                        context,
                        'YouTube bağlantısını ana ekrana yapıştır ve odanı aç.',
                        'Paste a YouTube link on the home screen and open your room.',
                        'Вставьте ссылку YouTube и создайте комнату.',
                        "Füge auf der Startseite einen YouTube-Link ein und öffne deinen Raum.",
                        "Pega un enlace de YouTube en el inicio y abre tu sala.")
                  ),
                  (
                    Icons.confirmation_number_outlined,
                    l(
                        context,
                        'Arkadaşını çağır',
                        'Invite a friend',
                        'Позовите друга',
                        "Lade jemanden ein",
                        "Invita a alguien"),
                    l(
                        context,
                        '6 haneli oda kodunu paylaş. Arkadaşın kodla sana katılsın.',
                        'Share your 6-character code. Your friend joins using the code.',
                        'Отправьте код из 6 символов. Друг войдёт по нему.',
                        "Teile deinen 6-stelligen Code. Damit kann die andere Person beitreten.",
                        "Comparte tu código de 6 caracteres para que otra persona entre.")
                  ),
                  (
                    Icons.sync_rounded,
                    l(
                        context,
                        'Aynı anı yakala',
                        'Share the same moment',
                        'Смотрите синхронно',
                        "Teilt denselben Moment",
                        "Comparte el mismo momento"),
                    l(
                        context,
                        'Oynat, duraklat veya ileri sar: herkesin videosu birlikte hareket eder. Sıraya yeni videolar da ekleyebilirsiniz.',
                        'Play, pause or seek: everyone follows. Add more videos to your shared queue.',
                        'Воспроизведение, пауза и перемотка общие. Добавляйте видео в очередь.',
                        "Abspielen, pausieren oder vorspulen: Alle bleiben synchron. Fügt weitere Videos zur gemeinsamen Warteschlange hinzu.",
                        "Al reproducir, pausar o avanzar, todos siguen el mismo ritmo. Añade más videos a la cola compartida.")
                  ),
                  (
                    Icons.auto_awesome_rounded,
                    l(
                        context,
                        'Kendi dilinde konuş',
                        'Chat in your language',
                        'Общайтесь на своём языке',
                        "Schreib in deiner Sprache",
                        "Chatea en tu idioma"),
                    l(
                        context,
                        'Mesajın altındaki GPT ile çevir düğmesine dokun. Fotoğraf veya sesli mesaj gönder; ses kaydını önce dinle. Bir mesaja basılı tutarak yanıtla ya da tepki ver.',
                        'Tap Translate with GPT below a message. Send photos or preview a voice note before sending. Long-press a message to reply or react.',
                        'Нажмите «Перевести с GPT». Отправляйте фото и голосовые. Удерживайте сообщение для ответа или реакции.',
                        "Tippe unter einer Nachricht auf Mit GPT übersetzen. Sende Fotos oder höre eine Sprachnachricht vor dem Senden an. Halte eine Nachricht gedrückt, um zu antworten oder zu reagieren.",
                        "Pulsa Traducir con GPT debajo de un mensaje. Envía fotos o escucha una nota de voz antes de enviarla. Mantén pulsado un mensaje para responder o reaccionar.")
                  ),
                ].indexed)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 26),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: item.$1.isEven
                                        ? PartyColors.lime
                                        : const Color(0xFFE9B199),
                                    borderRadius: BorderRadius.circular(14)),
                                child: Icon(item.$2.$1, size: 23)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('0${item.$1 + 1}  ${item.$2.$2}',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 6),
                                  Text(item.$2.$3,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: PartyColors.muted,
                                          height: 1.7))
                                ]))
                          ])),
              ]))));
}
