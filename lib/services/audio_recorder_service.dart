import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;
  Future<void> _removeDraft() async {
    final path = _path;
    _path = null;
    if (!kIsWeb && path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Future<String?> startRecording(String fileName) async {
    if (!await _recorder.hasPermission()) return null;
    await _removeDraft();
    final directory = kIsWeb ? null : await getTemporaryDirectory();
    final path =
        directory == null ? '$fileName.m4a' : '${directory.path}/$fileName.m4a';
    _path = path;
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        iosConfig: IosRecordConfig(categoryOptions: [
          IosAudioCategoryOption.mixWithOthers,
          IosAudioCategoryOption.defaultToSpeaker,
          IosAudioCategoryOption.allowBluetooth,
          IosAudioCategoryOption.allowBluetoothA2DP
        ]),
        audioInterruption: AudioInterruptionMode.none,
        androidConfig: AndroidRecordConfig(manageBluetooth: false),
      ),
      path: path,
    );
    return path;
  }

  Future<String?> stopRecording() async {
    return _recorder.stop();
  }

  Future<void> cancelRecording() async {
    await _recorder.cancel();
    await _removeDraft();
  }

  Future<void> pause() => _recorder.pause();
  Future<void> resume() => _recorder.resume();
  Stream<Amplitude> get amplitude =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 100));
  Future<bool> isRecording() => _recorder.isRecording();
  Future<void> dispose() async {
    await _recorder.dispose();
    await _removeDraft();
  }
}
