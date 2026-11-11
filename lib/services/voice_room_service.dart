// Pinned to LiveKit 2.13.1: explicit mixing uses its documented experimental audio-session API.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

// WebRTC shares the media stream with YouTube and never takes exclusive focus.
// Android playout attributes must be selected before WebRTC initializes.
const watchPartyAudioSession = AudioSessionOptions.communication(
  android: AndroidAudioSessionConfiguration(
    audioMode: AndroidAudioMode.normal,
    manageAudioFocus: false,
    streamType: AndroidAudioStreamType.music,
    usageType: AndroidAudioAttributesUsageType.media,
    contentType: AndroidAudioAttributesContentType.speech,
  ),
  apple: AppleAudioSessionConfiguration(
    category: AppleAudioCategory.playAndRecord,
    categoryOptions: {
      AppleAudioCategoryOption.mixWithOthers,
      AppleAudioCategoryOption.defaultToSpeaker,
      AppleAudioCategoryOption.allowBluetooth,
      AppleAudioCategoryOption.allowBluetoothA2DP,
    },
    mode: AppleAudioMode.videoChat,
  ),
);

class VoiceRoomService extends ChangeNotifier {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  int _generation = 0;
  bool _disposed = false, busy = false, recording = false;
  bool _restoreMic = false, deafened = false;
  double volume = 1;
  String? errorCode;
  bool get joined =>
      _room?.connectionState == ConnectionState.connected ||
      _room?.connectionState == ConnectionState.reconnecting;
  bool get reconnecting =>
      _room?.connectionState == ConnectionState.reconnecting;
  bool get microphoneEnabled =>
      _room?.localParticipant?.isMicrophoneEnabled() ?? false;
  List<Participant> get people => [
        if (_room?.localParticipant case final participant?) participant,
        ...?_room?.remoteParticipants.values,
      ];
  VoiceRoomService() {
    unawaited(_loadPreferences());
  }
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    volume = (prefs.getDouble('voice_volume') ?? 1).clamp(0, 1);
    deafened = prefs.getBool('voice_deafened') ?? false;
    _notify();
  }

  Future<void> join(String roomId) async {
    if (busy || joined || recording || _disposed) return;
    busy = true;
    errorCode = null;
    _notify();
    final generation = ++_generation;
    Room? room;
    try {
      final response = await FirebaseFunctions.instanceFor(
              region: 'europe-west1')
          .httpsCallable('joinVoiceRoom',
              options:
                  HttpsCallableOptions(timeout: const Duration(seconds: 25)))
          .call<Map<String, dynamic>>({'roomId': roomId});
      if (_disposed || generation != _generation) return;
      await _releaseRoom();
      await AudioManager.instance
          .setAudioSessionOptions(watchPartyAudioSession);
      room = Room(
          roomOptions: const RoomOptions(
        defaultAudioCaptureOptions: AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          stopAudioCaptureOnMute: true,
        ),
      ));
      _room = room;
      room.addListener(_roomChanged);
      _listener = room.createListener()
        ..on<TrackSubscribedEvent>((event) async {
          if (event.track is RemoteAudioTrack) {
            await _applyVolume(event.track as RemoteAudioTrack);
          }
          _notify();
        })
        ..on<RoomDisconnectedEvent>((event) {
          _notify();
        });
      await room.connect(
          response.data['url'] as String, response.data['token'] as String);
      if (_disposed || generation != _generation) {
        await room.disconnect();
        return;
      }
      // Joining only subscribes; no microphone permission or capture until tapped.
      await _applyVolumes();
    } catch (error) {
      if (generation == _generation && !_disposed) {
        errorCode =
            error is FirebaseFunctionsException ? error.code : 'connection';
        await _releaseRoom();
      } else {
        await room?.dispose();
      }
    } finally {
      if (generation == _generation) {
        busy = false;
        _notify();
      }
    }
  }

  void _roomChanged() {
    _notify();
  }

  Future<void> _applyVolume(RemoteAudioTrack track) =>
      rtc.Helper.setVolume(deafened ? 0 : volume, track.mediaStreamTrack);
  Future<void> _applyVolumes() async {
    for (final participant
        in _room?.remoteParticipants.values ?? <RemoteParticipant>[]) {
      for (final publication in participant.audioTrackPublications) {
        final track = publication.track;
        if (track is RemoteAudioTrack) await _applyVolume(track);
      }
    }
  }

  Future<void> setVolume(double value) async {
    volume = value.clamp(0, 1);
    _notify();
    await _applyVolumes();
    await (await SharedPreferences.getInstance())
        .setDouble('voice_volume', volume);
  }

  Future<void> toggleDeafen() async {
    deafened = !deafened;
    _notify();
    await _applyVolumes();
    await (await SharedPreferences.getInstance())
        .setBool('voice_deafened', deafened);
  }

  Future<void> toggleMicrophone() async {
    if (!joined || busy || recording) return;
    busy = true;
    errorCode = null;
    _notify();
    try {
      await AudioManager.instance
          .setAudioSessionOptions(watchPartyAudioSession);
      await _room?.localParticipant?.setMicrophoneEnabled(!microphoneEnabled);
    } catch (_) {
      errorCode = 'microphone';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> beginRecording() async {
    if (busy) throw StateError('voice-busy');
    recording = true;
    _restoreMic = microphoneEnabled;
    try {
      if (_restoreMic) {
        await _room?.localParticipant?.setMicrophoneEnabled(false);
      }
    } catch (_) {
      recording = false;
      _restoreMic = false;
      rethrow;
    }
    _notify();
  }

  Future<void> endRecording() async {
    if (!recording) return;
    recording = false;
    if (_restoreMic && joined && !_disposed) {
      try {
        await AudioManager.instance
            .setAudioSessionOptions(watchPartyAudioSession);
        await _room?.localParticipant?.setMicrophoneEnabled(true);
      } catch (_) {
        errorCode = 'microphone';
      }
    }
    _restoreMic = false;
    _notify();
  }

  Future<void> _releaseRoom() async {
    final room = _room;
    _room = null;
    room?.removeListener(_roomChanged);
    final listener = _listener;
    _listener = null;
    await listener?.dispose();
    await room?.disconnect();
    await room?.dispose();
  }

  Future<void> leave() async {
    ++_generation;
    busy = true;
    _restoreMic = false;
    _notify();
    await _releaseRoom();
    busy = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    unawaited(_releaseRoom());
    super.dispose();
  }
}
