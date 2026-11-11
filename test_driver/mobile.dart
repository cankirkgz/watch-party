import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final device = Platform.environment['WATCHPARTY_QA_DEVICE'];
  if (device != null) {
    if (!RegExp(r'^emulator-\d+$').hasMatch(device)) {
      throw StateError(
          'Automatic permission setup is limited to the QA emulator.');
    }
    final adb = Platform.environment['WATCHPARTY_QA_ADB'] ?? 'adb';
    final avd = await Process.run(adb, ['-s', device, 'emu', 'avd', 'name']);
    if (!avd.stdout
        .toString()
        .split('\n')
        .any((line) => line.trim() == 'WatchParty_QA')) {
      throw StateError('Expected the dedicated WatchParty_QA emulator.');
    }
    for (final permission in [
      'android.permission.RECORD_AUDIO',
      'android.permission.BLUETOOTH_CONNECT'
    ]) {
      final result = await Process.run(adb, [
        '-s',
        device,
        'shell',
        'pm',
        'grant',
        'com.example.watchparty',
        permission
      ]);
      if (result.exitCode != 0) {
        throw StateError('QA microphone setup failed.');
      }
    }
  }
  await integrationDriver(onScreenshot: (name, bytes, [args]) async {
    final file = File('build/qa-screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  });
}
