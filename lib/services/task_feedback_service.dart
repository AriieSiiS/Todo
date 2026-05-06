import 'dart:async';

import 'package:just_audio/just_audio.dart';

class TaskFeedbackService {
  static const String _taskCompleteAsset = 'resources/task-complete.wav';

  AudioPlayer? _taskCompletePlayer;
  bool _taskCompleteReady = false;

  Future<void> playTaskCompleted() async {
    final player = _taskCompletePlayer ??= AudioPlayer();
    try {
      if (!_taskCompleteReady) {
        await player.setAsset(_taskCompleteAsset);
        await player.setVolume(0.72);
        _taskCompleteReady = true;
      }
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {
      // El feedback sonoro es opcional y no debe bloquear la tarea.
    }
  }

  void dispose() {
    unawaited(_taskCompletePlayer?.dispose());
  }
}
