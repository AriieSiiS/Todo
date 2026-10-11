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
      _calendarEvents[index] = event.copyWith(
        startAt: start,
        endAt: start.add(event.endAt.difference(event.startAt)),
      );
      _commit();
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
    final event = CalendarEventModel(
      id: _id('event'),
      calendarId: _calendarSettings.selectedCalendarId.isNotEmpty
          ? _calendarSettings.selectedCalendarId
          : 'local-inbox',
      title: _noteTitle(note),
      startAt: resolvedStart,
      endAt: resolvedStart.add(duration),
      description: _noteDescription(note),
    );
    _calendarEvents.add(event);
    _commit();
    return event;
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
        await refreshCalendarEvents();
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
    _calendarEvents.clear();
    _calendarSettings = _calendarSettings.copyWith(
      connected: false,
      connectedEmail: '',
      lastError: '',
    );
    await _store.clearCalendarSession();
    _commit();
  }

  Future<void> refreshCalendarEvents() async {
    if (!_calendarSettings.connected) {
      return;
    }
    try {
      final events = await _calendarService.listEvents(
        settings: _calendarSettings,
        from: logicalDate().subtract(const Duration(days: 1)),
        to: logicalDate().add(const Duration(days: 14)),
      );
      _calendarEvents
        ..clear()
        ..addAll(events);
      _calendarSettings = _calendarSettings.copyWith(lastError: '');
      _commit();
    } catch (error) {
      _calendarSettings =
          _calendarSettings.copyWith(lastError: error.toString());
      _commit();
    }
  }

  Future<void> importCalendarEventsAsTasks(DateTime from, DateTime to) async {
    if (!_calendarSettings.connected) {
      return;
    }
    final events = await _calendarService.listEvents(
      settings: _calendarSettings,
      from: from,
      to: to,
    );
    for (final event in events) {
      final exists = _tasks.any(
        (task) =>
            task.calendarLink?.eventId == event.id &&
            task.calendarLink?.calendarId == event.calendarId,
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
    }
    await refreshCalendarEvents();
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
        await refreshCalendarEvents();
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
