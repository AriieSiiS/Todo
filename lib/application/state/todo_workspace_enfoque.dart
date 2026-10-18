part of 'todo_workspace.dart';

extension TodoWorkspaceEnfoque on TodoWorkspace {
  static const int focusNotificationId = 7100001;

  /// Empieza un temporizador. Si ya hay uno en curso se descarta sin registrar.
  void startFocus({
    String? taskId,
    String label = '',
    required int minutes,
  }) {
    final seconds = (minutes.clamp(1, 240)) * 60;
    final now = DateTime.now();
    final task = taskId == null ? null : taskById(taskId);
    _activeFocus = ActiveFocus(
      taskId: task?.id,
      label: label.trim().isNotEmpty ? label.trim() : (task?.title ?? ''),
      startedAt: now,
      plannedSeconds: seconds,
      runningSince: now,
    );
    _commit();
    _scheduleFocusCompletion();
  }

  void pauseFocus() {
    final active = _activeFocus;
    if (active == null || !active.isRunning) return;
    _focusTimer?.cancel();
    _activeFocus = active.paused(DateTime.now());
    _commit();
  }

  void resumeFocus() {
    final active = _activeFocus;
    if (active == null || active.isRunning) return;
    _activeFocus = active.resumed(DateTime.now());
    _commit();
    _scheduleFocusCompletion();
  }

  /// Detiene el temporizador y registra el tiempo trabajado, si lo hubo.
  void stopFocus() {
    final active = _activeFocus;
    if (active == null) return;
    _closeFocus(active, completed: false);
  }

  void discardFocus() {
    if (_activeFocus == null) return;
    _focusTimer?.cancel();
    _activeFocus = null;
    _commit();
  }

  void deleteFocusSession(String id) {
    _focusSessions.removeWhere((session) => session.id == id);
    _commit();
  }

  /// Segundos de enfoque registrados entre [from] (incluido) y [to] (excluido).
  int focusSecondsBetween(DateTime from, DateTime to) {
    var total = 0;
    for (final session in _focusSessions) {
      if (!session.startedAt.isBefore(from) && session.startedAt.isBefore(to)) {
        total += session.actualSeconds;
      }
    }
    return total;
  }

  /// Segundos de enfoque dedicados a una tarea.
  int focusSecondsForTask(String taskId) => _focusSessions
      .where((session) => session.taskId == taskId)
      .fold<int>(0, (sum, session) => sum + session.actualSeconds);

  /// Retoma el temporizador guardado al abrir la app: lo termina si ya venció.
  void resumeFocusAfterStartup() {
    final active = _activeFocus;
    if (active == null) return;
    if (active.isRunning) {
      if (active.remainingSeconds(DateTime.now()) <= 0) {
        _closeFocus(active, completed: true, announce: false);
      } else {
        _scheduleFocusCompletion();
      }
    }
  }

  void _scheduleFocusCompletion() {
    _focusTimer?.cancel();
    final active = _activeFocus;
    if (active == null || !active.isRunning) return;
    final remaining = active.remainingSeconds(DateTime.now());
    _focusTimer = Timer(Duration(seconds: remaining), () {
      final current = _activeFocus;
      if (current == null || !current.isRunning) return;
      _closeFocus(current, completed: true);
    });
  }

  void _closeFocus(
    ActiveFocus active, {
    required bool completed,
    bool announce = true,
  }) {
    _focusTimer?.cancel();
    final now = DateTime.now();
    final actual = completed
        ? active.plannedSeconds
        : active.elapsedSeconds(now).clamp(0, active.plannedSeconds);
    _activeFocus = null;
    if (actual >= 30 || completed) {
      _focusSessions.add(FocusSession(
        id: _id('focus'),
        taskId: active.taskId,
        label: active.label,
        startedAt: active.startedAt,
        plannedSeconds: active.plannedSeconds,
        actualSeconds: actual,
        completed: completed,
      ));
    }
    _commit();
    if (completed && announce) {
      unawaited(_feedback.playTaskCompleted());
      unawaited(_notificationService.showNow(
        id: focusNotificationId,
        title: 'Sesión de enfoque terminada',
        body: active.label.isEmpty
            ? 'Has completado ${active.plannedSeconds ~/ 60} minutos.'
            : '${active.label}: ${active.plannedSeconds ~/ 60} minutos.',
      ));
    }
  }
}
