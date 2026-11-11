import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:watchparty/core/localization/app_locale_controller.dart';
import 'package:watchparty/core/theme/party_theme.dart';
import 'package:watchparty/core/utils/playback_sync.dart';
import 'package:watchparty/core/utils/youtube_utils.dart';
import 'package:watchparty/core/utils/youtube_player_startup.dart';
import 'package:watchparty/feauters/room/services/room_service.dart';
import 'package:watchparty/models/message_model.dart';
import 'package:watchparty/models/room_model.dart';
import 'package:watchparty/models/user_model.dart';
import 'package:watchparty/services/auth_service.dart';
import 'package:watchparty/services/media_service.dart';
import 'package:watchparty/services/message_service.dart';
import 'package:watchparty/services/song_subtitle_service.dart';
import 'package:watchparty/services/user_service.dart';
import 'package:watchparty/services/voice_room_service.dart';
import 'package:watchparty/shared/organisms/voice_chat_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watchparty/shared/molecules/chat_message_bubble.dart';
import 'package:watchparty/shared/organisms/chat_panel.dart';
import 'package:watchparty/shared/molecules/inline_youtube_surface.dart';
import 'package:watchparty/shared/party_ui.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class WatchRoomPage extends StatefulWidget {
  const WatchRoomPage(
      {super.key,
      required this.roomId,
      required this.videoId,
      required this.userId});
  final String roomId, videoId, userId;
  @override
  State<WatchRoomPage> createState() => _WatchRoomPageState();
}

class _WatchRoomPageState extends State<WatchRoomPage>
    with WidgetsBindingObserver {
  late final RoomService _service;
  late final MessageService _messageService;
  final _chat = TextEditingController();
  final _voice = VoiceRoomService();
  final _movieVolume = ValueNotifier<double>(100);
  final _joinedAt = DateTime.now();
  final _surfaceKey = GlobalKey();
  YoutubePlayerController? _player;
  StreamSubscription<RoomModel>? _roomSub;
  StreamSubscription<YoutubePlayerValue>? _playerSub;
  StreamSubscription<YoutubeVideoState>? _positionSub;
  StreamSubscription<Map<String, DateTime>>? _readSub;
  Map<String, DateTime> _readThrough = {};
  Stream<List<MessageModel>>? _messages;
  Stream<List<Map<String, dynamic>>>? _presence;
  Timer? _heartbeat, _syncTimer, _recoveryTimer;
  int _recoveryAttempts = 0;
  bool _recoveringPlayer = false;
  Future<void> _syncWork = Future.value();
  UserModel? _profile;
  RoomModel? _room;
  String? _error, _handledEvent;
  MessageModel? _reply;
  String _loadedVideo = '';
  String _subtitleVideo = '', _subtitleLanguage = '';
  Future<void>? _subtitleWait;
  Object? _subtitleRequest;
  List<SongSubtitle> _subtitles = const [];
  bool _waitingForSubtitles = false, _showSubtitles = true;
  bool _loadingSubtitles = false, _subtitleLoadFailed = false;
  String? _playbackFailure;
  bool _fullscreen = false, _startingPlayer = false;
  bool _retrying = false;
  DateTime? _playerGestureAt;
  int _tab = 0;
  double _position = 0, _duration = 0;
  double _unmutedMovieVolume = 100;
  double? _dragPosition;
  bool _playing = false,
      _ready = false,
      _sendingMedia = false,
      _changing = false,
      _muted = false,
      _active = true;
  bool get _online => _room != null && !_room!.isFromCache;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = context.read<RoomService>();
    _messageService = context.read<MessageService>();
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    final room = _room;
    if (room != null && language != _subtitleLanguage) {
      _prepareSubtitles(room.videoId, language, wait: _waitingForSubtitles);
    }
  }

  void _prepareSubtitles(String videoId, String language, {bool wait = true}) {
    final request = Object();
    final room = _room!;
    final event = room.syncEventId;
    final clock = Stopwatch()..start();
    const limit = Duration(seconds: 6);
    _subtitleRequest = request;
    setState(() {
      _subtitleVideo = videoId;
      _subtitleLanguage = language;
      _subtitles = const [];
      _waitingForSubtitles = wait;
      _loadingSubtitles = true;
      _subtitleLoadFailed = false;
    });
    final work = () async {
      var cues = const <SongSubtitle>[];
      var failed = false;
      try {
        cues = await const SongSubtitleService()
            .prepare(widget.roomId, videoId, language);
      } catch (_) {
        failed = true;
      }
      if (!mounted || _subtitleRequest != request) return;
      setState(() {
        _subtitles = cues;
        _loadingSubtitles = false;
        _subtitleLoadFailed = failed;
      });
      if (!wait ||
          !_waitingForSubtitles ||
          !(event == 'initial' ||
              event?.startsWith('subtitle-prepare:') == true)) {
        return;
      }
      final marker = '$videoId/$event';
      try {
        await _service.heartbeat(widget.roomId, _profile!,
            active: _active, subtitlesReadyFor: marker);
        final remaining = limit - clock.elapsed;
        if (cues.isEmpty || remaining <= Duration.zero) return;
        final ready = Completer<void>();
        final subscription = _service
            .presenceStream(widget.roomId, serverOnly: true)
            .listen((people) {
          final now = DateTime.now();
          if (!ready.isCompleted &&
              people.every((person) {
                final seen = person['lastSeenAt'];
                return person['userId'] == widget.userId ||
                    (seen is Timestamp &&
                        now.difference(seen.toDate()) >
                            const Duration(seconds: 55)) ||
                    person['subtitlesReadyFor'] == marker;
              })) {
            ready.complete();
          }
        }, onError: (Object _) {
          if (!ready.isCompleted) ready.complete();
        });
        try {
          await ready.future.timeout(remaining);
        } finally {
          await subscription.cancel();
        }
      } catch (_) {
        // Missing peers or an offline presence stream cannot block playback.
      }
    }();
    _subtitleWait = work.timeout(limit, onTimeout: () {}).whenComplete(() {
      if (mounted && _subtitleRequest == request && _waitingForSubtitles) {
        setState(() => _waitingForSubtitles = false);
      }
    });
  }

  Future<void> _bootstrap() async {
    try {
      final room = await _service.getRoom(widget.roomId);
      if (room == null || room.videoId.isEmpty) {
        throw StateError('room-not-found');
      }
      await _service.addParticipant(widget.roomId, widget.userId);
      final profile = await UserService().getUserById(widget.userId);
      if (!mounted) return;
      _profile = profile ??
          UserModel(
              id: widget.userId,
              name: context.read<AuthService>().currentUser?.displayName ??
                  'Guest',
              createdAt: DateTime.now(),
              preferredLanguage:
                  context.read<AppLocaleController>().languageCode,
              translationLanguage:
                  context.read<AppLocaleController>().languageCode);
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      _movieVolume.value = preferences.getDouble('movie_volume') ?? 100;
      _showSubtitles = preferences.getBool('show_song_subtitles') ?? true;
      _muted = _movieVolume.value == 0;
      if (!_muted) _unmutedMovieVolume = _movieVolume.value;
      _room = room;
      _loadedVideo = room.videoId;
      _position = calculateTargetPlaybackSeconds(
          storedSeconds: room.currentTime,
          isPlaying: room.isPlaying,
          updatedAt: room.lastUpdatedAt ?? DateTime.now());
      _prepareSubtitles(
          room.videoId, context.read<AppLocaleController>().languageCode);
      _createPlayer();
      _readSub =
          _messageService.readReceiptsStream(widget.roomId).listen((receipts) {
        if (mounted) setState(() => _readThrough = receipts);
      }, onError: (Object _) {});
      _messages = _messageService.getMessagesStream(widget.roomId);
      _presence = _service.presenceStream(widget.roomId);
      _roomSub = _service.roomStream(widget.roomId).listen((room) {
        if (!mounted) return;
        final changedVideo = room.videoId != _subtitleVideo ||
            (room.syncEventId != _room?.syncEventId &&
                room.syncEventId?.startsWith('subtitle-prepare:') == true);
        setState(() => _room = room);
        if (changedVideo) {
          _prepareSubtitles(
              room.videoId, context.read<AppLocaleController>().languageCode);
          unawaited(_retryPlayer());
        } else {
          _scheduleSync();
        }
      }, onError: (Object _) {});
      await _beat();
      if (!mounted) return;
      _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) => _beat());
      _syncTimer = Timer.periodic(
          const Duration(seconds: 8), (_) => _scheduleSync(force: true));
      setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _error = l(
            context,
            'Odaya bağlanamadık. Kodu ve internet bağlantını kontrol et.',
            'Could not join the room. Check the code and connection.',
            'Не удалось войти. Проверьте код и соединение.',
            'Beitritt fehlgeschlagen. Prüfe den Code und deine Verbindung.',
            'No se pudo entrar en la sala. Comprueba el código y la conexión.'));
      }
    }
  }

  void _createPlayer() {
    final room = _room!;
    late final YoutubePlayerController player;
    player = YoutubePlayerController(
        key: room.videoId,
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted && _player == player) {
            _handlePlaybackFailure('connection');
          }
        },
        params: YoutubePlayerParams(
            showControls: false,
            showFullscreenButton: false,
            enableKeyboard: false,
            enableCaption: true,
            captionLanguage: _profile!.preferredLanguage,
            pointerEvents: PointerEvents.auto,
            origin: nativeYoutubeAppOrigin));
    _player = player;
    _playerSub = player.listen((value) {
      if (!mounted || _player != player) return;
      final ready = [PlayerState.cued, PlayerState.playing, PlayerState.paused]
          .contains(value.playerState);
      final firstReady = ready && !_ready;
      setState(() {
        _playing = value.playerState == PlayerState.playing;

        if (value.metaData.duration > Duration.zero) {
          _duration = value.metaData.duration.inMilliseconds / 1000;
        }
        if (ready && !value.hasError) {
          _ready = true;
          _playbackFailure = null;
        }
      });
      if (value.hasError) _handlePlaybackFailure('youtube');
      if (ready && !value.hasError) {
        _recoveryTimer?.cancel();
        _recoveringPlayer = false;
        _recoveryAttempts = 0;
      }
      if (firstReady && !_startingPlayer) _scheduleSync(force: true);
      if (_playerGestureAt != null &&
          DateTime.now().difference(_playerGestureAt!) <
              const Duration(seconds: 2) &&
          [PlayerState.playing, PlayerState.paused]
              .contains(value.playerState) &&
          _room?.isPlaying != _playing &&
          !_changing) {
        _playerGestureAt = null;
        unawaited(_control(playing: _playing));
      }
      if (value.playerState == PlayerState.ended &&
          (_room?.isPlaying ?? false) &&
          !_changing) {
        unawaited(_control(playing: false, seconds: _duration));
      }
    });
    _positionSub = player.videoStateStream.listen((value) {
      if (mounted && _player == player) {
        setState(() => _position = value.position.inMilliseconds / 1000);
      }
    });
    unawaited(_initializePlayer(player, room));
  }

  Future<void> _initializePlayer(
      YoutubePlayerController player, RoomModel initial) async {
    if (mounted) setState(() => _startingPlayer = true);
    try {
      while (mounted && _player == player && _waitingForSubtitles) {
        await _subtitleWait;
      }
      if (!mounted || _player != player) return;
      final latest = _room ?? initial;
      final target = calculateTargetPlaybackSeconds(
          storedSeconds: latest.currentTime,
          isPlaying: latest.isPlaying,
          updatedAt: latest.lastUpdatedAt ?? DateTime.now());
      await initializeEmbeddedVideo(
          player: player,
          videoId: latest.videoId,
          startSeconds: target,
          isPlaying: latest.isPlaying);
      if (!mounted || _player != player) return;
      setState(() {
        _ready = true;
        _startingPlayer = false;
        _loadedVideo = latest.videoId;
        if (!_playing) _position = target;
      });
      await _applyMovieVolume(player);
      final current = _room;
      if (mounted &&
          _player == player &&
          current != null &&
          current.videoId == latest.videoId &&
          current.updatedBy == widget.userId &&
          !current.isPlaying &&
          (current.syncEventId?.startsWith('subtitle-prepare:') == true ||
              (current.syncEventId == 'initial' && _subtitles.isNotEmpty))) {
        await _service
            .startPreparedVideo(current, widget.userId)
            .catchError((Object _) {});
      }
      _scheduleSync(force: true);
    } catch (_) {
      if (mounted && _player == player) {
        setState(() => _startingPlayer = false);
        _handlePlaybackFailure(
            player.value.hasError ? 'youtube' : 'connection');
      }
    }
  }

  void _handlePlaybackFailure(String failure) {
    if (!mounted || _recoveryTimer?.isActive == true) return;
    // Two bounded fresh-player attempts also cover transient 101/150 responses.
    // A real owner restriction is respected after those attempts.
    if (_active &&
        _recoveryAttempts < 2 &&
        _player?.value.error != YoutubeError.videoNotFound) {
      final seconds = _recoveryAttempts == 0 ? 1 : 3;
      _recoveryAttempts++;
      setState(() {
        _recoveringPlayer = true;
        _playbackFailure = null;
      });
      _recoveryTimer = Timer(Duration(seconds: seconds), () {
        if (mounted && _active) unawaited(_retryPlayer(resetRecovery: false));
      });
    } else {
      setState(() {
        _recoveringPlayer = false;
        _playbackFailure = failure;
      });
    }
  }

  Future<void> _retryPlayer({bool resetRecovery = true}) async {
    if (!mounted || _retrying || _room == null) {
      return;
    }
    _retrying = true;
    if (resetRecovery) {
      _recoveryTimer?.cancel();
      _recoveryAttempts = 0;
      _recoveringPlayer = false;
    }
    try {
      await _playerSub?.cancel();
      await _positionSub?.cancel();
      if (!mounted) return;
      final old = _player;
      setState(() {
        _ready = false;
        _playing = false;
        _duration = 0;
        _handledEvent = null;
        _playbackFailure = null;
        _loadedVideo = _room!.videoId;
        _createPlayer();
      });
      await old?.close();
    } finally {
      _retrying = false;
    }
  }

  Future<void> _beat() async {
    if (_profile == null || !mounted) return;
    try {
      await _service.heartbeat(widget.roomId, _profile!, active: _active);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _scheduleSync({bool force = false}) {
    final room = _room;
    if (room == null ||
        !_ready ||
        _waitingForSubtitles ||
        _startingPlayer ||
        !_active ||
        room.isFromCache ||
        room.hasPendingWrites) {
      return;
    }
    _syncWork = _syncWork
        .then((_) => _apply(room, force: force))
        .catchError((Object e) {});
  }

  Future<void> _apply(RoomModel room, {bool force = false}) async {
    final player = _player;
    if (!mounted ||
        player == null ||
        !_ready ||
        _waitingForSubtitles ||
        _room?.videoId != room.videoId) {
      return;
    }
    final event = room.syncEventId ?? '${room.currentTime}:${room.isPlaying}';
    if (!force && event == _handledEvent) return;
    _handledEvent = event;
    var target = calculateTargetPlaybackSeconds(
        storedSeconds: room.currentTime,
        isPlaying: room.isPlaying,
        updatedAt: room.lastUpdatedAt ?? DateTime.now());
    if (_loadedVideo == room.videoId && _duration > 0) {
      target = math.min(target, _duration);
    }
    if (_loadedVideo != room.videoId) {
      _recoveryAttempts = 0;
      _recoveryTimer?.cancel();
      _loadedVideo = room.videoId;
      setState(() {
        _position = 0;
        _duration = 0;
      });
      if (room.isPlaying) {
        await player.loadVideoById(videoId: room.videoId, startSeconds: target);
      } else {
        await player.cueVideoById(videoId: room.videoId, startSeconds: target);
      }
      return;
    }
    if (_duration <= 0) {
      final duration = await player.duration;
      if (mounted && duration > 0) setState(() => _duration = duration);
    }
    if (_duration > 0 && (target - _position).abs() > 1.2) {
      await player.seekTo(seconds: target, allowSeekAhead: true);
      if (mounted) setState(() => _position = target);
    }
    if (room.isPlaying && !_playing) {
      await player.playVideo();
    } else if (!room.isPlaying && _playing) {
      await player.pauseVideo();
    }
  }

  Future<void> _control({bool? playing, double? seconds}) async {
    if (_changing ||
        !_online ||
        _player == null ||
        !_ready ||
        _startingPlayer ||
        _waitingForSubtitles) {
      return;
    }
    setState(() => _changing = true);
    final previous = _room;
    final nextPlaying = playing ?? _room?.isPlaying ?? _playing;
    final nextSeconds = (seconds ?? _position)
        .clamp(0.0, _duration > 0 ? _duration : 864000.0)
        .toDouble();
    final event = const Uuid().v4();
    _handledEvent = event;
    try {
      if (seconds != null) {
        await _player!.seekTo(seconds: nextSeconds, allowSeekAhead: true);
      }
      if (nextPlaying) {
        await _player!.playVideo();
      } else {
        await _player!.pauseVideo();
      }
      await _service.setPlaybackState(
          roomId: widget.roomId,
          isPlaying: nextPlaying,
          currentTime: nextSeconds,
          updatedBy: widget.userId,
          syncEventId: event);
    } catch (_) {
      if (mounted) {
        toast(
            context,
            l(
                context,
                'Oynatma komutu gönderilemedi.',
                'Could not sync playback.',
                'Не удалось синхронизировать воспроизведение.',
                "Wiedergabe konnte nicht synchronisiert werden.",
                "No se pudo sincronizar la reproducción."));
        if (previous != null) await _apply(previous, force: true);
      }
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  String? get _replyPreview => _reply == null
      ? null
      : switch (_reply!.type) {
          MessageType.text => _reply!.text,
          MessageType.image =>
            l(context, 'Fotoğraf', 'Photo', 'Фото', 'Foto', 'Foto'),
          MessageType.audio => l(context, 'Sesli mesaj', 'Voice note',
              'Голосовое', 'Sprachnachricht', 'Nota de voz'),
        };

  Future<void> _sendText(String text) =>
      _messageService.sendMessage(MessageModel(
          senderId: widget.userId,
          senderName: _profile!.name,
          senderCountry: _profile!.countryCode,
          sentAt: DateTime.now(),
          roomId: widget.roomId,
          text: text,
          languageCode: context.read<AppLocaleController>().languageCode,
          replyToText: _replyPreview,
          replyToMessageId: _reply?.id,
          replyToSenderName: _reply?.senderName,
          videoSeconds: _position));
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (c) => SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(l(
                      c,
                      'Galeriden seç',
                      'Choose from gallery',
                      'Выбрать из галереи',
                      "Aus der Galerie wählen",
                      "Elegir de la galería")),
                  onTap: () => Navigator.pop(c, ImageSource.gallery)),
              ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: Text(l(c, 'Fotoğraf çek', 'Take a photo',
                      'Сделать фото', "Foto aufnehmen", "Tomar una foto")),
                  onTap: () => Navigator.pop(c, ImageSource.camera)),
            ])));
    if (source == null) return;
    final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
        requestFullMetadata: false);
    if (image == null || !mounted) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(l(
                    c,
                    'Bu fotoğrafı gönder?',
                    'Send this photo?',
                    'Отправить это фото?',
                    "Dieses Foto senden?",
                    "¿Enviar esta foto?")),
                content: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child:
                        Image.memory(bytes, height: 240, fit: BoxFit.contain)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(l(c, 'Vazgeç', 'Cancel', 'Отмена',
                          "Abbrechen", "Cancelar"))),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(l(c, 'Gönder', 'Send', 'Отправить', "Senden",
                          "Enviar")))
                ]));
    if (confirmed != true || !mounted) return;
    await _upload(() async {
      final png = bytes.length > 4 && bytes[0] == 137 && bytes[1] == 80;
      final type = image.mimeType ?? (png ? 'image/png' : 'image/jpeg');
      final extension = png
          ? 'png'
          : type.contains('webp')
              ? 'webp'
              : type.contains('heic')
                  ? 'heic'
                  : 'jpg';
      final url = await context.read<MediaService>().uploadMessageMedia(
          roomId: widget.roomId,
          userId: widget.userId,
          bytes: bytes,
          extension: extension,
          contentType: type);
      await _messageService.sendMessage(MessageModel(
          senderId: widget.userId,
          senderName: _profile!.name,
          senderCountry: _profile!.countryCode,
          sentAt: DateTime.now(),
          roomId: widget.roomId,
          type: MessageType.image,
          mediaUrl: url,
          languageCode: _profile!.preferredLanguage,
          replyToText: _replyPreview,
          replyToMessageId: _reply?.id,
          replyToSenderName: _reply?.senderName,
          videoSeconds: _position));
    });
  }

  Future<void> _sendAudio(String path, int duration) => _upload(() async {
        final bytes = await XFile(path).readAsBytes();
        if (!mounted) return;
        final url = await context.read<MediaService>().uploadMessageMedia(
            roomId: widget.roomId,
            userId: widget.userId,
            bytes: bytes,
            extension: 'm4a',
            contentType: 'audio/mp4');
        await _messageService.sendMessage(MessageModel(
            senderId: widget.userId,
            senderName: _profile!.name,
            senderCountry: _profile!.countryCode,
            sentAt: DateTime.now(),
            roomId: widget.roomId,
            type: MessageType.audio,
            mediaUrl: url,
            durationMs: duration,
            languageCode: _profile!.preferredLanguage,
            replyToText: _replyPreview,
            replyToMessageId: _reply?.id,
            replyToSenderName: _reply?.senderName,
            videoSeconds: _position));
      });
  Future<void> _upload(Future<void> Function() action) async {
    if (_sendingMedia) return;
    setState(() => _sendingMedia = true);
    try {
      await action();
      if (mounted) setState(() => _reply = null);
    } finally {
      if (mounted) setState(() => _sendingMedia = false);
    }
  }

  Future<void> _applyMovieVolume(YoutubePlayerController player) async {
    await player.setVolume(_movieVolume.value.round());
    if (_movieVolume.value == 0) {
      await player.mute();
    } else {
      await player.unMute();
    }
  }

  void _setMovieVolume(double value) {
    _movieVolume.value = value.clamp(0, 100);
    if (value > 0) _unmutedMovieVolume = value;
    setState(() => _muted = value == 0);
    if (_player != null) {
      unawaited(_applyMovieVolume(_player!).catchError((Object _) {}));
    }
    SharedPreferences.getInstance()
        .then((p) => p.setDouble('movie_volume', _movieVolume.value));
  }

  Future<void> _voiceSheet() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: PartyColors.night,
        builder: (context) => Theme(
            data: PartyTheme.dark,
            child: VoiceChatSheet(
                service: _voice,
                roomId: widget.roomId,
                movieVolume: _movieVolume,
                onMovieVolume: _setMovieVolume)),
      );

  Future<void> _invite() async {
    final invitation = l(
        context,
        'Birlikte izleyelim! WatchParty oda kodum: ${widget.roomId}',
        'Watch with me! My WatchParty room code: ${widget.roomId}',
        'Посмотрим вместе! Код комнаты WatchParty: ${widget.roomId}',
        "Schau mit mir! Mein WatchParty-Raumcode: ${widget.roomId}",
        "¡Veamos algo juntos! Mi código de sala de WatchParty: ${widget.roomId}");
    final text = '$invitation\nwatchparty://watch/room/${widget.roomId}';
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
          text: text,
          subject: 'WatchParty',
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size));
    } catch (_) {
      await _copyCode();
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.roomId));
    if (mounted) {
      toast(
          context,
          l(
              context,
              'Oda kodu kopyalandı.',
              'Room code copied.',
              'Код комнаты скопирован.',
              "Raumcode kopiert.",
              "Código de sala copiado."));
    }
  }

  Future<void> _addVideo() async {
    final link = TextEditingController();
    final result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (c) => Padding(
            padding: EdgeInsets.fromLTRB(
                24, 8, 24, MediaQuery.viewInsetsOf(c).bottom + 24),
            child: SafeArea(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      l(c, 'Sırada ne var?', 'What is next?', 'Что дальше?',
                          "Was kommt als Nächstes?", "¿Qué sigue?"),
                      style: const TextStyle(
                          fontFamily: 'InstrumentSerif',
                          fontFamilyFallback: ['PTSerif', 'Manrope'],
                          fontSize: 36)),
                  const SizedBox(height: 14),
                  TextField(
                      controller: link,
                      autofocus: true,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                          hintText: l(
                              c,
                              'YouTube bağlantısı',
                              'YouTube link',
                              'Ссылка YouTube',
                              "YouTube-Link",
                              "Enlace de YouTube"))),
                  const SizedBox(height: 16),
                  PartyButton(
                      label: l(
                          c,
                          'Sıraya ekle',
                          'Add to queue',
                          'Добавить в очередь',
                          "Zur Warteschlange hinzufügen",
                          "Añadir a la cola"),
                      onPressed: () => Navigator.pop(c, link.text))
                ]))));
    Future.delayed(const Duration(seconds: 1), link.dispose);
    if (result == null || !mounted) return;
    final id = extractYoutubeVideoId(result);
    if (id == null) {
      toast(
          context,
          l(
              context,
              'Geçerli bir YouTube bağlantısı gir.',
              'Enter a valid YouTube link.',
              'Введите корректную ссылку YouTube.',
              "Gib einen gültigen YouTube-Link ein.",
              "Introduce un enlace válido de YouTube."));
      return;
    }
    try {
      await _service.addToQueue(widget.roomId, id, widget.userId);
    } catch (_) {
      if (mounted) {
        toast(
            context,
            l(
                context,
                'Video eklenemedi. Sırada en fazla 30 video olabilir.',
                'Could not add video. The queue holds up to 30.',
                'Не удалось добавить видео. Максимум 30 видео.',
                "Video konnte nicht hinzugefügt werden. Die Warteschlange fasst bis zu 30 Videos.",
                "No se pudo añadir el video. La cola admite hasta 30 videos."));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_voice.leave());
    }
    _beat();
    if (_active) {
      if (_playbackFailure != null && !_startingPlayer && _player != null) {
        unawaited(_retryPlayer());
      } else {
        _scheduleSync(force: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recoveryTimer?.cancel();
    _heartbeat?.cancel();
    _syncTimer?.cancel();
    _roomSub?.cancel();
    _positionSub?.cancel();
    _readSub?.cancel();
    _playerSub?.cancel();
    _player?.close();
    if (_fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _voice.dispose();
    _movieVolume.dispose();
    _chat.dispose();
    _service
        .removeParticipant(widget.roomId, widget.userId)
        .catchError((Object e) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
      data: PartyTheme.dark,
      child: Builder(builder: (context) {
        // Scaffold removes bottom viewInsets from its body after resizing.
        // Read the IME inset above Scaffold; only metadata collapses, never video.
        final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
        if (_error != null) {
          return Scaffold(
              appBar: AppBar(),
              body: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.meeting_room_outlined,
                            size: 48, color: PartyColors.lime),
                        const SizedBox(height: 20),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        FilledButton(
                            onPressed: () => context.go('/'),
                            child: Text(l(
                                context,
                                'Ana sayfaya dön',
                                'Back to home',
                                'На главную',
                                "Zur Startseite",
                                "Volver al inicio")))
                      ]))));
        }
        if (_player == null || _messages == null) {
          return Scaffold(
              body: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Brand(),
            const SizedBox(height: 30),
            const CircularProgressIndicator(strokeWidth: 2),
            const SizedBox(height: 20),
            Text(
                l(
                    context,
                    'İzleme odan hazırlanıyor…',
                    'Getting your room ready…',
                    'Готовим вашу комнату…',
                    "Dein Raum wird vorbereitet…",
                    "Preparando tu sala…"),
                style: const TextStyle(color: Colors.white54, fontSize: 12))
          ])));
        }
        if (_fullscreen) {
          return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _toggleFullscreen();
              },
              child: Scaffold(
                  body: SafeArea(
                      child: Stack(children: [
                Column(children: [
                  Expanded(
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(
                          child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: _videoSurface(context)),
                        ),
                        _subtitleLine(context),
                      ]),
                    ),
                  ),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _controls(context)),
                ]),
                Positioned(
                    top: 4,
                    right: 8,
                    child: IconButton(
                        tooltip: l(
                            context,
                            'Tam ekrandan çık',
                            'Exit fullscreen',
                            'Выйти из полноэкранного режима',
                            'Vollbild verlassen',
                            'Salir de pantalla completa'),
                        onPressed: _toggleFullscreen,
                        icon: const Icon(Icons.fullscreen_exit_rounded))),
              ]))));
        }
        return Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
                toolbarHeight: keyboardOpen ? 40 : kToolbarHeight,
                leading: IconButton(
                    tooltip: l(
                        context,
                        'Odadan ayrıl',
                        'Leave room',
                        'Выйти из комнаты',
                        "Raum verlassen",
                        "Salir de la sala"),
                    icon: const Icon(Icons.arrow_back_rounded, size: 22),
                    onPressed: () => context.go('/')),
                titleSpacing: 0,
                title: InkWell(
                    onTap: _copyCode,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              l(
                                  context,
                                  'BİZİM İZLEME ODAMIZ',
                                  'OUR WATCH ROOM',
                                  'НАША КОМНАТА',
                                  "UNSER GEMEINSAMER RAUM",
                                  "NUESTRA SALA"),
                              style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.white38,
                                  letterSpacing: 1.6)),
                          const SizedBox(height: 2),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(widget.roomId,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2)),
                            const SizedBox(width: 6),
                            const Icon(Icons.content_copy_rounded,
                                size: 11, color: Colors.white38)
                          ])
                        ])),
                actions: [
                  ListenableBuilder(
                      listenable: _voice,
                      builder: (context, _) => IconButton(
                          key: const Key('open-voice-chat'),
                          tooltip: l(
                              context,
                              'Sesli sohbet ve ses ayarları',
                              'Voice chat and volume',
                              'Голосовой чат и громкость',
                              'Sprachchat und Lautstärke',
                              'Chat de voz y volumen'),
                          onPressed: _voiceSheet,
                          icon: Badge(
                              isLabelVisible: _voice.joined,
                              smallSize: 7,
                              backgroundColor: PartyColors.lime,
                              child: Icon(
                                  _voice.microphoneEnabled
                                      ? Icons.mic_rounded
                                      : Icons.headphones_rounded,
                                  color: _voice.joined
                                      ? PartyColors.lime
                                      : Colors.white70,
                                  size: 22)))),
                  IconButton(
                      tooltip: l(
                          context,
                          'Arkadaşını davet et',
                          'Invite your friend',
                          'Пригласить друга',
                          "Lade jemanden ein",
                          "Invita a alguien"),
                      onPressed: _invite,
                      icon: const Icon(Icons.ios_share_rounded, size: 20)),
                  const SizedBox(width: 10)
                ]),
            body: SafeArea(
                top: false,
                bottom: false,
                child: LayoutBuilder(builder: (context, c) {
                  final wide = c.maxWidth > 760;
                  final stage = _stage(
                      context,
                      wide ? c.maxWidth * .55 : c.maxWidth,
                      (keyboardOpen || c.maxHeight < 420));
                  return wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Expanded(
                                  flex: 55,
                                  child: SingleChildScrollView(child: stage)),
                              const VerticalDivider(width: 1),
                              Expanded(
                                  flex: 45,
                                  child: _conversation(context,
                                      compact: keyboardOpen))
                            ])
                      : Column(children: [
                          stage,
                          Expanded(
                              child:
                                  _conversation(context, compact: keyboardOpen))
                        ]);
                })));
      }));

  void _toggleFullscreen() {
    FocusScope.of(context).unfocus();
    setState(() => _fullscreen = !_fullscreen);
    SystemChrome.setEnabledSystemUIMode(
        _fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  Widget _videoSurface(BuildContext context) =>
      Stack(fit: StackFit.expand, children: [
        if (!_waitingForSubtitles)
          Listener(
              onPointerDown: (_) => _playerGestureAt = DateTime.now(),
              child:
                  InlineYoutubeSurface(key: _surfaceKey, controller: _player!)),
        if (_waitingForSubtitles)
          ColoredBox(
              key: const Key('song-subtitle-wait'),
              color: PartyColors.night,
              child: Center(
                  child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.closed_caption_outlined,
                      size: 30, color: PartyColors.lime),
                  const SizedBox(height: 10),
                  Text(_subtitlesPreparing(context),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 14),
                  const SizedBox(
                    width: 92,
                    child: LinearProgressIndicator(
                        minHeight: 2, color: PartyColors.lime),
                  ),
                ]),
              ))),
        if (!_waitingForSubtitles &&
            (_startingPlayer || _recoveringPlayer || _playbackFailure != null))
          ColoredBox(
              color: PartyColors.night,
              child: Center(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (_playbackFailure == null ||
                            _recoveringPlayer ||
                            _startingPlayer) ...[
                          const CircularProgressIndicator(strokeWidth: 2),
                          const SizedBox(height: 12),
                          Text(
                              l(
                                  context,
                                  'YouTube bağlantısı kuruluyor…',
                                  'Connecting to YouTube…',
                                  'Подключение к YouTube…',
                                  'Verbindung zu YouTube…',
                                  'Conectando con YouTube…'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12)),
                        ] else ...[
                          Icon(
                              _playbackFailure == 'youtube'
                                  ? Icons.error_outline_rounded
                                  : Icons.wifi_off_rounded,
                              color: PartyColors.orange),
                          const SizedBox(height: 8),
                          Text(
                              _playbackFailure == 'youtube'
                                  ? _youtubeFailureMessage(context)
                                  : l(
                                      context,
                                      'YouTube bağlantısı kurulamadı. İnternet veya VPN bağlantını kontrol edip tekrar dene.',
                                      'Could not connect to YouTube. Check your internet or VPN connection and try again.',
                                      'Не удалось подключиться к YouTube. Проверьте интернет или VPN и повторите.',
                                      'Keine Verbindung zu YouTube. Prüfe Internet oder VPN und versuche es erneut.',
                                      'No se pudo conectar con YouTube. Comprueba tu conexión a internet o VPN e inténtalo de nuevo.'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 8),
                          if (_playbackFailure == 'youtube')
                            Text('YouTube · ${_player!.value.error.code}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white60)),
                          if (_playbackFailure == 'connection')
                            Text(
                                l(
                                    context,
                                    'VPN yalnızca seçili uygulamalarda çalışıyorsa WatchParty’yi de listeye ekle.',
                                    'If your VPN only covers selected apps, add WatchParty to that list.',
                                    'Если VPN работает только для выбранных приложений, добавьте WatchParty в список.',
                                    'Wenn dein VPN nur ausgewählte Apps umfasst, füge WatchParty zur Liste hinzu.',
                                    'Si tu VPN solo incluye algunas aplicaciones, añade WatchParty a la lista.'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white60)),
                          TextButton.icon(
                              onPressed: _retryPlayer,
                              icon: const Icon(Icons.refresh),
                              label: Text(l(
                                  context,
                                  'Yeniden bağlan',
                                  'Reconnect',
                                  'Подключиться снова',
                                  'Neu verbinden',
                                  'Volver a conectar'))),
                        ],
                      ])))),
      ]);

  String _youtubeFailureMessage(BuildContext context) =>
      switch (_player!.value.error) {
        YoutubeError.invalidParam => l(
            context,
            'Video oynatıcısı başlatılamadı. Yeniden bağlan.',
            'The video player could not start. Reconnect.',
            'Не удалось запустить видеоплеер. Подключитесь снова.',
            'Der Videoplayer konnte nicht starten. Verbinde dich neu.',
            'No se pudo iniciar el reproductor. Vuelve a conectar.'),
        YoutubeError.notEmbeddable ||
        YoutubeError.sameAsNotEmbeddable ||
        YoutubeError.sameAsNotEmbeddable2 =>
          l(
              context,
              'Video sahibi bu videonun uygulama içinde oynatılmasına izin vermiyor. Başka bir video seç.',
              'The owner does not allow this video in embedded players. Choose another video.',
              'Автор запретил просмотр этого видео во встроенных плеерах. Выберите другое видео.',
              'Dieses Video darf nicht in eingebetteten Playern laufen. Wähle ein anderes.',
              'El propietario no permite este video en reproductores integrados. Elige otro.'),
        _ => l(
            context,
            'YouTube videoyu yükleyemedi. Yeniden bağlanmayı dene.',
            'YouTube could not load the video. Try reconnecting.',
            'YouTube не удалось загрузить видео. Подключитесь снова.',
            'YouTube konnte das Video nicht laden. Versuche es erneut.',
            'YouTube no pudo cargar el video. Prueba a volver a conectar.'),
      };

  String _subtitlesPreparing(BuildContext context) => l(
      context,
      'Şarkı altyazısı hazırlanıyor…',
      'Preparing song subtitles…',
      'Готовим субтитры песни…',
      'Lieduntertitel werden vorbereitet…',
      'Preparando los subtítulos de la canción…');

  Future<void> _toggleSongSubtitles() async {
    if (_subtitles.isNotEmpty) {
      setState(() => _showSubtitles = !_showSubtitles);
      final value = _showSubtitles;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('show_song_subtitles', value);
      return;
    }
    if (_subtitleLoadFailed && _room != null) {
      _prepareSubtitles(_room!.videoId, _subtitleLanguage, wait: false);
    }
    final message = _loadingSubtitles
        ? _subtitlesPreparing(context)
        : l(
            context,
            'Bu video için şarkı altyazısı bulunamadı.',
            'Song subtitles are unavailable for this video.',
            'Для этого видео нет субтитров песни.',
            'Für dieses Video sind keine Lieduntertitel verfügbar.',
            'No hay subtítulos de la canción para este vídeo.');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _subtitleLine(BuildContext context) {
    if (!_showSubtitles ||
        _subtitles.isEmpty ||
        _loadedVideo != _subtitleVideo ||
        !_ready ||
        _waitingForSubtitles) {
      return const SizedBox.shrink();
    }
    final line = SongSubtitle.at(_subtitles, (_position * 1000).round());
    return Container(
      key: const Key('song-subtitle-strip'),
      width: double.infinity,
      height: MediaQuery.textScalerOf(context).scale(14) * 2.8 + 12,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      alignment: Alignment.center,
      color: PartyColors.panel,
      child: line == null
          ? null
          : Text(line,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: PartyColors.paper)),
    );
  }

  Widget _stage(BuildContext context, double width, bool keyboard) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            key: const Key('room-video-stage'),
            height: keyboard ? 200 : (width * 9 / 16).clamp(200.0, 330.0),
            child: _videoSurface(context)),
        _subtitleLine(context),
        if (!keyboard) ...[
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
              child: Row(children: [
                Expanded(
                    child: Text(
                        _room?.videoTitle.isNotEmpty == true
                            ? _room!.videoTitle
                            : 'YouTube',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: PartyColors.paper))),
                IconButton(
                    tooltip: l(context, 'Tam ekran', 'Fullscreen',
                        'Полный экран', 'Vollbild', 'Pantalla completa'),
                    onPressed: _toggleFullscreen,
                    icon: const Icon(Icons.fullscreen_rounded, size: 22)),
              ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: _controls(context)),
        ],
      ]);
  Widget _controls(BuildContext context) {
    final canControl =
        _online && _ready && !_startingPlayer && !_waitingForSubtitles;
    final drift = _room == null
        ? 0.0
        : (calculateTargetPlaybackSeconds(
                    storedSeconds: _room!.currentTime,
                    isPlaying: _room!.isPlaying,
                    updatedAt: _room!.lastUpdatedAt ?? DateTime.now()) -
                _position)
            .abs();
    final synced = _online &&
        _ready &&
        !_room!.hasPendingWrites &&
        drift < 2 &&
        _playing == _room!.isPlaying;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        IconButton(
            tooltip: l(
                context,
                'Herkes için 10 saniye geri',
                'Rewind 10 seconds for everyone',
                'Назад на 10 секунд для всех',
                "Für alle 10 Sekunden zurückspulen",
                "Retroceder 10 segundos para todos"),
            visualDensity: VisualDensity.compact,
            onPressed:
                canControl ? () => _control(seconds: _position - 10) : null,
            icon: const Icon(Icons.replay_10_rounded, size: 23)),
        IconButton.filled(
            tooltip: l(
                context,
                'Herkes için oynat / duraklat',
                'Play / pause for everyone',
                'Воспроизвести / пауза для всех',
                "Für alle abspielen / pausieren",
                "Reproducir / pausar para todos"),
            style: IconButton.styleFrom(
                backgroundColor: PartyColors.lime,
                foregroundColor: PartyColors.ink),
            onPressed: canControl && !_changing
                ? () => _control(playing: !_playing)
                : null,
            icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 25)),
        Expanded(
            child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12)),
                child: Slider(
                    value: (_dragPosition ?? _position)
                        .clamp(0, _duration > 0 ? _duration : 1),
                    max: _duration > 0 ? _duration : 1,
                    onChanged: canControl && _duration > 0
                        ? (v) => setState(() => _dragPosition = v)
                        : null,
                    onChangeEnd: (v) {
                      setState(() => _dragPosition = null);
                      _control(seconds: v);
                    }))),
        Text(
            '${formatTime(_dragPosition ?? _position)} / ${formatTime(_duration)}',
            style: const TextStyle(fontSize: 9, color: Colors.white54)),
        IconButton(
          key: const Key('song-subtitle-toggle'),
          tooltip: l(context, 'Şarkı altyazısı', 'Song subtitles',
              'Субтитры песни', 'Lieduntertitel', 'Subtítulos de la canción'),
          visualDensity: VisualDensity.compact,
          isSelected: _showSubtitles && _subtitles.isNotEmpty,
          onPressed: _waitingForSubtitles ? null : _toggleSongSubtitles,
          icon: const Icon(Icons.closed_caption_off_outlined,
              size: 20, color: Colors.white60),
          selectedIcon: const Icon(Icons.closed_caption_rounded,
              size: 20, color: PartyColors.lime),
        ),
        IconButton(
            tooltip: l(
                context,
                'Sesi aç / kapat (yalnızca sen)',
                'Mute / unmute (only you)',
                'Звук (только у вас)',
                "Ton ein / aus (nur bei dir)",
                "Activar / silenciar sonido (solo para ti)"),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              _setMovieVolume(_muted ? _unmutedMovieVolume : 0);
            },
            icon: Icon(
                _muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                size: 18,
                color: Colors.white54)),
      ]),
      Padding(
          padding: const EdgeInsets.fromLTRB(6, 1, 6, 8),
          child: Row(children: [
            Icon(
                synced
                    ? Icons.link_rounded
                    : _online
                        ? Icons.sync_rounded
                        : Icons.cloud_off_outlined,
                size: 12,
                color: synced ? PartyColors.lime : Colors.white38),
            const SizedBox(width: 5),
            Text(
                !_online
                    ? l(context, 'Çevrimdışı', 'Offline', 'Нет сети', "Offline",
                        "Sin conexión")
                    : synced
                        ? l(context, 'Aynı andayız', 'In sync', 'Синхронно',
                            "Synchron", "Sincronizados")
                        : l(
                            context,
                            'Eşitleniyor…',
                            'Syncing…',
                            'Синхронизация…',
                            "Synchronisierung…",
                            "Sincronizando…"),
                style: TextStyle(
                    fontSize: 9,
                    color: synced ? PartyColors.lime : Colors.white38)),
            const Spacer(),
            Text(
                l(
                    context,
                    'Kontroller herkes için ortak',
                    'Shared controls for everyone',
                    'Общее управление',
                    "Gemeinsame Steuerung für alle",
                    "Controles compartidos para todos"),
                style: const TextStyle(fontSize: 9, color: Colors.white30))
          ]))
    ]);
  }

  Widget _conversation(BuildContext context, {bool compact = false}) =>
      Column(children: [
        if (!compact)
          Container(
              decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(color: Colors.white10),
                      bottom: BorderSide(color: Colors.white10))),
              child: Row(children: [
                for (final item in [
                  (
                    Icons.chat_bubble_outline_rounded,
                    l(context, 'Sohbet', 'Chat', 'Чат', "Chat", "Chat")
                  ),
                  (
                    Icons.playlist_play_rounded,
                    l(context, 'Sıradaki', 'Queue', 'Очередь', "Nächste",
                        "Cola")
                  ),
                  (
                    Icons.people_outline_rounded,
                    l(context, 'Birlikte', 'People', 'Участники', "Dabei",
                        "Personas")
                  )
                ].indexed)
                  Expanded(
                      child: InkWell(
                          onTap: () => setState(() => _tab = item.$1),
                          child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: _tab == item.$1
                                              ? PartyColors.lime
                                              : Colors.transparent,
                                          width: 2))),
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(item.$2.$1,
                                        size: 15,
                                        color: _tab == item.$1
                                            ? PartyColors.lime
                                            : Colors.white38),
                                    const SizedBox(width: 7),
                                    Flexible(
                                        child: Text(item.$2.$2,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: _tab == item.$1
                                                    ? PartyColors.paper
                                                    : Colors.white38))),
                                    if (item.$1 == 1 &&
                                        (_room?.queue.length ?? 0) > 0)
                                      Text('  ${_room!.queue.length}',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: PartyColors.lime))
                                  ])))),
              ])),
        Expanded(
            child: (compact || _tab == 0)
                ? StreamBuilder<List<MessageModel>>(
                    stream: _messages,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                            child: Text(l(
                                context,
                                'Sohbet yüklenemedi. Odaya tekrar katıl.',
                                'Could not load chat. Rejoin the room.',
                                'Не удалось загрузить чат. Войдите снова.',
                                "Chat konnte nicht geladen werden. Tritt erneut bei.",
                                "No se pudo cargar el chat. Vuelve a entrar en la sala.")));
                      }
                      return ChatPanel(
                          messages: snapshot.data ?? [],
                          currentUserId: widget.userId,
                          isActive: _active && !_fullscreen,
                          readThrough: _readThrough,
                          onMessageVisible: (message) => _messageService
                              .markRead(widget.roomId, widget.userId, message),
                          controller: _chat,
                          onSendText: _sendText,
                          onPickImage: _pickPhoto,
                          onSendAudio: _sendAudio,
                          isSending: _sendingMedia,
                          voiceService: _voice,
                          targetLanguage: _profile?.translationLanguage ?? 'tr',
                          autoTranslate: _profile?.autoTranslate ?? false,
                          joinedAt: _joinedAt,
                          replyTo: _reply == null
                              ? null
                              : '${_reply!.senderName}: $_replyPreview',
                          onReply: (v) => setState(() => _reply = v),
                          onClearReply: () => setState(() => _reply = null),
                          onSeek: (v) => _control(seconds: v));
                    })
                : _tab == 1
                    ? _queue(context)
                    : _people(context)),
      ]);
  Widget _queue(BuildContext context) => Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                  child: Text(
                      l(
                          context,
                          'Sonraki videoyu sen seç.',
                          'Pick the next video.',
                          'Выберите следующее видео.',
                          "Wähle das nächste Video.",
                          "Elige el siguiente video."),
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white54))),
              FilledButton.tonalIcon(
                  onPressed: _online ? _addVideo : null,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                      l(context, 'Ekle', 'Add', 'Добавить', "Hinzufügen",
                          "Añadir"),
                      style: const TextStyle(fontSize: 11)))
            ])),
        Expanded(
            child: (_room?.queue.isEmpty ?? true)
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                            l(
                                context,
                                'Bir sonraki favorinizi buraya ekleyin.\nSıra herkes için ortak.',
                                'Add your next favourite here.\nThe queue is shared with everyone.',
                                'Добавьте следующее видео.\nОчередь общая для всех.',
                                "Füge hier deinen nächsten Favoriten hinzu.\nDie Warteschlange ist für alle gemeinsam.",
                                "Añade aquí tu próximo favorito.\nLa cola se comparte con todos."),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white38,
                                height: 1.8))))
                : ListView(
                    children: _room!.queue
                        .map((v) => ListTile(
                              leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                      'https://i.ytimg.com/vi/${v['videoId']}/mqdefault.jpg',
                                      width: 70,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, e, s) => const Icon(
                                          Icons.video_library_outlined))),
                              title: Text(v['title'] as String? ?? 'YouTube',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12)),
                              subtitle: Text(
                                  l(
                                      context,
                                      'Dokun, herkes için oynat',
                                      'Tap to play for everyone',
                                      'Нажмите, чтобы включить для всех',
                                      "Antippen, um es für alle abzuspielen",
                                      "Pulsa para reproducirlo para todos"),
                                  style: const TextStyle(
                                      fontSize: 9, color: Colors.white38)),
                              onTap: _online
                                  ? () async {
                                      try {
                                        await _service.playQueued(widget.roomId,
                                            v['id'] as String, widget.userId);
                                      } catch (_) {
                                        if (context.mounted) {
                                          toast(
                                              context,
                                              l(
                                                  context,
                                                  'Video başlatılamadı.',
                                                  'Could not start video.',
                                                  'Не удалось запустить видео.',
                                                  "Video konnte nicht gestartet werden.",
                                                  "No se pudo iniciar el video."));
                                        }
                                      }
                                    }
                                  : null,
                              trailing: IconButton(
                                  tooltip: l(
                                      context,
                                      'Sıradan kaldır',
                                      'Remove from queue',
                                      'Удалить из очереди',
                                      "Aus der Warteschlange entfernen",
                                      "Quitar de la cola"),
                                  onPressed: _online
                                      ? () async {
                                          try {
                                            await _service.removeFromQueue(
                                                widget.roomId,
                                                v['id'] as String);
                                          } catch (_) {}
                                        }
                                      : null,
                                  icon: const Icon(Icons.close,
                                      size: 16, color: Colors.white38)),
                            ))
                        .toList())),
      ]);
  Widget _people(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
          stream: _presence,
          builder: (context, snapshot) {
            final people = (snapshot.data ?? []).where((p) {
              final seen = p['lastSeenAt'];
              return p['userId'] == widget.userId ||
                  seen is Timestamp &&
                      DateTime.now().difference(seen.toDate()).inSeconds < 90;
            }).toList();
            return ListView(padding: const EdgeInsets.all(20), children: [
              Row(children: [
                Eyebrow(
                    l(
                        context,
                        '${people.length} KİŞİ BU ANDA',
                        '${people.length} HERE RIGHT NOW',
                        'СЕЙЧАС ЗДЕСЬ: ${people.length}',
                        "${people.length} GERADE DABEI",
                        "${people.length} AQUÍ AHORA"),
                    color: Colors.white38),
                const Spacer(),
                IconButton(
                    tooltip: l(context, 'Davet et', 'Invite', 'Пригласить',
                        "Einladen", "Invitar"),
                    onPressed: _invite,
                    icon: const Icon(Icons.person_add_alt_1_outlined,
                        size: 20, color: PartyColors.lime))
              ]),
              for (final p in people)
                ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 5),
                    leading: PartyAvatar(
                        name: p['name'] as String? ??
                            l(context, 'Misafir', 'Guest', 'Гость', 'Gast',
                                'Invitado'),
                        countryCode: p['countryCode'] as String? ?? ''),
                    title: Text('${p['name'] ?? l(context, 'Misafir', 'Guest', 'Гость', 'Gast', 'Invitado')}${p['userId'] == widget.userId ? l(context, ' (sen)', ' (you)', ' (вы)', ' (du)', ' (tú)') : ''}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        p['userId'] == _room?.createdBy
                            ? l(
                                context,
                                'Odayı açan',
                                'Room creator',
                                'Создатель комнаты',
                                "Raum erstellt von",
                                "Creó la sala")
                            : l(
                                context,
                                'Birlikte izliyor',
                                'Watching together',
                                'Смотрит вместе',
                                "Schaut mit",
                                "Viendo juntos"),
                        style: const TextStyle(fontSize: 10, color: Colors.white38)),
                    trailing: const Icon(Icons.circle, size: 7, color: PartyColors.lime)),
              if (people.length < 2)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                        l(
                            context,
                            'En güzel kısmı paylaşmak.\nOda kodunu arkadaşına gönder, birlikte başlayın.',
                            'Better when shared.\nSend your room code to a friend and start together.',
                            'Вместе интереснее.\nОтправьте код другу и начинайте.',
                            "Zusammen ist es schöner.\nTeile deinen Raumcode und schaut gemeinsam los.",
                            "Mejor en compañía.\nComparte tu código de sala y empiecen juntos."),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white38, height: 1.8))),
            ]);
          });
}
