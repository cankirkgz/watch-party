double calculateTargetPlaybackSeconds({
  required double storedSeconds,
  required bool isPlaying,
  required DateTime updatedAt,
  DateTime? now,
}) {
  if (!isPlaying) return storedSeconds;
  final elapsedMilliseconds =
      (now ?? DateTime.now()).difference(updatedAt).inMilliseconds;
  final nonNegativeElapsed = elapsedMilliseconds < 0 ? 0 : elapsedMilliseconds;
  return storedSeconds + nonNegativeElapsed / Duration.millisecondsPerSecond;
}
