part of 'kindle_workspace.dart';

extension KindleTasks on KindleWorkspace {
  List<TaskModel> _kindleFamily(TaskModel root) {
    final family = <TaskModel>[root];
    final seen = <String>{root.id};
    for (var index = 0; index < family.length; index++) {
      family.addAll(_tasks.where((task) =>
          task.parentTaskId == family[index].id && seen.add(task.id)));
    }
    return family;
  }

  String _kindleVersion(TaskModel root, String key) {
    final family = _kindleFamily(root)..sort((a, b) => a.id.compareTo(b.id));
    return _agentDigest({
      'tasks': family.map((task) => task.toJson()).toList(),
      'occurrence_date': key,
    });
  }

  bool _kindleCompleted(TaskModel task, TaskModel root, String key) =>
      root.recurrence.isRecurring || task.recurrence.isRecurring
          ? task.recurrenceCompletions.containsKey(key)
          : task.status == TaskStatus.completed;

  Map<String, dynamic> _kindleTask(TaskModel root, String key) {
    final family = _kindleFamily(root);
    Map<String, dynamic> project(TaskModel task) => {
          'id': task.id,
          'title': task.title,
          'description': task.description ?? '',
          'scheduled_at': task.scheduledAt?.toIso8601String() ?? '',
          'priority': task.priority.name,
          'completed': _kindleCompleted(task, root, key),
          'blocked': task.status == TaskStatus.archived ||
              task.calendarLink != null ||
              root.skippedRecurrenceOccurrences.contains(key) ||
              task.skippedRecurrenceOccurrences.contains(key),
          'subtasks': [
            for (final child
                in family.where((item) => item.parentTaskId == task.id))
              project(child),
          ],
        };
    return {
      ...project(root),
      'task_version': _kindleVersion(root, key),
      'root_task_id': root.id,
    };
  }

  Map<String, dynamic> _kindleAgenda(DateTime start) {
    final today = logicalDate();
    final now = DateTime.now();
    return {
      'protocol_version': 1,
      'logical_date': _occurrenceKey(today),
      'server_now': now.toUtc().toIso8601String(),
      'server_epoch': now.millisecondsSinceEpoch ~/ 1000,
      'day_valid_until': DateTime(
                  now.year,
                  now.month,
                  now.day + (now.hour < _daySettings.dayEndsAtHour ? 0 : 1),
                  _daySettings.dayEndsAtHour)
              .millisecondsSinceEpoch ~/
          1000,
      'utc_offset_minutes': now.timeZoneOffset.inMinutes,
      'day_ends_at_hour': _daySettings.dayEndsAtHour,
      'manual_logical_date': _activeManualLogicalDate(now) != null,
      'days': [
        for (var index = 0; index < 7; index++)
          for (final day in [
            DateTime(start.year, start.month, start.day + index)
          ])
            {
              'date': _occurrenceKey(day),
              'tasks': [
                for (final task in tasksForDate(day))
                  _kindleTask(task, _occurrenceKey(day)),
              ],
            },
      ],
    };
  }

  Future<Map<String, dynamic>> _completeKindleGroup(
      Map<String, dynamic> args, String requestId, String fingerprint) async {
    final key = args['occurrence_date'];
    final parsed = key is String ? DateTime.tryParse(key) : null;
    if (parsed == null ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key as String) ||
        _occurrenceKey(parsed) != key ||
        parsed.isAfter(logicalDate())) {
      throw const FormatException(
          'La fecha de la marca no es válida o es futura.');
    }
    final ids = args['task_ids'];
    if (ids is! List ||
        ids.isEmpty ||
        ids.length > 200 ||
        ids.any((id) => id is! String) ||
        ids.toSet().length != ids.length ||
        args['root_task_id'] is! String ||
        args['expected_version'] is! String) {
      throw const FormatException('El grupo de tareas no es válido.');
    }
    final root = taskById(args['root_task_id'] as String);
    Map<String, dynamic> conflict(String message) => {
          'status': 'conflict',
          'error': message,
          'current': root == null
              ? null
              : {
                  ..._kindleTask(root, key),
                  if (root.isSubtask) 'blocked': true,
                },
          'request_id': requestId,
          'savedLocally': false,
        };
    if (root == null) return conflict('La tarea principal ya no existe.');
    if (root.isSubtask) {
      return conflict(
          'La tarea principal ahora pertenece a otra familia. Revísala en Todo.');
    }
    final family = _kindleFamily(root);
    final members = {for (final task in family) task.id: task};
    if (ids.any(
        (id) => !members.containsKey(id) && taskById(id as String) != null)) {
      return conflict(
          'Las tareas ya no pertenecen a la misma familia. Revisa las marcas.');
    }
    if (ids.any((id) => !members.containsKey(id))) {
      return conflict('Una tarea ya no pertenece al grupo. Revisa las marcas.');
    }
    final selected = ids.map((id) => members[id]!).toList();
    final affected = <TaskModel>{};
    for (final task in selected) {
      affected.addAll(_kindleFamily(task));
    }
    if (root.status == TaskStatus.archived ||
        root.calendarLink != null ||
        affected.any((task) =>
            task.status == TaskStatus.archived || task.calendarLink != null) ||
        root.skippedRecurrenceOccurrences.contains(key) ||
        affected
            .any((task) => task.skippedRecurrenceOccurrences.contains(key))) {
      return conflict(
          'La tarea está omitida, archivada o enlazada al calendario. Revísala en Todo.');
    }
    final allDone = selected.every((task) => _kindleCompleted(task, root, key));
    if (!allDone && args['expected_version'] != _kindleVersion(root, key)) {
      return conflict(
          'La tarea cambió desde la consulta. Revisa la versión actual.');
    }
    if (!allDone &&
        (root.recurrence.isRecurring
            ? !_recursOnDay(root, parsed)
            : root.scheduledAt != null &&
                DateTime(root.scheduledAt!.year, root.scheduledAt!.month,
                        root.scheduledAt!.day)
                    .isAfter(parsed))) {
      return conflict('La tarea no corresponde a la fecha de la marca.');
    }
    // Validar el grupo completo antes de aplicar una sola marca.
    if (!allDone) {
      final now = DateTime.now();
      for (final task in affected) {
        if (_kindleCompleted(task, root, key)) continue;
        if (root.recurrence.isRecurring || task.recurrence.isRecurring) {
          _setRecurringOccurrenceCompleted(task.id, key, completed: true);
        } else {
          final index = _tasks.indexWhere((item) => item.id == task.id);
          _tasks[index] =
              task.copyWith(status: TaskStatus.completed, completedAt: now);
        }
      }
    }
    return _finishAgentOperation(requestId, fingerprint, {
      'status': 'saved',
      'occurrence_date': key,
      'task_ids': ids,
    });
  }
}
