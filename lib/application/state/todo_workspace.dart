import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/supabase_config.dart';
import '../../core/date/date_helpers.dart';
import '../../data/local_store.dart';
import '../../data/repositories/calendar_service_repository.dart';
import '../../data/repositories/local_todo_state_repository.dart';
import '../../data/repositories/notification_service_repository.dart';
import '../../data/repositories/supabase_cloud_sync_repository.dart';
import '../../domain/models.dart';
import '../../domain/repositories/calendar_repository.dart';
import '../../domain/repositories/cloud_sync_repository.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/repositories/todo_state_repository.dart';
import '../../services/calendar_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_cloud_service.dart';
import '../../services/task_scheduler_service.dart';

class TodoWorkspace extends ChangeNotifier {
  TodoWorkspace._(
    this._store,
    this._cloudService,
    this._calendarService,
    this._notificationService,
    this._scheduler,
  );

  static Future<TodoWorkspace> create() async {
    final controller = TodoWorkspace._(
      LocalTodoStateRepository(LocalStore()),
      SupabaseCloudSyncRepository(SupabaseCloudService()),
      CalendarServiceRepository(createCalendarService()),
      NotificationServiceRepository(createNotificationService()),
      TaskSchedulerService(),
    );
    await controller._load();
    return controller;
  }

  @visibleForTesting
  static TodoWorkspace createForTest({AppStateSnapshot? snapshot}) {
    final controller = TodoWorkspace._(
      LocalTodoStateRepository(LocalStore()),
      SupabaseCloudSyncRepository(SupabaseCloudService()),
      CalendarServiceRepository(createCalendarService()),
      NotificationServiceRepository(createNotificationService()),
      TaskSchedulerService(),
    );
    if (snapshot != null) {
      controller._applySnapshot(snapshot);
      controller._loadedFromPersistence = true;
    } else {
      controller._seed();
    }
    return controller;
  }

  final TodoStateRepository _store;
  final CloudSyncRepository _cloudService;
  final CalendarRepository _calendarService;
  final NotificationRepository _notificationService;
  final TaskSchedulerService _scheduler;
  final Random _random = Random();

  final List<TaskModel> _tasks = <TaskModel>[];
  final List<CategoryModel> _categories = <CategoryModel>[];
  final List<ProjectModel> _projects = <ProjectModel>[];
  final List<QuickNote> _notes = <QuickNote>[];
  final List<CalendarEventModel> _calendarEvents = <CalendarEventModel>[];

  DaySettings _daySettings = const DaySettings();
  DeviceNotificationSettings _notificationSettings =
      const DeviceNotificationSettings();
  CalendarIntegrationSettings _calendarSettings =
      const CalendarIntegrationSettings();
  CalendarAccount? _calendarAccount;
  AppSection _section = AppSection.today;
  TodaySort _todaySort = TodaySort.manual;
  AppVisualMode _visualMode = AppVisualMode.classic;
  DateTime? _lastSavedAt;
  bool _loadedFromPersistence = false;
  bool _calendarBusy = false;
  bool _notificationBusy = false;
  bool _cloudBusy = false;
  DateTime? _lastCloudSyncAt;
  Timer? _saveDebounce;

  bool get _isFlutterTest {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  List<TaskModel> get tasks => List<TaskModel>.unmodifiable(_tasks);
  List<CategoryModel> get categories =>
      List<CategoryModel>.unmodifiable(_categories);
  List<ProjectModel> get projects => List<ProjectModel>.unmodifiable(_projects);
  List<QuickNote> get notes => List<QuickNote>.unmodifiable(_notes);
  List<CalendarEventModel> get calendarEvents =>
      List<CalendarEventModel>.unmodifiable(_calendarEvents);
  DaySettings get settings => _daySettings;
  DaySettings get daySettings => _daySettings;
  DeviceNotificationSettings get notificationSettings => _notificationSettings;
  CalendarIntegrationSettings get calendarSettings => _calendarSettings;
  CalendarAccount? get calendarAccount => _calendarAccount;
  AppSection get section => _section;
  TodaySort get todaySort => _todaySort;
  AppVisualMode get visualMode => _visualMode;
  DateTime? get lastSavedAt => _lastSavedAt;
  bool get loadedFromPersistence => _loadedFromPersistence;
  bool get calendarBusy => _calendarBusy;
  bool get notificationBusy => _notificationBusy;
  bool get cloudBusy => _cloudBusy;
  bool get cloudConfigured => _cloudService.isConfigured;
  bool get cloudInitialized => _cloudService.isInitialized;
  bool get cloudConnected => _cloudService.isAuthenticated;
  String get cloudEmail => _cloudService.currentEmail;
  String get cloudError => _cloudService.lastError;
  String get cloudSupabaseUrl => _cloudService.url;
  String get cloudAllowedEmail => _cloudService.allowedEmail;
  String get cloudRedirectUrl => _cloudService.redirectUrl;
  DateTime? get lastCloudSyncAt => _lastCloudSyncAt;
  String get calendarError => _calendarSettings.lastError;
  bool get isCalendarConnected => _calendarSettings.connected;

  DateTime get now => DateTime.now();

  void setSection(AppSection value) {
    _section = value;
    _commit();
  }

  void setTodaySort(TodaySort value) {
    _todaySort = value;
    _commit();
  }

  void setVisualMode(AppVisualMode value) {
    if (_visualMode == value) {
      return;
    }
    _visualMode = value;
    _commit();
  }

  DateTime logicalDate([DateTime? instant]) {
    final value = instant ?? now;
    if (value.hour < _daySettings.dayEndsAtHour) {
      final previous = value.subtract(const Duration(days: 1));
      return DateTime(previous.year, previous.month, previous.day);
    }
    return DateTime(value.year, value.month, value.day);
  }

  bool isNextDayVisible([DateTime? instant]) {
    final value = instant ?? now;
    return value.hour >= _daySettings.nextDayVisibleAtHour;
  }

  List<TaskModel> tasksForToday() => _sortTasks(_tasksForDay(logicalDate()));

  List<TaskModel> tasksForDate(DateTime day) => _sortTasks(_tasksForDay(day));

  List<TaskModel> tasksForWeek([DateTime? anchor]) {
    final start = logicalDate(anchor);
    final dates =
        List<DateTime>.generate(7, (index) => start.add(Duration(days: index)));
    return _tasks
        .where((task) =>
            task.status == TaskStatus.active && task.scheduledAt != null)
        .where((task) => dates.any((day) => _sameDay(task.scheduledAt!, day)))
        .toList()
      ..sort((left, right) =>
          (left.scheduledAt ?? start).compareTo(right.scheduledAt ?? start));
  }

  List<CalendarEventModel> calendarEventsForWeek([DateTime? anchor]) {
    final start = logicalDate(anchor);
    final end = start.add(const Duration(days: 7));
    return _calendarEvents
        .where((event) =>
            event.startAt.isBefore(end) && event.endAt.isAfter(start))
        .toList()
      ..sort((left, right) => left.startAt.compareTo(right.startAt));
  }

  List<TaskModel> tasksByCategory(String categoryId) {
    return _tasks
        .where((task) => task.categoryIds.contains(categoryId))
        .toList()
      ..sort((left, right) => left.manualOrder.compareTo(right.manualOrder));
  }

  List<TaskModel> completedTasks() {
    return _tasks
        .where((task) => task.status == TaskStatus.completed && !task.isSubtask)
        .toList()
      ..sort(
        (left, right) => (right.scheduledAt ?? DateTime(1970))
            .compareTo(left.scheduledAt ?? DateTime(1970)),
      );
  }

  List<QuickNote> inboxNotes() {
    return _notes.where((note) => note.status == NoteStatus.inbox).toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
  }

  CategoryModel? categoryById(String id) {
    for (final category in _categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  ProjectModel? projectById(String id) {
    for (final project in _projects) {
      if (project.id == id) {
        return project;
      }
    }
    return null;
  }

  TaskModel? taskById(String id) {
    for (final task in _tasks) {
      if (task.id == id) {
        return task;
      }
    }
    return null;
  }

  QuickNote? noteById(String id) {
    for (final note in _notes) {
      if (note.id == id) {
        return note;
      }
    }
    return null;
  }

  List<TaskModel> subtasksOf(TaskModel task) {
    return _tasks.where((item) => item.parentTaskId == task.id).toList()
      ..sort((left, right) => left.manualOrder.compareTo(right.manualOrder));
  }

  ExportSnapshot exportSnapshot() {
    return ExportSnapshot(
      tasks: tasks,
      categories: categories,
      projects: projects,
      notes: notes,
      calendarEvents: calendarEvents,
      daySettings: daySettings,
      notificationSettings: notificationSettings,
      calendarSettings: calendarSettings,
      visualMode: visualMode,
    );
  }

  TaskModel createTask({
    required String title,
    String? description,
    List<String> categoryIds = const <String>[],
    List<String> projectIds = const <String>[],
    DateTime? scheduledAt,
    TaskPriority priority = TaskPriority.medium,
    RecurrenceRule recurrence = const RecurrenceRule(),
    TaskOrigin origin = TaskOrigin.manual,
    String? parentTaskId,
    ReminderRule? reminderRule,
    CalendarLink? calendarLink,
  }) {
    final task = TaskModel(
      id: _id('task'),
      title: title.trim(),
      description:
          description?.trim().isEmpty == true ? null : description?.trim(),
      categoryIds: List<String>.from(categoryIds),
      projectIds: List<String>.from(projectIds),
      scheduledAt: scheduledAt,
      priority: priority,
      recurrence: recurrence,
      origin: origin,
      manualOrder: _nextManualOrder(parentTaskId: parentTaskId),
      parentTaskId: parentTaskId,
      reminderRule: reminderRule,
      calendarLink: calendarLink,
    );
    _tasks.add(task);
    if (parentTaskId != null) {
      final parentIndex = _tasks.indexWhere((item) => item.id == parentTaskId);
      if (parentIndex != -1) {
        final parent = _tasks[parentIndex];
        _tasks[parentIndex] = parent.copyWith(
          subtaskIds: <String>[...parent.subtaskIds, task.id],
        );
      }
    }
    _commit();
    return task;
  }

  void updateTask(TaskModel updated) {
    final index = _tasks.indexWhere((task) => task.id == updated.id);
    if (index == -1) {
      return;
    }
    _tasks[index] = updated;
    _commit();
  }

  void deleteTask(String taskId) {
    _tasks.removeWhere(
        (task) => task.id == taskId || task.parentTaskId == taskId);
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.subtaskIds.contains(taskId)) {
        _tasks[i] = task.copyWith(
          subtaskIds: task.subtaskIds.where((id) => id != taskId).toList(),
        );
      }
    }
    _commit();
  }

  Future<void> completeTask(String taskId) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    final task = _tasks[index];
    final willComplete = task.status != TaskStatus.completed;
    _tasks[index] = task.copyWith(
      status: willComplete ? TaskStatus.completed : TaskStatus.active,
    );
    if (willComplete && task.recurrence.isRecurring) {
      _tasks.add(
        task.copyWith(
          id: _id('task'),
          status: TaskStatus.active,
          scheduledAt: _nextRecurrence(task),
          manualOrder: _nextManualOrder(),
          collapsed: false,
        ),
      );
    }
    if (task.calendarLink != null && _calendarSettings.connected) {
      await syncTaskToCalendar(taskId, silent: true);
    }
    _commit();
  }

  void reopenTask(String taskId) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(status: TaskStatus.active);
    _commit();
  }

  TaskModel createSubtask(String parentTaskId, String title) {
    return createTask(
      title: title,
      parentTaskId: parentTaskId,
      origin: TaskOrigin.manual,
      scheduledAt: taskById(parentTaskId)?.scheduledAt,
    );
  }

  Future<void> moveTaskToDay(String taskId, DateTime date) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    final source = _tasks[index];
    final current = source.scheduledAt ?? logicalDate();
    _tasks[index] = source.copyWith(
      scheduledAt: DateTime(
          date.year, date.month, date.day, current.hour, current.minute),
      calendarLink:
          source.calendarLink?.copyWith(syncStatus: CalendarSyncStatus.pending),
    );
    _commit();
    if (_tasks[index].calendarLink != null && _calendarSettings.connected) {
      await syncTaskToCalendar(taskId, silent: true);
    }
  }

  void changePriority(String taskId, TaskPriority priority) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(priority: priority);
    _commit();
  }

  void changeManualOrder(List<String> orderedIds) {
    for (var i = 0; i < orderedIds.length; i++) {
      final index = _tasks.indexWhere((task) => task.id == orderedIds[i]);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(manualOrder: i.toDouble());
      }
    }
    _commit();
  }

  void changeCategory(String taskId, List<String> categoryIds) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(categoryIds: categoryIds);
    _commit();
  }

  void changeProject(String taskId, List<String> projectIds) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(projectIds: projectIds);
    _commit();
  }

  ProjectModel createProject({
    required String name,
    String description = '',
    required int colorValue,
    required IconData icon,
    List<String> categoryIds = const <String>[],
  }) {
    final project = ProjectModel(
      id: _id('project'),
      name: name.trim(),
      description: description.trim(),
      colorValue: colorValue,
      icon: icon,
      categoryIds: List<String>.from(categoryIds),
    );
    _projects.add(project);
    _commit();
    return project;
  }

  void updateProject(ProjectModel updated) {
    final index = _projects.indexWhere((project) => project.id == updated.id);
    if (index == -1) {
      return;
    }
    _projects[index] = updated;
    _commit();
  }

  void setProjectStatus(String projectId, ProjectStatus status) {
    final index = _projects.indexWhere((project) => project.id == projectId);
    if (index == -1) {
      return;
    }
    _projects[index] = _projects[index].copyWith(status: status);
    _commit();
  }

  void completeProject(String projectId) {
    setProjectStatus(projectId, ProjectStatus.completed);
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.projectIds.contains(projectId) &&
          task.status == TaskStatus.active) {
        _tasks[i] = task.copyWith(status: TaskStatus.completed);
      }
    }
    _commit();
  }

  void cancelProject(String projectId) {
    setProjectStatus(projectId, ProjectStatus.cancelled);
  }

  CategoryModel createCategory({
    required String name,
    String description = '',
    required int colorValue,
    required IconData icon,
  }) {
    final category = CategoryModel(
      id: _id('category'),
      name: name.trim(),
      description: description.trim(),
      colorValue: colorValue,
      icon: icon,
    );
    _categories.add(category);
    _commit();
    return category;
  }

  void updateCategory(CategoryModel updated) {
    final index =
        _categories.indexWhere((category) => category.id == updated.id);
    if (index == -1) {
      return;
    }
    _categories[index] = updated;
    _commit();
  }

  void toggleCategory(String categoryId) {
    final index =
        _categories.indexWhere((category) => category.id == categoryId);
    if (index == -1) {
      return;
    }
    final category = _categories[index];
    _categories[index] = category.copyWith(active: !category.active);
    _commit();
  }

  void deleteCategory(String categoryId) {
    final index =
        _categories.indexWhere((category) => category.id == categoryId);
    if (index == -1) {
      return;
    }
    _categories.removeAt(index);
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.categoryIds.contains(categoryId)) {
        _tasks[i] = task.copyWith(
          categoryIds:
              task.categoryIds.where((id) => id != categoryId).toList(),
        );
      }
    }
    for (var i = 0; i < _projects.length; i++) {
      final project = _projects[i];
      if (project.categoryIds.contains(categoryId)) {
        _projects[i] = project.copyWith(
          categoryIds:
              project.categoryIds.where((id) => id != categoryId).toList(),
        );
      }
    }
    _commit();
  }

  QuickNote createNote(String content, {DateTime? scheduledFor}) {
    final note = QuickNote(
      id: _id('note'),
      content: content.trim(),
      createdAt: now,
      scheduledFor: scheduledFor,
    );
    _notes.insert(0, note);
    _commit();
    return note;
  }

  void updateNote(
    String noteId, {
    required String content,
    DateTime? scheduledFor,
  }) {
    final index = _notes.indexWhere((note) => note.id == noteId);
    if (index == -1) {
      return;
    }
    _notes[index] = _notes[index].copyWith(
      content: content.trim(),
      scheduledFor: scheduledFor,
      clearScheduledFor: scheduledFor == null,
    );
    _commit();
  }

  TaskModel convertNoteToTask(String noteId, {DateTime? scheduledAt}) {
    final note = _notes.firstWhere((item) => item.id == noteId);
    final task = createTask(
      title: _noteTitle(note),
      description: _noteDescription(note),
      origin: TaskOrigin.note,
      scheduledAt: scheduledAt ?? note.scheduledFor ?? _defaultNoteDate(),
      reminderRule: ReminderRule(
        enabled: true,
        minutesBefore: _notificationSettings.defaultMinutesBeforeTask,
      ),
    );
    _markNoteConverted(noteId, persist: false);
    _commit();
    return task;
  }

  ProjectModel convertNoteToProject(String noteId) {
    final note = _notes.firstWhere((item) => item.id == noteId);
    final project = createProject(
      name: _noteTitle(note),
      description: _noteDescription(note) ?? '',
      colorValue: const Color(0xFF607A5A).toARGB32(),
      icon: Icons.folder_open_rounded,
    );
    _markNoteConverted(noteId, persist: false);
    _commit();
    return project;
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
    _markNoteConverted(noteId, persist: false);
    _commit();
    return event;
  }

  void archiveNote(String noteId) {
    final index = _notes.indexWhere((note) => note.id == noteId);
    if (index == -1) {
      return;
    }
    _notes[index] = _notes[index].copyWith(status: NoteStatus.archived);
    _commit();
  }

  void reorganizeDay() {
    final today = tasksForToday();
    final urgent = today
        .where((task) => task.priority == TaskPriority.urgent)
        .map((task) => task.id);
    final high = today
        .where((task) => task.priority == TaskPriority.high)
        .map((task) => task.id);
    final rest = today
        .where((task) =>
            task.priority != TaskPriority.urgent &&
            task.priority != TaskPriority.high)
        .map((task) => task.id);
    changeManualOrder(<String>[...urgent, ...high, ...rest]);
  }

  void reorganizeWeek() {
    final week = tasksForWeek();
    for (final task in week) {
      if (task.priority == TaskPriority.low && task.scheduledAt != null) {
        final index = _tasks.indexWhere((item) => item.id == task.id);
        if (index != -1) {
          _tasks[index] = _tasks[index].copyWith(
            scheduledAt: task.scheduledAt!.add(const Duration(days: 1)),
          );
        }
      }
    }
    _commit();
  }

  void updateSettings(DaySettings value) {
    _daySettings = value;
    _commit();
  }

  Future<void> updateNotificationSettings(
      DeviceNotificationSettings value) async {
    _notificationSettings = value;
    _commit();
  }

  Future<void> updateCalendarSettings(CalendarIntegrationSettings value) async {
    _calendarSettings = value;
    _commit();
  }

  Future<bool> connectCloud() async {
    if (!cloudConfigured) {
      return false;
    }
    _cloudBusy = true;
    notifyListeners();
    try {
      final launched = await _cloudService.signInWithGoogle();
      if (launched && _cloudService.isAuthenticated) {
        await syncWithCloud();
      }
      return launched;
    } catch (_) {
      return false;
    } finally {
      _cloudBusy = false;
      notifyListeners();
    }
  }

  Future<void> disconnectCloud() async {
    _cloudBusy = true;
    notifyListeners();
    try {
      await _cloudService.signOut();
      _lastCloudSyncAt = null;
    } finally {
      _cloudBusy = false;
      notifyListeners();
    }
  }

  Future<void> syncWithCloud() async {
    if (!cloudConfigured) {
      return;
    }
    _cloudBusy = true;
    notifyListeners();
    try {
      final local = _buildSnapshot();
      final remote = await _cloudService.fetchSnapshot();
      if (_shouldPullRemoteSnapshot(local: local, remote: remote)) {
        _applySnapshot(remote!);
        await _store.save(remote);
        _loadedFromPersistence = true;
      } else {
        await _cloudService.pushSnapshot(local);
      }
      _lastCloudSyncAt = DateTime.now();
    } catch (_) {
      // Keep local state intact when cloud sync fails.
    } finally {
      _cloudBusy = false;
      notifyListeners();
    }
  }

  bool _shouldPullRemoteSnapshot({
    required AppStateSnapshot local,
    required AppStateSnapshot? remote,
  }) {
    if (remote == null) {
      return false;
    }
    if (remote.resolvedUpdatedAt.isAfter(local.resolvedUpdatedAt)) {
      return true;
    }

    final remoteOwner = remote.lastModifiedBy.trim().toLowerCase();
    final localOwner = local.lastModifiedBy.trim().toLowerCase();
    final currentOwner = _cloudService.currentEmail.trim().toLowerCase();
    final localLooksUnsynced =
        localOwner.isEmpty || localOwner == 'local-device';
    final remoteBelongsToSignedUser =
        currentOwner.isNotEmpty && remoteOwner == currentOwner;

    if (localLooksUnsynced && remoteBelongsToSignedUser) {
      return true;
    }

    final remoteHasUserState =
        remoteOwner.isNotEmpty && remoteOwner != 'local-device';
    final localIsSeededDemo =
        local.tasks.any((task) => task.id == 'task-reset') ||
            local.projects.any((project) => project.id == 'project-reset') ||
            local.notes.any((note) => note.id == 'note-1');

    if (localLooksUnsynced && localIsSeededDemo && remoteHasUserState) {
      return true;
    }

    return false;
  }

  void toggleTaskCollapse(String taskId) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(collapsed: !_tasks[index].collapsed);
    _commit();
  }

  Future<bool> requestNotificationPermissions() async {
    _notificationBusy = true;
    notifyListeners();
    try {
      final granted = await _notificationService.requestPermissions();
      _notificationSettings = _notificationSettings.copyWith(
        webPermissionGranted: granted,
        windowsPermissionGranted: granted,
      );
      _commit();
      return granted;
    } finally {
      _notificationBusy = false;
      notifyListeners();
    }
  }

  Future<bool> connectCalendar() async {
    _calendarBusy = true;
    notifyListeners();
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
      notifyListeners();
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
          reminderRule: ReminderRule(
            enabled: true,
            minutesBefore: _notificationSettings.defaultMinutesBeforeTask,
          ),
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

  void setTaskReminder(String taskId, ReminderRule reminder) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(reminderRule: reminder);
    _commit();
  }

  void clearTaskReminder(String taskId) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(clearReminderRule: true);
    _commit();
  }

  Future<void> rescheduleTaskReminders() async {
    final plans = _scheduler.buildPlans(
      tasks: tasks,
      notes: notes,
      daySettings: daySettings,
      notificationSettings: notificationSettings,
      now: DateTime.now(),
    );
    await _notificationService.syncSchedules(
      plans: plans,
      notificationSettings: notificationSettings,
    );
  }

  bool importStateFromJson(String rawJson) {
    try {
      final decoded = (jsonDecode(rawJson) as Map<dynamic, dynamic>)
          .cast<String, dynamic>();
      final snapshot = AppStateSnapshot.fromJson(decoded);
      _applySnapshot(snapshot);
      _loadedFromPersistence = true;
      _commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> resetToSeed() async {
    _tasks.clear();
    _categories.clear();
    _projects.clear();
    _notes.clear();
    _calendarEvents.clear();
    _calendarAccount = null;
    _daySettings = const DaySettings();
    _notificationSettings = const DeviceNotificationSettings();
    _calendarSettings = const CalendarIntegrationSettings();
    _section = AppSection.today;
    _todaySort = TodaySort.manual;
    _loadedFromPersistence = false;
    await _calendarService.disconnect();
    await _store.clearCalendarSession();
    _seed();
    _commit();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    await SupabaseConfig.load();
    final persisted = await _store.load();
    if (persisted != null) {
      _applySnapshot(persisted);
      _loadedFromPersistence = true;
    } else {
      _seed();
    }
    final session = await _store.loadCalendarSession();
    await _calendarService.restoreSession(session);
    _calendarAccount = await _calendarService.getAccount();
    if (_calendarAccount != null) {
      _calendarSettings = _calendarSettings.copyWith(
        connected: true,
        connectedEmail: _calendarAccount!.email,
      );
      await refreshCalendarEvents();
    }
    await _cloudService.initialize();
    if (_cloudService.isAuthenticated) {
      await syncWithCloud();
    }
    if (!_isFlutterTest) {
      await _notificationService.initialize();
      await rescheduleTaskReminders();
    }
  }

  void _applySnapshot(AppStateSnapshot snapshot) {
    _tasks
      ..clear()
      ..addAll(snapshot.tasks);
    _categories
      ..clear()
      ..addAll(snapshot.categories);
    _projects
      ..clear()
      ..addAll(snapshot.projects);
    _notes
      ..clear()
      ..addAll(snapshot.notes);
    _calendarEvents
      ..clear()
      ..addAll(snapshot.calendarEvents);
    _daySettings = snapshot.daySettings;
    _notificationSettings = snapshot.notificationSettings;
    _calendarSettings = snapshot.calendarSettings;
    _section = snapshot.section;
    _todaySort = snapshot.todaySort;
    _visualMode = snapshot.visualMode;
  }

  void _commit() {
    notifyListeners();
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), () async {
      await _persist();
      if (!_isFlutterTest) {
        await rescheduleTaskReminders();
      }
    });
  }

  Future<void> _persist() async {
    final snapshot = _buildSnapshot();
    await _store.save(snapshot);
    if (_cloudService.isAuthenticated) {
      try {
        await _cloudService.pushSnapshot(snapshot);
        _lastCloudSyncAt = DateTime.now();
      } catch (_) {
        // Local persistence remains the primary safety net on Windows.
      }
    }
    final session = await _calendarService.exportSession();
    if (session == null) {
      await _store.clearCalendarSession();
    } else {
      await _store.saveCalendarSession(session);
    }
    _lastSavedAt = DateTime.now();
    notifyListeners();
  }

  AppStateSnapshot _buildSnapshot() {
    return AppStateSnapshot(
      tasks: tasks,
      categories: categories,
      projects: projects,
      notes: notes,
      calendarEvents: calendarEvents,
      daySettings: daySettings,
      notificationSettings: notificationSettings,
      calendarSettings: calendarSettings,
      section: section,
      todaySort: todaySort,
      visualMode: visualMode,
      updatedAt: DateTime.now(),
      schemaVersion: 1,
      lastModifiedBy: _cloudService.currentEmail.isNotEmpty
          ? _cloudService.currentEmail
          : 'local-device',
    );
  }

  List<TaskModel> _tasksForDay(DateTime day) {
    return _tasks
        .where((task) => task.status == TaskStatus.active)
        .where((task) => !task.isSubtask)
        .where((task) {
      final scheduled = task.scheduledAt;
      if (scheduled == null) {
        return true;
      }
      return _sameDay(scheduled, day);
    }).toList();
  }

  List<TaskModel> _sortTasks(List<TaskModel> list) {
    final sorted = List<TaskModel>.from(list);
    switch (_todaySort) {
      case TodaySort.manual:
        sorted.sort(
            (left, right) => left.manualOrder.compareTo(right.manualOrder));
        break;
      case TodaySort.category:
        sorted.sort((left, right) =>
            _primaryCategory(left).compareTo(_primaryCategory(right)));
        break;
      case TodaySort.time:
        sorted.sort(
          (left, right) => (left.scheduledAt ?? logicalDate())
              .compareTo(right.scheduledAt ?? logicalDate()),
        );
        break;
      case TodaySort.project:
        sorted.sort((left, right) =>
            _primaryProject(left).compareTo(_primaryProject(right)));
        break;
      case TodaySort.priority:
        sorted.sort((left, right) =>
            right.priority.index.compareTo(left.priority.index));
        break;
    }
    return sorted;
  }

  String _primaryCategory(TaskModel task) {
    if (task.categoryIds.isEmpty) {
      return 'zzz';
    }
    return categoryById(task.categoryIds.first)?.name ?? 'zzz';
  }

  String _primaryProject(TaskModel task) {
    if (task.projectIds.isEmpty) {
      return 'zzz';
    }
    return projectById(task.projectIds.first)?.name ?? 'zzz';
  }

  double _nextManualOrder({String? parentTaskId}) {
    final pool = _tasks.where((task) => task.parentTaskId == parentTaskId);
    if (pool.isEmpty) {
      return 0;
    }
    return pool.map((task) => task.manualOrder).reduce(max) + 1;
  }

  DateTime _nextRecurrence(TaskModel task) {
    final source = task.scheduledAt ?? logicalDate();
    final reference = logicalDate(now);
    final base = source.isBefore(reference) ? reference : source;
    switch (task.recurrence.type) {
      case RecurrenceType.none:
        return base;
      case RecurrenceType.daily:
        return base.add(Duration(days: task.recurrence.interval));
      case RecurrenceType.everyXDays:
        return base.add(Duration(days: task.recurrence.interval));
      case RecurrenceType.weekly:
        return base.add(Duration(days: 7 * task.recurrence.interval));
      case RecurrenceType.yearly:
        return DateTime(
          base.year + task.recurrence.interval,
          base.month,
          base.day,
          base.hour,
          base.minute,
        );
    }
  }

  bool _sameDay(DateTime left, DateTime right) {
    return isSameCalendarDay(left, right);
  }

  String _id(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(9999)}';
  }

  DateTime _defaultNoteDate() {
    final day = logicalDate();
    return DateTime(day.year, day.month, day.day, 10);
  }

  String _noteTitle(QuickNote note) {
    final lines = note.content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return 'Nota';
    }
    return lines.first;
  }

  String? _noteDescription(QuickNote note) {
    final lines = note.content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length <= 1) {
      return null;
    }
    return lines.skip(1).join('\n');
  }

  void _markNoteConverted(String noteId, {bool persist = true}) {
    final index = _notes.indexWhere((note) => note.id == noteId);
    if (index == -1) {
      return;
    }
    _notes[index] = _notes[index].copyWith(status: NoteStatus.converted);
    if (persist) {
      _commit();
    }
  }

  void _seed() {
    final categories = <CategoryModel>[
      CategoryModel(
        id: 'cat-home',
        name: 'Casa',
        description: 'Categoría base para probar edición y organización.',
        colorValue: const Color(0xFF607A5A).toARGB32(),
        icon: Icons.home_rounded,
      ),
    ];
    _categories.addAll(categories);

    final projects = <ProjectModel>[
      ProjectModel(
        id: 'project-bathroom',
        name: 'Fix bathroom cabinet',
        description: 'Sort products, measure shelves and move overflow.',
        colorValue: const Color(0xFFAA5C4D).toARGB32(),
        icon: Icons.handyman_rounded,
        categoryIds: const <String>['cat-home'],
      ),
      ProjectModel(
        id: 'project-reset',
        name: 'Weekly reset',
        description: 'Bring home systems back to baseline without overload.',
        colorValue: const Color(0xFF607A5A).toARGB32(),
        icon: Icons.refresh_rounded,
        categoryIds: const <String>['cat-home'],
      ),
    ];
    _projects.addAll(projects);

    final today = logicalDate(now);

    _tasks.addAll(<TaskModel>[
      TaskModel(
        id: 'task-reset',
        title: 'Weekly reset',
        description: 'Clean inbox, review calendar, set the top three tasks.',
        categoryIds: const <String>['cat-home'],
        projectIds: const <String>['project-reset'],
        scheduledAt: DateTime(today.year, today.month, today.day, 8),
        priority: TaskPriority.urgent,
        origin: TaskOrigin.project,
        manualOrder: 0,
        subtaskIds: const <String>['task-reset-sub-1', 'task-reset-sub-2'],
        reminderRule: ReminderRule(
          enabled: true,
          minutesBefore: _notificationSettings.defaultMinutesBeforeTask,
        ),
      ),
      TaskModel(
        id: 'task-reset-sub-1',
        title: 'Clear quick captures',
        categoryIds: const <String>['cat-home'],
        projectIds: const <String>['project-reset'],
        scheduledAt: DateTime(today.year, today.month, today.day, 8),
        priority: TaskPriority.high,
        parentTaskId: 'task-reset',
        manualOrder: 0,
      ),
      TaskModel(
        id: 'task-reset-sub-2',
        title: 'Block focus time on calendar',
        categoryIds: const <String>['cat-home'],
        projectIds: const <String>['project-reset'],
        scheduledAt: DateTime(today.year, today.month, today.day, 8, 30),
        priority: TaskPriority.medium,
        parentTaskId: 'task-reset',
        manualOrder: 1,
      ),
      TaskModel(
        id: 'task-laundry',
        title: 'Laundry and fold',
        categoryIds: const <String>['cat-home'],
        scheduledAt: DateTime(today.year, today.month, today.day, 18, 30),
        priority: TaskPriority.medium,
        manualOrder: 1,
      ),
      TaskModel(
        id: 'task-cabinet',
        title: 'Empty bathroom cabinet top shelf',
        categoryIds: const <String>['cat-home'],
        projectIds: const <String>['project-bathroom'],
        scheduledAt: DateTime(today.year, today.month, today.day, 16),
        priority: TaskPriority.high,
        origin: TaskOrigin.project,
        manualOrder: 2,
      ),
      TaskModel(
        id: 'task-bed',
        title: 'Make the bed',
        categoryIds: const <String>['cat-home'],
        scheduledAt: DateTime(today.year, today.month, today.day, 10),
        priority: TaskPriority.low,
        recurrence: const RecurrenceRule(type: RecurrenceType.daily),
        origin: TaskOrigin.recurring,
        manualOrder: 3,
        reminderRule: ReminderRule(
          enabled: true,
          minutesBefore: _notificationSettings.defaultMinutesBeforeTask,
        ),
      ),
      TaskModel(
        id: 'task-completed',
        title: 'Order detergents',
        categoryIds: const <String>['cat-home'],
        scheduledAt: DateTime(today.year, today.month, today.day),
        priority: TaskPriority.medium,
        status: TaskStatus.completed,
        manualOrder: 4,
      ),
    ]);

    _notes.addAll(<QuickNote>[
      QuickNote(
        id: 'note-1',
        content: 'Check if the bathroom mirror light can be replaced this week',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      QuickNote(
        id: 'note-2',
        content: 'Maybe create a small gym recovery project',
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
    ]);
  }
}
