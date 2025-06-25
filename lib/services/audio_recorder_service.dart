import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<String?> startRecording(String fileName) async {
    if (await hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$fileName.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      return path;
    }
    return null;
  }

  Future<String?> stopRecording() async {
    if (await _recorder.isRecording()) {
      return await _recorder.stop();
    }
    return null;
  }

  Future<void> cancelRecording() async {
    await _recorder.cancel();
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  void dispose() {
    _recorder.dispose();
  }
}
