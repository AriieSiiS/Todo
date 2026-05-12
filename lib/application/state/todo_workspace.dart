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
import '../../services/task_feedback_service.dart';
import '../../services/task_scheduler_service.dart';

class TodoWorkspace extends ChangeNotifier {
  TodoWorkspace._(
    this._store,
    this._cloudService,
    this._calendarService,
    this._notificationService,
    this._scheduler,
    this._feedback,
  );

  static Future<TodoWorkspace> create() async {
    final controller = TodoWorkspace._(
      LocalTodoStateRepository(LocalStore()),
      SupabaseCloudSyncRepository(SupabaseCloudService()),
      CalendarServiceRepository(createCalendarService()),
      NotificationServiceRepository(createNotificationService()),
      TaskSchedulerService(),
      TaskFeedbackService(),
    );
    await controller._load();
    return controller;
  }

  static const List<AppSection> defaultNavOrder = <AppSection>[
    AppSection.today,
    AppSection.inbox,
    AppSection.projects,
    AppSection.categories,
    AppSection.expenses,
    AppSection.calendar,
    AppSection.library,
    AppSection.completed,
    AppSection.settings,
  ];

  @visibleForTesting
  static TodoWorkspace createForTest({AppStateSnapshot? snapshot}) {
    final controller = TodoWorkspace._(
      LocalTodoStateRepository(LocalStore()),
      SupabaseCloudSyncRepository(SupabaseCloudService()),
      CalendarServiceRepository(createCalendarService()),
      NotificationServiceRepository(createNotificationService()),
      TaskSchedulerService(),
      TaskFeedbackService(),
    );
    if (snapshot != null) {
      controller._applySnapshot(snapshot);
      controller._loadedFromPersistence = true;
    } else {
      controller._clearStateToDefaults();
    }
    return controller;
  }

  final TodoStateRepository _store;
  final CloudSyncRepository _cloudService;
  final CalendarRepository _calendarService;
  final NotificationRepository _notificationService;
  final TaskSchedulerService _scheduler;
  final TaskFeedbackService _feedback;
  final Random _random = Random();

  final List<TaskModel> _tasks = <TaskModel>[];
  final List<CategoryModel> _categories = <CategoryModel>[];
  final List<ProjectModel> _projects = <ProjectModel>[];
  final List<QuickNote> _notes = <QuickNote>[];
  final List<Expense> _expenses = <Expense>[];
  final List<ExpenseCategory> _expenseCategories = <ExpenseCategory>[];
  final List<PaymentMethodModel> _paymentMethods = <PaymentMethodModel>[];
  final List<FixedPayment> _fixedPayments = <FixedPayment>[];
  final List<LibraryItem> _libraryItems = <LibraryItem>[];
  final List<LibraryGoal> _libraryGoals = <LibraryGoal>[];
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
  List<AppSection> _navOrder = List<AppSection>.of(defaultNavOrder);
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
  List<Expense> get expenses => List<Expense>.unmodifiable(_expenses);
  List<ExpenseCategory> get expenseCategories =>
      List<ExpenseCategory>.unmodifiable(_expenseCategories);
  List<PaymentMethodModel> get paymentMethods =>
      List<PaymentMethodModel>.unmodifiable(_paymentMethods);
  List<FixedPayment> get fixedPayments =>
      List<FixedPayment>.unmodifiable(_fixedPayments);
  List<LibraryItem> get libraryItems =>
      List<LibraryItem>.unmodifiable(_libraryItems);
  List<LibraryGoal> get libraryGoals =>
      List<LibraryGoal>.unmodifiable(_libraryGoals);
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
  List<AppSection> get navOrder => List<AppSection>.unmodifiable(_navOrder);
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

  void reorderNavigation(int oldIndex, int newIndex) {
    final next = List<AppSection>.of(_navOrder);
    if (oldIndex < 0 || oldIndex >= next.length) {
      return;
    }
    if (newIndex > next.length) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length), moved);
    _navOrder = _normalizeNavOrder(next);
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
        (left, right) => (right.completedAt ??
                right.scheduledAt ??
                DateTime(1970))
            .compareTo(left.completedAt ?? left.scheduledAt ?? DateTime(1970)),
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
      expenses: expenses,
      expenseCategories: expenseCategories,
      paymentMethods: paymentMethods,
      fixedPayments: fixedPayments,
      libraryItems: libraryItems,
      libraryGoals: libraryGoals,
      calendarEvents: calendarEvents,
      daySettings: daySettings,
      notificationSettings: notificationSettings,
      calendarSettings: calendarSettings,
      visualMode: visualMode,
      navOrder: navOrder,
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

  void deleteTasks(Iterable<String> taskIds) {
    final ids = taskIds.toSet();
    if (ids.isEmpty) {
      return;
    }
    _tasks.removeWhere(
      (task) => ids.contains(task.id) || ids.contains(task.parentTaskId),
    );
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      final filtered =
          task.subtaskIds.where((id) => !ids.contains(id)).toList();
      if (filtered.length != task.subtaskIds.length) {
        _tasks[i] = task.copyWith(subtaskIds: filtered);
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
    final completedAt = willComplete ? DateTime.now() : null;
    _tasks[index] = task.copyWith(
      status: willComplete ? TaskStatus.completed : TaskStatus.active,
      completedAt: completedAt,
      clearCompletedAt: !willComplete,
    );
    if (willComplete && task.recurrence.isRecurring) {
      _tasks.add(
        task.copyWith(
          id: _id('task'),
          status: TaskStatus.active,
          scheduledAt: _nextRecurrence(task),
          manualOrder: _nextManualOrder(),
          collapsed: false,
          clearCompletedAt: true,
        ),
      );
    }
    if (task.calendarLink != null && _calendarSettings.connected) {
      await syncTaskToCalendar(taskId, silent: true);
    }
    if (willComplete) {
      unawaited(_feedback.playTaskCompleted());
    }
    _commit();
  }

  void reopenTask(String taskId) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(
      status: TaskStatus.active,
      clearCompletedAt: true,
    );
    _commit();
  }

  void reopenTasks(Iterable<String> taskIds) {
    final ids = taskIds.toSet();
    if (ids.isEmpty) {
      return;
    }
    var changed = false;
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (!ids.contains(task.id) || task.status != TaskStatus.completed) {
        continue;
      }
      _tasks[i] = task.copyWith(
        status: TaskStatus.active,
        clearCompletedAt: true,
      );
      changed = true;
    }
    if (changed) {
      _commit();
    }
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

  Future<void> moveTasksToDay(Iterable<String> taskIds, DateTime date) async {
    final ids = taskIds.toSet();
    if (ids.isEmpty) {
      return;
    }
    final tasksToSync = <String>[];
    for (var i = 0; i < _tasks.length; i++) {
      final source = _tasks[i];
      if (!ids.contains(source.id)) {
        continue;
      }
      final current = source.scheduledAt ?? logicalDate();
      _tasks[i] = source.copyWith(
        scheduledAt: DateTime(
            date.year, date.month, date.day, current.hour, current.minute),
        calendarLink: source.calendarLink
            ?.copyWith(syncStatus: CalendarSyncStatus.pending),
      );
      if (_tasks[i].calendarLink != null && _calendarSettings.connected) {
        tasksToSync.add(source.id);
      }
    }
    _commit();
    for (final id in tasksToSync) {
      await syncTaskToCalendar(id, silent: true);
    }
  }

  Future<void> completeTasks(Iterable<String> taskIds) async {
    final ids = taskIds.toSet();
    if (ids.isEmpty) {
      return;
    }
    final tasksToSync = <String>[];
    final spawnedTasks = <TaskModel>[];
    var changed = false;
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (!ids.contains(task.id) || task.status == TaskStatus.completed) {
        continue;
      }
      _tasks[i] = task.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime.now(),
      );
      changed = true;
      if (task.recurrence.isRecurring) {
        spawnedTasks.add(
          task.copyWith(
            id: _id('task'),
            status: TaskStatus.active,
            scheduledAt: _nextRecurrence(task),
            manualOrder: _nextManualOrder(),
            collapsed: false,
            clearCompletedAt: true,
          ),
        );
      }
      if (task.calendarLink != null && _calendarSettings.connected) {
        tasksToSync.add(task.id);
      }
    }
    if (spawnedTasks.isNotEmpty) {
      _tasks.addAll(spawnedTasks);
      changed = true;
    }
    if (!changed) {
      return;
    }
    unawaited(_feedback.playTaskCompleted());
    _commit();
    for (final id in tasksToSync) {
      await syncTaskToCalendar(id, silent: true);
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
        _tasks[i] = task.copyWith(
          status: TaskStatus.completed,
          completedAt: DateTime.now(),
        );
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
    _clearStateToDefaults();
    await _calendarService.disconnect();
    await _store.clearCalendarSession();
    _commit();
  }

  ExpenseCategory? expenseCategoryById(String id) {
    for (final category in _expenseCategories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  PaymentMethodModel? paymentMethodById(String id) {
    for (final method in _paymentMethods) {
      if (method.id == id) {
        return method;
      }
    }
    return null;
  }

  Expense? expenseById(String id) {
    for (final expense in _expenses) {
      if (expense.id == id) {
        return expense;
      }
    }
    return null;
  }

  Expense createExpense({
    required DateTime date,
    String concept = '',
    required double amount,
    required String categoryId,
    String? paymentMethodId,
    List<String> projectIds = const <String>[],
    String? note,
    bool isRecurringInstance = false,
    String? fixedPaymentId,
  }) {
    final now = DateTime.now();
    final expense = Expense(
      id: _id('expense'),
      date: DateTime(date.year, date.month, date.day),
      concept: concept.trim().isEmpty ? 'Gasto' : concept.trim(),
      amount: amount,
      categoryId: categoryId,
      paymentMethodId: paymentMethodId,
      projectIds: List<String>.from(projectIds),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      isRecurringInstance: isRecurringInstance,
      fixedPaymentId: fixedPaymentId,
      createdAt: now,
      updatedAt: now,
    );
    _expenses.add(expense);
    _commit();
    return expense;
  }

  void updateExpense(Expense updated) {
    final index = _expenses.indexWhere((expense) => expense.id == updated.id);
    if (index == -1) {
      return;
    }
    _expenses[index] = updated.copyWith(updatedAt: DateTime.now());
    _commit();
  }

  void duplicateExpense(String expenseId) {
    final source = expenseById(expenseId);
    if (source == null) {
      return;
    }
    createExpense(
      date: source.date,
      concept: '${source.concept} copia',
      amount: source.amount,
      categoryId: source.categoryId,
      paymentMethodId: source.paymentMethodId,
      projectIds: source.projectIds,
      note: source.note,
      isRecurringInstance: source.isRecurringInstance,
      fixedPaymentId: source.fixedPaymentId,
    );
  }

  void deleteExpense(String expenseId) {
    _expenses.removeWhere((expense) => expense.id == expenseId);
    _commit();
  }

  ExpenseCategory createExpenseCategory({
    required String name,
    required int colorValue,
    required IconData icon,
  }) {
    final now = DateTime.now();
    final category = ExpenseCategory(
      id: _id('expense-category'),
      name: name.trim(),
      colorValue: colorValue,
      icon: icon,
      createdAt: now,
      updatedAt: now,
    );
    _expenseCategories.add(category);
    _commit();
    return category;
  }

  void updateExpenseCategory(ExpenseCategory updated) {
    final index =
        _expenseCategories.indexWhere((category) => category.id == updated.id);
    if (index == -1) {
      return;
    }
    _expenseCategories[index] = updated.copyWith(updatedAt: DateTime.now());
    _commit();
  }

  PaymentMethodModel createPaymentMethod({
    required String name,
    required IconData icon,
    required int colorValue,
  }) {
    final now = DateTime.now();
    final method = PaymentMethodModel(
      id: _id('payment-method'),
      name: name.trim(),
      icon: icon,
      colorValue: colorValue,
      createdAt: now,
      updatedAt: now,
    );
    _paymentMethods.add(method);
    _commit();
    return method;
  }

  void updatePaymentMethod(PaymentMethodModel updated) {
    final index =
        _paymentMethods.indexWhere((method) => method.id == updated.id);
    if (index == -1) {
      return;
    }
    _paymentMethods[index] = updated.copyWith(updatedAt: DateTime.now());
    _commit();
  }

  FixedPayment createFixedPayment({
    required String name,
    required double amount,
    required String categoryId,
    String? paymentMethodId,
    FixedPaymentFrequency frequency = FixedPaymentFrequency.monthly,
    String? customInterval,
    required DateTime nextPaymentDate,
    String? note,
  }) {
    final now = DateTime.now();
    final payment = FixedPayment(
      id: _id('fixed-payment'),
      name: name.trim(),
      amount: amount,
      categoryId: categoryId,
      paymentMethodId: paymentMethodId,
      frequency: frequency,
      customInterval: customInterval,
      nextPaymentDate: DateTime(
          nextPaymentDate.year, nextPaymentDate.month, nextPaymentDate.day),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _fixedPayments.add(payment);
    _commit();
    return payment;
  }

  void updateFixedPayment(FixedPayment updated) {
    final index =
        _fixedPayments.indexWhere((payment) => payment.id == updated.id);
    if (index == -1) {
      return;
    }
    _fixedPayments[index] = updated.copyWith(updatedAt: DateTime.now());
    _commit();
  }

  LibraryItem createLibraryItem({
    required LibraryItemType type,
    required String title,
    required DateTime completedDate,
    String? coverUrl,
    double? rating,
    String? note,
    String? platform,
    String? developer,
    String? author,
    LibraryMediaType? mediaType,
    int? releaseYear,
    String? creatorOrDirector,
    String? genre,
    String? format,
    String? duration,
    String? pages,
    String? country,
  }) {
    final now = DateTime.now();
    final item = LibraryItem(
      id: _id('library'),
      type: type,
      title: title.trim(),
      completedDate: completedDate,
      coverUrl: coverUrl?.trim().isEmpty == true ? null : coverUrl?.trim(),
      rating: rating,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      platform: platform?.trim().isEmpty == true ? null : platform?.trim(),
      developer: developer?.trim().isEmpty == true ? null : developer?.trim(),
      author: author?.trim().isEmpty == true ? null : author?.trim(),
      mediaType: mediaType,
      releaseYear: releaseYear,
      creatorOrDirector: creatorOrDirector?.trim().isEmpty == true
          ? null
          : creatorOrDirector?.trim(),
      genre: genre?.trim().isEmpty == true ? null : genre?.trim(),
      format: format?.trim().isEmpty == true ? null : format?.trim(),
      duration: duration?.trim().isEmpty == true ? null : duration?.trim(),
      pages: pages?.trim().isEmpty == true ? null : pages?.trim(),
      country: country?.trim().isEmpty == true ? null : country?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _libraryItems.add(item);
    _commit();
    return item;
  }

  void updateLibraryItem(LibraryItem updated) {
    final index = _libraryItems.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      return;
    }
    _libraryItems[index] = updated.copyWith(updatedAt: DateTime.now());
    _commit();
  }

  void deleteLibraryItem(String itemId) {
    final before = _libraryItems.length;
    _libraryItems.removeWhere((item) => item.id == itemId);
    if (_libraryItems.length != before) {
      _commit();
    }
  }

  LibraryGoal createLibraryGoal({
    required LibraryItemType type,
    required String title,
    required int targetYear,
    bool isFavorite = false,
    String? coverUrl,
    String? note,
    String? platform,
    String? developer,
    String? author,
    LibraryMediaType? mediaType,
    int? releaseYear,
    String? creatorOrDirector,
    String? genre,
    String? format,
    String? duration,
    String? pages,
    String? country,
  }) {
    final now = DateTime.now();
    final goal = LibraryGoal(
      id: _id('library_goal'),
      type: type,
      title: title.trim(),
      targetYear: targetYear,
      isFavorite: isFavorite,
      coverUrl: coverUrl?.trim().isEmpty == true ? null : coverUrl?.trim(),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      platform: platform?.trim().isEmpty == true ? null : platform?.trim(),
      developer: developer?.trim().isEmpty == true ? null : developer?.trim(),
      author: author?.trim().isEmpty == true ? null : author?.trim(),
      mediaType: mediaType,
      releaseYear: releaseYear,
      creatorOrDirector: creatorOrDirector?.trim().isEmpty == true
          ? null
          : creatorOrDirector?.trim(),
      genre: genre?.trim().isEmpty == true ? null : genre?.trim(),
      format: format?.trim().isEmpty == true ? null : format?.trim(),
      duration: duration?.trim().isEmpty == true ? null : duration?.trim(),
      pages: pages?.trim().isEmpty == true ? null : pages?.trim(),
      country: country?.trim().isEmpty == true ? null : country?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _libraryGoals.add(goal);
    _commit();
    return goal;
  }

  void updateLibraryGoal(LibraryGoal updated) {
    final index = _libraryGoals.indexWhere((goal) => goal.id == updated.id);
    if (index == -1) {
      return;
    }
    _libraryGoals[index] = updated.copyWith(updatedAt: DateTime.now());
    _commit();
  }

  void deleteLibraryGoal(String goalId) {
    final before = _libraryGoals.length;
    _libraryGoals.removeWhere((goal) => goal.id == goalId);
    if (_libraryGoals.length != before) {
      _commit();
    }
  }

  void toggleLibraryGoalCompleted(String goalId) {
    final index = _libraryGoals.indexWhere((goal) => goal.id == goalId);
    if (index == -1) {
      return;
    }
    final goal = _libraryGoals[index];
    final willComplete = !goal.isCompleted;
    _libraryGoals[index] = goal.copyWith(
      status: willComplete
          ? LibraryGoalStatus.completed
          : LibraryGoalStatus.pending,
      updatedAt: DateTime.now(),
    );
    if (willComplete) {
      _createLibraryItemFromCompletedGoal(_libraryGoals[index]);
    }
    _commit();
  }

  bool _createLibraryItemFromCompletedGoal(LibraryGoal goal) {
    final completedDate = logicalDate();
    final normalizedTitle = goal.title.trim().toLowerCase();
    final alreadyExists = _libraryItems.any((item) =>
        item.type == goal.type &&
        item.title.trim().toLowerCase() == normalizedTitle &&
        item.completedDate.year == completedDate.year);
    if (alreadyExists) {
      return false;
    }
    final now = DateTime.now();
    _libraryItems.add(
      LibraryItem(
        id: _id('library'),
        type: goal.type,
        title: goal.title.trim(),
        completedDate: completedDate,
        coverUrl: goal.coverUrl,
        note: goal.note?.trim().isEmpty == true ? null : goal.note?.trim(),
        platform: goal.platform,
        developer: goal.developer,
        author: goal.author,
        mediaType: goal.mediaType,
        releaseYear: goal.releaseYear,
        creatorOrDirector: goal.creatorOrDirector,
        genre: goal.genre,
        format: goal.format,
        duration: goal.duration,
        pages: goal.pages,
        country: goal.country,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return true;
  }

  bool _syncCompletedLibraryGoalsIntoItems() {
    var changed = false;
    for (final goal in _libraryGoals) {
      if (goal.isCompleted) {
        changed = _createLibraryItemFromCompletedGoal(goal) || changed;
      }
    }
    return changed;
  }

  void toggleLibraryGoalFavorite(String goalId) {
    final index = _libraryGoals.indexWhere((goal) => goal.id == goalId);
    if (index == -1) {
      return;
    }
    final goal = _libraryGoals[index];
    _libraryGoals[index] = goal.copyWith(
      isFavorite: !goal.isFavorite,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  Expense createExpenseFromFixedPayment(String fixedPaymentId) {
    final payment =
        _fixedPayments.firstWhere((item) => item.id == fixedPaymentId);
    return createExpense(
      date: payment.nextPaymentDate,
      concept: payment.name,
      amount: payment.amount,
      categoryId: payment.categoryId,
      paymentMethodId: payment.paymentMethodId,
      note: payment.note,
      isRecurringInstance: true,
      fixedPaymentId: payment.id,
    );
  }

  List<Expense> expensesForMonth(int year, int month) {
    return _expenses
        .where((expense) =>
            expense.date.year == year && expense.date.month == month)
        .toList()
      ..sort((left, right) => right.date.compareTo(left.date));
  }

  double expenseTotalForMonth(int year, int month) {
    return expensesForMonth(year, month)
        .fold<double>(0, (total, expense) => total + expense.amount);
  }

  double expenseTotalForCategoryMonth(String categoryId, int year, int month) {
    return _expenses
        .where((expense) =>
            expense.categoryId == categoryId &&
            expense.date.year == year &&
            expense.date.month == month)
        .fold<double>(0, (total, expense) => total + expense.amount);
  }

  double expenseTotalForCategoryYear(String categoryId, int year) {
    return _expenses
        .where((expense) =>
            expense.categoryId == categoryId && expense.date.year == year)
        .fold<double>(0, (total, expense) => total + expense.amount);
  }

  double expenseTotalForYear(int year) {
    return _expenses
        .where((expense) => expense.date.year == year)
        .fold<double>(0, (total, expense) => total + expense.amount);
  }

  String exportFinancialJson() {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'expenses': expenses.map((expense) => expense.toJson()).toList(),
      'expenseCategories':
          expenseCategories.map((category) => category.toJson()).toList(),
      'paymentMethods':
          paymentMethods.map((method) => method.toJson()).toList(),
      'fixedPayments':
          fixedPayments.map((payment) => payment.toJson()).toList(),
      'generatedAt': DateTime.now().toIso8601String(),
    });
  }

  String exportFinancialCsv() {
    final rows = <List<String>>[
      ['fecha', 'concepto', 'importe', 'categoría', 'método', 'nota'],
      ..._expenses.map((expense) {
        return [
          expense.date.toIso8601String().split('T').first,
          expense.concept,
          expense.amount.toStringAsFixed(2),
          expenseCategoryById(expense.categoryId)?.name ?? '',
          paymentMethodById(expense.paymentMethodId ?? '')?.name ?? '',
          expense.note ?? '',
        ];
      }),
    ];
    return rows
        .map((row) =>
            row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(','))
        .join('\n');
  }

  Future<void> _load() async {
    await SupabaseConfig.load();
    final persisted = await _store.load();
    if (persisted != null) {
      _applySnapshot(persisted);
      _loadedFromPersistence = true;
      final normalized = _normalizeLoadedSpanishText();
      final syncedLibraryGoals = _syncCompletedLibraryGoalsIntoItems();
      if (normalized || syncedLibraryGoals) {
        await _persist();
      }
    } else {
      _clearStateToDefaults();
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
    _expenses
      ..clear()
      ..addAll(snapshot.expenses);
    _expenseCategories
      ..clear()
      ..addAll(snapshot.expenseCategories);
    _paymentMethods
      ..clear()
      ..addAll(snapshot.paymentMethods);
    _fixedPayments
      ..clear()
      ..addAll(snapshot.fixedPayments);
    _ensureFinancialSeed();
    _libraryItems
      ..clear()
      ..addAll(
          snapshot.libraryItems.where((item) => !_isDemoLibraryItem(item)));
    _libraryGoals
      ..clear()
      ..addAll(snapshot.libraryGoals);
    _calendarEvents
      ..clear()
      ..addAll(snapshot.calendarEvents);
    _daySettings = snapshot.daySettings;
    _notificationSettings = snapshot.notificationSettings;
    _calendarSettings = snapshot.calendarSettings;
    _section = snapshot.section;
    _todaySort = snapshot.todaySort;
    _visualMode = snapshot.visualMode;
    _navOrder = _normalizeNavOrder(snapshot.navOrder);
  }

  bool _normalizeLoadedSpanishText() {
    var changed = false;

    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      final title = _cleanSpanishText(task.title);
      final description = _cleanNullableSpanishText(task.description);
      final checklist = task.checklist.map(_cleanSpanishText).toList();
      final materials = task.materials.map(_cleanSpanishText).toList();
      if (title != task.title ||
          description != task.description ||
          !_sameStringList(checklist, task.checklist) ||
          !_sameStringList(materials, task.materials)) {
        _tasks[i] = task.copyWith(
          title: title,
          description: description,
          clearDescription: description == null,
          checklist: checklist,
          materials: materials,
        );
        changed = true;
      }
    }

    for (var i = 0; i < _categories.length; i++) {
      final category = _categories[i];
      final name = _cleanSpanishText(category.name);
      final description = _cleanSpanishText(category.description);
      if (name != category.name || description != category.description) {
        _categories[i] = category.copyWith(
          name: name,
          description: description,
        );
        changed = true;
      }
    }

    for (var i = 0; i < _projects.length; i++) {
      final project = _projects[i];
      final name = _cleanSpanishText(project.name);
      final description = _cleanSpanishText(project.description);
      if (name != project.name || description != project.description) {
        _projects[i] = project.copyWith(name: name, description: description);
        changed = true;
      }
    }

    for (var i = 0; i < _notes.length; i++) {
      final note = _notes[i];
      final content = _cleanSpanishText(note.content);
      if (content != note.content) {
        _notes[i] = note.copyWith(content: content);
        changed = true;
      }
    }

    for (var i = 0; i < _calendarEvents.length; i++) {
      final event = _calendarEvents[i];
      final title = _cleanSpanishText(event.title);
      final description = _cleanNullableSpanishText(event.description);
      if (title != event.title || description != event.description) {
        _calendarEvents[i] = event.copyWith(
          title: title,
          description: description,
          clearDescription: description == null,
        );
        changed = true;
      }
    }

    for (var i = 0; i < _expenses.length; i++) {
      final expense = _expenses[i];
      final concept = _cleanSpanishText(expense.concept);
      final note = _cleanNullableSpanishText(expense.note);
      if (concept != expense.concept || note != expense.note) {
        _expenses[i] = expense.copyWith(
          concept: concept,
          note: note,
          clearNote: note == null,
        );
        changed = true;
      }
    }

    for (var i = 0; i < _expenseCategories.length; i++) {
      final category = _expenseCategories[i];
      final name = _cleanSpanishText(category.name);
      if (name != category.name) {
        _expenseCategories[i] = category.copyWith(name: name);
        changed = true;
      }
    }

    for (var i = 0; i < _paymentMethods.length; i++) {
      final method = _paymentMethods[i];
      final name = _cleanSpanishText(method.name);
      if (name != method.name) {
        _paymentMethods[i] = method.copyWith(name: name);
        changed = true;
      }
    }

    for (var i = 0; i < _fixedPayments.length; i++) {
      final payment = _fixedPayments[i];
      final name = _cleanSpanishText(payment.name);
      final note = _cleanNullableSpanishText(payment.note);
      if (name != payment.name || note != payment.note) {
        _fixedPayments[i] = payment.copyWith(
          name: name,
          note: note,
          clearNote: note == null,
        );
        changed = true;
      }
    }

    return changed;
  }

  String? _cleanNullableSpanishText(String? value) {
    if (value == null) {
      return null;
    }
    return _cleanSpanishText(value);
  }

  String _cleanSpanishText(String value) {
    var result = value;
    for (var pass = 0; pass < 2; pass++) {
      result = _decodeMojibakeOnce(result);
    }
    return result;
  }

  String _decodeMojibakeOnce(String value) {
    if (value.codeUnits.any((unit) => unit > 255)) {
      return value;
    }
    try {
      return utf8.decode(latin1.encode(value));
    } on FormatException {
      return value;
    }
  }

  bool _sameStringList(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) {
        return false;
      }
    }
    return true;
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
      expenses: expenses,
      expenseCategories: expenseCategories,
      paymentMethods: paymentMethods,
      fixedPayments: fixedPayments,
      libraryItems: libraryItems,
      libraryGoals: libraryGoals,
      calendarEvents: calendarEvents,
      daySettings: daySettings,
      notificationSettings: notificationSettings,
      calendarSettings: calendarSettings,
      section: section,
      todaySort: todaySort,
      visualMode: visualMode,
      navOrder: navOrder,
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

  void _clearStateToDefaults() {
    _tasks.clear();
    _categories.clear();
    _projects.clear();
    _notes.clear();
    _expenses.clear();
    _expenseCategories.clear();
    _paymentMethods.clear();
    _fixedPayments.clear();
    _ensureFinancialSeed();
    _libraryItems.clear();
    _libraryGoals.clear();
    _calendarEvents.clear();
    _daySettings = const DaySettings();
    _notificationSettings = const DeviceNotificationSettings();
    _calendarSettings = const CalendarIntegrationSettings();
    _calendarAccount = null;
    _section = AppSection.today;
    _todaySort = TodaySort.manual;
    _visualMode = AppVisualMode.classic;
    _navOrder = List<AppSection>.of(defaultNavOrder);
    _lastSavedAt = null;
    _lastCloudSyncAt = null;
    _loadedFromPersistence = false;
  }

  List<AppSection> _normalizeNavOrder(List<AppSection> source) {
    final next = <AppSection>[];
    for (final section in source) {
      if (defaultNavOrder.contains(section) && !next.contains(section)) {
        next.add(section);
      }
    }
    for (final section in defaultNavOrder) {
      if (!next.contains(section)) {
        next.add(section);
      }
    }
    return next;
  }

  void _ensureFinancialSeed() {
    if (_expenseCategories.isNotEmpty || _paymentMethods.isNotEmpty) {
      return;
    }
    final now = DateTime.now();
    ExpenseCategory category(
      String id,
      String name,
      int color,
      IconData icon,
    ) {
      return ExpenseCategory(
        id: id,
        name: name,
        colorValue: color,
        icon: icon,
        createdAt: now,
        updatedAt: now,
      );
    }

    _expenseCategories.addAll([
      category('expense-cat-supermercado', 'Supermercado',
          const Color(0xFFDBA62D).toARGB32(), Icons.shopping_cart_rounded),
      category('expense-cat-comer-fuera', 'Comer fuera',
          const Color(0xFFC7744E).toARGB32(), Icons.restaurant_rounded),
      category('expense-cat-ropa', 'Ropa', const Color(0xFF9D7AA5).toARGB32(),
          Icons.checkroom_rounded),
      category('expense-cat-bienestar', 'Bienestar',
          const Color(0xFF7FA37A).toARGB32(), Icons.favorite_rounded),
      category('expense-cat-libros-juegos', 'Libros y juegos',
          const Color(0xFF6C7B8E).toARGB32(), Icons.menu_book_rounded),
      category('expense-cat-casa', 'Casa', const Color(0xFFB4845F).toARGB32(),
          Icons.home_rounded),
      category('expense-cat-deporte', 'Deporte',
          const Color(0xFF78996B).toARGB32(), Icons.fitness_center_rounded),
      category('expense-cat-ocio', 'Ocio', const Color(0xFF8F8AB8).toARGB32(),
          Icons.sports_esports_rounded),
      category('expense-cat-regalos', 'Regalos',
          const Color(0xFFB96C68).toARGB32(), Icons.redeem_rounded),
      category('expense-cat-otros', 'Otros', const Color(0xFF8E8A7D).toARGB32(),
          Icons.inventory_2_rounded),
    ]);

    PaymentMethodModel method(
        String id, String name, IconData icon, int color) {
      return PaymentMethodModel(
        id: id,
        name: name,
        icon: icon,
        colorValue: color,
        createdAt: now,
        updatedAt: now,
      );
    }

    _paymentMethods.addAll([
      method('payment-card', 'Tarjeta', Icons.credit_card_rounded,
          const Color(0xFF6C7B8E).toARGB32()),
      method('payment-cash', 'Efectivo', Icons.payments_rounded,
          const Color(0xFF7FA37A).toARGB32()),
      method('payment-bank', 'Cuenta bancaria', Icons.account_balance_rounded,
          const Color(0xFFB4845F).toARGB32()),
      method('payment-paypal', 'PayPal', Icons.account_balance_wallet_rounded,
          const Color(0xFF5F89B1).toARGB32()),
      method('payment-bizum', 'Bizum', Icons.phone_iphone_rounded,
          const Color(0xFF7C9164).toARGB32()),
      method('payment-amazon', 'Amazon', Icons.inventory_2_rounded,
          const Color(0xFFC08A3B).toARGB32()),
      method('payment-other', 'Otro', Icons.more_horiz_rounded,
          const Color(0xFF8E8A7D).toARGB32()),
    ]);

    if (_expenses.isNotEmpty) {
      return;
    }
    final sampleYear = now.year;
    final samples =
        <({String categoryId, int month, double amount, String concept})>[
      (
        categoryId: 'expense-cat-supermercado',
        month: 1,
        amount: 246.42,
        concept: 'Compra mensual'
      ),
      (
        categoryId: 'expense-cat-comer-fuera',
        month: 1,
        amount: 40,
        concept: 'Comer fuera'
      ),
      (
        categoryId: 'expense-cat-ropa',
        month: 1,
        amount: 66.11,
        concept: 'Ropa'
      ),
      (
        categoryId: 'expense-cat-bienestar',
        month: 1,
        amount: 99.09,
        concept: 'Bienestar'
      ),
      (
        categoryId: 'expense-cat-casa',
        month: 1,
        amount: 571.97,
        concept: 'Casa'
      ),
      (
        categoryId: 'expense-cat-deporte',
        month: 1,
        amount: 32,
        concept: 'Deporte'
      ),
      (
        categoryId: 'expense-cat-ocio',
        month: 1,
        amount: 175.18,
        concept: 'Ocio'
      ),
      (
        categoryId: 'expense-cat-regalos',
        month: 1,
        amount: 20,
        concept: 'Regalos'
      ),
      (categoryId: 'expense-cat-otros', month: 1, amount: 16, concept: 'Otros'),
      (
        categoryId: 'expense-cat-supermercado',
        month: 2,
        amount: 75,
        concept: 'Supermercado'
      ),
      (
        categoryId: 'expense-cat-comer-fuera',
        month: 2,
        amount: 8,
        concept: 'Café'
      ),
      (categoryId: 'expense-cat-ropa', month: 2, amount: 45, concept: 'Ropa'),
      (
        categoryId: 'expense-cat-bienestar',
        month: 2,
        amount: 370,
        concept: 'Bienestar'
      ),
      (
        categoryId: 'expense-cat-libros-juegos',
        month: 2,
        amount: 183,
        concept: 'Libros y juegos'
      ),
      (categoryId: 'expense-cat-casa', month: 2, amount: 50, concept: 'Casa'),
      (
        categoryId: 'expense-cat-deporte',
        month: 2,
        amount: 24,
        concept: 'Deporte'
      ),
      (
        categoryId: 'expense-cat-regalos',
        month: 2,
        amount: 24,
        concept: 'Regalos'
      ),
      (
        categoryId: 'expense-cat-otros',
        month: 2,
        amount: 478.5,
        concept: 'Otros'
      ),
    ];
    for (final sample in samples) {
      _expenses.add(
        Expense(
          id: _id('expense-seed'),
          date: DateTime(sampleYear, sample.month, 12),
          concept: sample.concept,
          amount: sample.amount,
          categoryId: sample.categoryId,
          paymentMethodId: 'payment-card',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    _fixedPayments.addAll([
      FixedPayment(
        id: 'fixed-internet',
        name: 'Internet',
        amount: 39.99,
        categoryId: 'expense-cat-casa',
        paymentMethodId: 'payment-bank',
        frequency: FixedPaymentFrequency.monthly,
        nextPaymentDate: DateTime(now.year, now.month, 5),
        note: 'Pago domiciliado',
        createdAt: now,
        updatedAt: now,
      ),
      FixedPayment(
        id: 'fixed-gym',
        name: 'Gimnasio',
        amount: 32,
        categoryId: 'expense-cat-deporte',
        paymentMethodId: 'payment-card',
        frequency: FixedPaymentFrequency.monthly,
        nextPaymentDate: DateTime(now.year, now.month, 10),
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  }

  bool _isDemoLibraryItem(LibraryItem item) {
    return const <String>{
      'library-game-prey',
      'library-game-ffx',
      'library-game-silksong',
      'library-game-dragon-age',
      'library-game-control',
      'library-book-priorato',
      'library-book-frankenstein',
      'library-book-orgullo',
      'library-book-mala-costumbre',
      'library-book-entre-fuegos',
      'library-film-godfather',
      'library-film-28-days',
      'library-film-sinners',
      'library-film-shawshank',
      'library-film-martian',
    }.contains(item.id);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _feedback.dispose();
    super.dispose();
  }
}
