part of 'todo_workspace.dart';

extension TodoWorkspaceCalendario on TodoWorkspace {
  List<CalendarEventModel> calendarEventsForWeek([DateTime? anchor]) {
    final start = logicalDate(anchor);
    final end = start.add(const Duration(days: 7));
    return _calendarEvents
        .where((event) =>
            event.startAt.isBefore(end) && event.endAt.isAfter(start))
        .toList()
      ..sort((left, right) => left.startAt.compareTo(right.startAt));
  }

  Future<void> rescheduleCalendarEntry({
    required String id,
    required bool isTask,
    required DateTime destination,
    bool preserveTime = false,
  }) async {
    if (isTask) {
      final index = _tasks.indexWhere((task) => task.id == id);
      if (index == -1) return;
      final task = _tasks[index];
      final current = task.scheduledAt ?? destination;
      final start = preserveTime
          ? DateTime(destination.year, destination.month, destination.day,
              current.hour, current.minute)
          : destination;
      _tasks[index] = task.copyWith(
        scheduledAt: start,
        calendarLink:
            task.calendarLink?.copyWith(syncStatus: CalendarSyncStatus.pending),
      );
      _commit();
      if (task.calendarLink != null && _calendarSettings.connected) {
        await syncTaskToCalendar(id, silent: true);
      }
    } else {
      final index = _calendarEvents.indexWhere((event) => event.id == id);
      if (index == -1) return;
      final event = _calendarEvents[index];
      final start = preserveTime
          ? DateTime(destination.year, destination.month, destination.day,
              event.startAt.hour, event.startAt.minute)
          : destination;
      _calendarEvents[index] = _markCalendarEventChanged(event.copyWith(
        startAt: start,
        endAt: start.add(event.endAt.difference(event.startAt)),
      ));
      _commit();
      _requestCalendarSync();
    }
  }

  void reserveTaskTimeBlock(String taskId, DateTime start, int minutes) {
    if (minutes < 1 || minutes > 1440) {
      throw ArgumentError('La duración debe estar entre 1 y 1440 minutos.');
    }
    final task = _tasks.where((task) => task.id == taskId).firstOrNull;
    if (task == null) return;
    updateTask(task.copyWith(scheduledAt: start, timeBlockMinutes: minutes));
  }

  List<String> calendarConflicts({
    required DateTime start,
    required DateTime end,
    String? excludeTaskId,
    String? excludeEventId,
  }) {
    bool overlaps(DateTime from, DateTime to) =>
        from.isBefore(end) && to.isAfter(start);
    final conflicts = <String>[];
    for (final task in _tasks) {
      if (task.id == excludeTaskId ||
          task.status != TaskStatus.active ||
          task.scheduledAt == null ||
          (task.timeBlockMinutes ?? 0) <= 0) {
        continue;
      }
      if (overlaps(task.scheduledAt!,
          task.scheduledAt!.add(Duration(minutes: task.timeBlockMinutes!)))) {
        conflicts.add(task.title);
      }
    }
    for (final event in _calendarEvents) {
      if (event.id == excludeEventId ||
          event.originTaskId == excludeTaskId && excludeTaskId != null) {
        continue;
      }
      final allDay = event.startAt.hour == 0 &&
          event.startAt.minute == 0 &&
          event.endAt.difference(event.startAt) >= const Duration(hours: 24);
      if (!allDay && overlaps(event.startAt, event.endAt)) {
        conflicts.add(event.title);
      }
    }
    return conflicts;
  }

  CalendarEventModel convertNoteToCalendarEvent(
    String noteId, {
    DateTime? startAt,
    Duration duration = const Duration(hours: 1),
  }) {
    final note = _notes.firstWhere((item) => item.id == noteId);
    final resolvedStart = startAt ?? note.scheduledFor ?? _defaultNoteDate();
    return createCalendarEvent(
      title: _noteTitle(note),
      startAt: resolvedStart,
      endAt: resolvedStart.add(duration),
      description: _noteDescription(note),
    );
  }

  /// Crea un evento en Todo; se envía a Google en la siguiente sincronización.
  CalendarEventModel createCalendarEvent({
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    String? description,
  }) {
    final cleanDescription = description?.trim();
    final event = _markCalendarEventChanged(CalendarEventModel(
      id: _id('event'),
      calendarId: _calendarSettings.selectedCalendarId.isNotEmpty
          ? _calendarSettings.selectedCalendarId
          : 'local-inbox',
      title: title.trim().isEmpty ? 'Evento sin título' : title.trim(),
      startAt: startAt,
      endAt: endAt != null && endAt.isAfter(startAt)
          ? endAt
          : startAt.add(const Duration(hours: 1)),
      description: cleanDescription == null || cleanDescription.isEmpty
          ? null
          : cleanDescription,
    ));
    _calendarEvents.add(event);
    _commit();
    _requestCalendarSync();
    return event;
  }

  void updateCalendarEvent(CalendarEventModel updated) {
    final index = _calendarEvents.indexWhere((event) => event.id == updated.id);
    if (index == -1) return;
    final start = updated.startAt;
    final end = updated.endAt.isAfter(start)
        ? updated.endAt
        : start.add(const Duration(hours: 1));
    _calendarEvents[index] =
        _markCalendarEventChanged(updated.copyWith(endAt: end));
    _commit();
    _requestCalendarSync();
  }

  void deleteCalendarEvent(String id) {
    final index = _calendarEvents.indexWhere((event) => event.id == id);
    if (index == -1) return;
    final googleId = _calendarEvents.removeAt(index).googleEventId;
    if (googleId != null) {
      _calendarSettings = _calendarSettings.copyWith(
        pendingDeletions: <String, DateTime>{
          ..._calendarSettings.pendingDeletions,
          googleId: DateTime.now(),
        },
      );
    }
    _commit();
    _requestCalendarSync();
  }

  CalendarEventModel _markCalendarEventChanged(CalendarEventModel event) =>
      event.originTaskId == null
          ? event.copyWith(localUpdatedAt: DateTime.now())
          : event;

  /// Lanza una sincronización en segundo plano tras un cambio local.
  void _requestCalendarSync() {
    if (_calendarSettings.connected && !_isFlutterTest) {
      unawaited(syncCalendar());
    }
  }

  Future<void> updateCalendarSettings(CalendarIntegrationSettings value) async {
    _calendarSettings = value;
    _commit();
  }

  Future<bool> connectCalendar() async {
    _calendarBusy = true;
    _notifyChanged();
    try {
      final ok = await _calendarService.connect(_calendarSettings);
      final account = await _calendarService.getAccount();
      final error = await _calendarService.getLastError() ?? '';
      _calendarAccount = account;
      _calendarSettings = _calendarSettings.copyWith(
        connected: ok,
        connectedEmail: account?.email ?? '',
        lastError: error,
        selectedCalendarId: account?.calendars
                .firstWhere(
                  (calendar) => calendar.primary,
                  orElse: () => account.calendars.first,
                )
                .id ??
            _calendarSettings.selectedCalendarId,
        selectedCalendarName: account?.calendars
                .firstWhere(
                  (calendar) => calendar.primary,
                  orElse: () => account.calendars.first,
                )
                .name ??
            _calendarSettings.selectedCalendarName,
      );
      if (ok) {
        await syncCalendar();
      } else {
        _commit();
      }
      return ok;
    } finally {
      _calendarBusy = false;
      _notifyChanged();
    }
  }

  Future<void> disconnectCalendar() async {
    await _calendarService.disconnect();
    _calendarAccount = null;
    // Los eventos de Google se retiran; los que solo existen en Todo se conservan.
    _calendarEvents.removeWhere((event) => event.googleEventId != null);
    _calendarSettings = _calendarSettings.copyWith(
      connected: false,
      connectedEmail: '',
      lastError: '',
      syncToken: '',
      pendingDeletions: const <String, DateTime>{},
    );
    await _store.clearCalendarSession();
    _commit();
  }

  /// Sincroniza el calendario principal de Google en ambos sentidos: primero
  /// trae los cambios de Google y después envía los hechos en Todo. Ante un
  /// conflicto gana el cambio más reciente.
  Future<void> syncCalendar() async {
    if (!_calendarSettings.connected) return;
    if (_calendarSyncing) {
      _calendarSyncAgain = true;
      return;
    }
    _calendarSyncing = true;
    _notifyChanged();
    var error = '';
    try {
      await _pullCalendarChanges();
      error = await _pushCalendarChanges();
      _calendarSettings =
          _calendarSettings.copyWith(lastSyncAt: DateTime.now());
    } catch (exception) {
      error = _calendarErrorText(exception);
    } finally {
      _calendarSettings = _calendarSettings.copyWith(lastError: error);
      _calendarSyncing = false;
      _commit();
    }
    if (_calendarSyncAgain) {
      _calendarSyncAgain = false;
      await syncCalendar();
    }
  }

  String _calendarErrorText(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.contains('invalid_grant') || text.contains('invalid_client')
        ? 'Google rechazó la sesión. Desconecta y vuelve a conectar Google Calendar.'
        : text;
  }

  Future<void> _pullCalendarChanges() async {
    final today = logicalDate();
    final from = today.subtract(const Duration(days: 30));
    final to = today.add(const Duration(days: 365));
    final lastFull = _calendarSettings.lastFullSyncAt;
    // La ventana avanza con el tiempo: cada dos meses se vuelve a leer completa.
    final stale =
        lastFull == null || DateTime.now().difference(lastFull).inDays > 60;
    CalendarRemoteDelta delta;
    try {
      delta = await _calendarService.pullEvents(
        syncToken: stale ? '' : _calendarSettings.syncToken,
        from: from,
        to: to,
      );
    } on CalendarSyncTokenExpired {
      // Si Google invalida el token, se parte de cero con la ventana completa.
      delta =
          await _calendarService.pullEvents(syncToken: '', from: from, to: to);
    }
    _applyRemoteCalendarChanges(delta, from, to);
    _calendarSettings = _calendarSettings.copyWith(
      syncToken: delta.syncToken,
      lastFullSyncAt: delta.full ? DateTime.now() : null,
    );
  }

  void _applyRemoteCalendarChanges(
      CalendarRemoteDelta delta, DateTime from, DateTime to) {
    // Los eventos de tareas enlazadas ya aparecen como tarea: no se duplican.
    final linkedToTask = <String>{
      for (final task in _tasks)
        if (task.calendarLink != null) task.calendarLink!.eventId,
    };
    final pending =
        Map<String, DateTime>.of(_calendarSettings.pendingDeletions);
    final seen = <String>{};
    for (final change in delta.changes) {
      final id = change.googleEventId;
      seen.add(id);
      final index =
          _calendarEvents.indexWhere((event) => event.googleEventId == id);
      final local = index == -1 ? null : _calendarEvents[index];
      final remote = change.event;
      final changedAt = change.updatedAt ?? DateTime.now();

      final deletedAt = pending[id];
      if (deletedAt != null) {
        // Borrado en Todo: solo se anula si Google lo modificó después.
        if (remote == null || !changedAt.isAfter(deletedAt)) continue;
        pending.remove(id);
      }
      final mirrorsTask = remote != null &&
          (remote.originTaskId != null || linkedToTask.contains(id));
      if (remote == null || mirrorsTask) {
        if (local == null) continue;
        final editedAt = local.localUpdatedAt;
        if (remote == null && editedAt != null && editedAt.isAfter(changedAt)) {
          // Lo editado en Todo es más reciente que el borrado: se vuelve a crear.
          _calendarEvents[index] = local.copyWith(clearGoogleEventId: true);
        } else {
          _calendarEvents.removeAt(index);
        }
        continue;
      }
      if (local == null) {
        _calendarEvents.add(remote);
        continue;
      }
      final editedAt = local.localUpdatedAt;
      final remoteWins = editedAt == null ||
          (remote.googleUpdatedAt ?? changedAt).isAfter(editedAt);
      if (remoteWins) _calendarEvents[index] = remote.copyWith(id: local.id);
    }
    if (delta.full) {
      // Lo que Google ya no devuelve dentro de la ventana se ha borrado allí.
      _calendarEvents.removeWhere((event) =>
          event.googleEventId != null &&
          event.localUpdatedAt == null &&
          !seen.contains(event.googleEventId) &&
          event.startAt.isBefore(to) &&
          event.endAt.isAfter(from));
    }
    _calendarSettings = _calendarSettings.copyWith(pendingDeletions: pending);
  }

  /// Envía a Google los borrados, creaciones y ediciones hechos en Todo.
  /// Devuelve el primer error, si lo hubo, sin detener el resto.
  Future<String> _pushCalendarChanges() async {
    var error = '';
    for (final id in _calendarSettings.pendingDeletions.keys.toList()) {
      try {
        await _calendarService.deleteEvent(id);
        final rest =
            Map<String, DateTime>.of(_calendarSettings.pendingDeletions)
              ..remove(id);
        _calendarSettings = _calendarSettings.copyWith(pendingDeletions: rest);
      } catch (exception) {
        if (error.isEmpty) error = _calendarErrorText(exception);
      }
    }
    for (final event in List<CalendarEventModel>.of(_calendarEvents)) {
      final needsPush = event.originTaskId == null &&
          (event.googleEventId == null || event.localUpdatedAt != null);
      if (!needsPush) continue;
      try {
        final pushed = await _calendarService.pushEvent(event);
        final index = _calendarEvents.indexWhere((item) => item.id == event.id);
        if (index == -1) continue;
        final current = _calendarEvents[index];
        // Si se volvió a editar durante el envío, el cambio queda pendiente.
        _calendarEvents[index] = current.localUpdatedAt == event.localUpdatedAt
            ? pushed
            : current.copyWith(
                googleEventId: pushed.googleEventId,
                googleUpdatedAt: pushed.googleUpdatedAt,
              );
      } catch (exception) {
        if (error.isEmpty) error = _calendarErrorText(exception);
      }
    }
    return error;
  }

  /// Convierte en tareas los eventos de Google del rango que aún no lo son.
  Future<void> importCalendarEventsAsTasks(DateTime from, DateTime to) async {
    if (!_calendarSettings.connected) {
      return;
    }
    await syncCalendar();
    final candidates = _calendarEvents.where((event) =>
        event.googleEventId != null &&
        event.originTaskId == null &&
        !event.startAt.isBefore(from) &&
        !event.startAt.isAfter(to));
    for (final event in candidates.toList()) {
      final exists = _tasks.any(
        (task) => task.calendarLink?.eventId == event.googleEventId,
      );
      if (exists) {
        continue;
      }
      final imported = await _calendarService.importEventAsTask(event: event);
      _tasks.add(
        imported.copyWith(
          id: _id('task'),
          manualOrder: _nextManualOrder(),
          reminderRules: <ReminderRule>[
            ReminderRule(
              enabled: true,
              minutesBefore: _notificationSettings.defaultMinutesBeforeTask,
            ),
          ],
        ),
      );
      // Desde ahora el evento se muestra como tarea, no como evento suelto.
      _calendarEvents.removeWhere((item) => item.id == event.id);
    }
    _commit();
  }

  Future<void> syncTaskToCalendar(String taskId, {bool silent = false}) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1 || !_calendarSettings.connected) {
      return;
    }
    final task = _tasks[index];
    try {
      final link = await _calendarService.upsertTaskEvent(
        settings: _calendarSettings,
        task: task,
      );
      _tasks[index] = task.copyWith(calendarLink: link);
      _calendarSettings = _calendarSettings.copyWith(lastError: '');
      if (!silent) {
        await syncCalendar();
      }
      _commit();
    } catch (error) {
      _tasks[index] = task.copyWith(
        calendarLink:
            task.calendarLink?.copyWith(syncStatus: CalendarSyncStatus.error),
      );
      _calendarSettings =
          _calendarSettings.copyWith(lastError: error.toString());
      _commit();
    }
  }

  void linkTaskToCalendarEvent(String taskId, CalendarLink link) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(calendarLink: link);
    _commit();
  }

  void unlinkTaskFromCalendarEvent(String taskId) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(clearCalendarLink: true);
    _commit();
  }
}
