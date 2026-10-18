/// Sesión de enfoque terminada o interrumpida.
class FocusSession {
  const FocusSession({
    required this.id,
    required this.startedAt,
    required this.plannedSeconds,
    required this.actualSeconds,
    this.taskId,
    this.label = '',
    this.completed = true,
  });

  final String id;
  final String? taskId;
  final String label;
  final DateTime startedAt;
  final int plannedSeconds;
  final int actualSeconds;

  /// Verdadero si el temporizador llegó a cero; falso si se detuvo antes.
  final bool completed;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'taskId': taskId,
        'label': label,
        'startedAt': startedAt.toIso8601String(),
        'plannedSeconds': plannedSeconds,
        'actualSeconds': actualSeconds,
        'completed': completed,
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
        id: json['id'] as String? ?? '',
        taskId: json['taskId'] as String?,
        label: json['label'] as String? ?? '',
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? '') ??
            DateTime.now(),
        plannedSeconds: (json['plannedSeconds'] as num?)?.toInt() ?? 0,
        actualSeconds: (json['actualSeconds'] as num?)?.toInt() ?? 0,
        completed: json['completed'] as bool? ?? true,
      );
}

/// Temporizador en curso. Se guarda para sobrevivir a un reinicio de la app.
class ActiveFocus {
  const ActiveFocus({
    required this.startedAt,
    required this.plannedSeconds,
    this.taskId,
    this.label = '',
    this.accumulatedSeconds = 0,
    this.runningSince,
  });

  final String? taskId;
  final String label;
  final DateTime startedAt;
  final int plannedSeconds;

  /// Segundos ya contados en tramos anteriores a la última reanudación.
  final int accumulatedSeconds;

  /// Instante de la última reanudación; nulo si está en pausa.
  final DateTime? runningSince;

  bool get isRunning => runningSince != null;

  int elapsedSeconds(DateTime now) {
    final running = runningSince;
    final extra = running == null ? 0 : now.difference(running).inSeconds;
    return accumulatedSeconds + (extra < 0 ? 0 : extra);
  }

  int remainingSeconds(DateTime now) {
    final left = plannedSeconds - elapsedSeconds(now);
    return left < 0 ? 0 : left;
  }

  ActiveFocus paused(DateTime now) => ActiveFocus(
        taskId: taskId,
        label: label,
        startedAt: startedAt,
        plannedSeconds: plannedSeconds,
        accumulatedSeconds: elapsedSeconds(now),
      );

  ActiveFocus resumed(DateTime now) => ActiveFocus(
        taskId: taskId,
        label: label,
        startedAt: startedAt,
        plannedSeconds: plannedSeconds,
        accumulatedSeconds: accumulatedSeconds,
        runningSince: now,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'taskId': taskId,
        'label': label,
        'startedAt': startedAt.toIso8601String(),
        'plannedSeconds': plannedSeconds,
        'accumulatedSeconds': accumulatedSeconds,
        'runningSince': runningSince?.toIso8601String(),
      };

  static ActiveFocus? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, dynamic>();
    final started = DateTime.tryParse(json['startedAt'] as String? ?? '');
    final planned = (json['plannedSeconds'] as num?)?.toInt() ?? 0;
    if (started == null || planned <= 0) return null;
    return ActiveFocus(
      taskId: json['taskId'] as String?,
      label: json['label'] as String? ?? '',
      startedAt: started,
      plannedSeconds: planned,
      accumulatedSeconds: (json['accumulatedSeconds'] as num?)?.toInt() ?? 0,
      runningSince: DateTime.tryParse(json['runningSince'] as String? ?? ''),
    );
  }
}
