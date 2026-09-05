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
import '../../services/knowledge_service.dart';
import '../../services/isaac_save_service.dart';
import '../../services/household_asset_service.dart';
import '../../services/recipe_asset_service.dart';
import '../../services/recipe_import_service.dart';
import '../../services/supabase_cloud_service.dart';
import '../../services/task_feedback_service.dart';
import '../../services/task_scheduler_service.dart';
import '../../services/wardrobe_asset_service.dart';

class TodoWorkspace extends ChangeNotifier {
  TodoWorkspace._(
    this._store,
    this._cloudService,
    this._calendarService,
    this._notificationService,
    this._scheduler,
    this._feedback,
    this._knowledgeService,
  ) {
    _isaacSaveSync = IsaacSaveSyncService(_knowledgeService);
    _notificationActionSubscription =
        _notificationService.actions.listen(_handleNotificationAction);
  }

  static Future<TodoWorkspace> create() async {
    final controller = TodoWorkspace._(
      LocalTodoStateRepository(LocalStore()),
      SupabaseCloudSyncRepository(SupabaseCloudService()),
      CalendarServiceRepository(createCalendarService()),
      NotificationServiceRepository(createNotificationService()),
      TaskSchedulerService(),
      TaskFeedbackService(),
      KnowledgeService(),
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
    AppSection.wardrobe,
    AppSection.household,
    AppSection.recipes,
    AppSection.completed,
    AppSection.settings,
  ];

  @visibleForTesting
  static TodoWorkspace createForTest({AppStateSnapshot? snapshot}) {
    final controller = TodoWorkspace._(
      _InMemoryTodoStateRepository(snapshot),
      SupabaseCloudSyncRepository(SupabaseCloudService()),
      CalendarServiceRepository(createCalendarService()),
      NotificationServiceRepository(createNotificationService()),
      TaskSchedulerService(),
      TaskFeedbackService(enabled: false),
      KnowledgeService.inMemory(),
    );
    if (snapshot != null) {
      controller._applySnapshot(snapshot);
      controller._loadedFromPersistence = true;
    } else {
      controller._clearStateToDefaults();
    }
    unawaited(controller._knowledgeService.ensureLibraryRoots(
      controller._libraryItems,
    ));
    return controller;
  }

  final TodoStateRepository _store;
  final CloudSyncRepository _cloudService;
  final CalendarRepository _calendarService;
  final NotificationRepository _notificationService;
  final TaskSchedulerService _scheduler;
  final TaskFeedbackService _feedback;
  final KnowledgeService _knowledgeService;
  late final IsaacSaveSyncService _isaacSaveSync;
  late final StreamSubscription<NotificationAction>
      _notificationActionSubscription;
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
  final List<WardrobeItem> _wardrobeItems = <WardrobeItem>[];
  final List<WardrobeOutfit> _wardrobeOutfits = <WardrobeOutfit>[];
  final List<WardrobeWearLog> _wardrobeWearLogs = <WardrobeWearLog>[];
  final List<WardrobePlanEntry> _wardrobePlanEntries = <WardrobePlanEntry>[];
  final List<WardrobePackingList> _wardrobePackingLists =
      <WardrobePackingList>[];
  final List<WardrobeImportBatch> _wardrobeImportBatches =
      <WardrobeImportBatch>[];
  final List<HouseholdItem> _householdItems = <HouseholdItem>[];
  final List<Recipe> _recipes = <Recipe>[];
  final List<WeeklyMenu> _weeklyMenus = <WeeklyMenu>[];
  final List<CalendarEventModel> _calendarEvents = <CalendarEventModel>[];
  final WardrobeAssetService _wardrobeAssets = WardrobeAssetService();
  final HouseholdAssetService _householdAssets = HouseholdAssetService();
  final RecipeAssetService _recipeAssets = RecipeAssetService();
  final RecipeImportService _recipeImporter = RecipeImportService();
  final RecipeIngredientClassifier _recipeIngredientClassifier =
      const RecipeIngredientClassifier();

  DaySettings _daySettings = const DaySettings();
  WardrobeDisplaySettings _wardrobeDisplaySettings =
      const WardrobeDisplaySettings();
  DeviceNotificationSettings _notificationSettings =
      const DeviceNotificationSettings();
  CalendarIntegrationSettings _calendarSettings =
      const CalendarIntegrationSettings();
  CalendarAccount? _calendarAccount;
  AppSection _section = AppSection.today;
  LibraryItem? _openKnowledgeLibraryItem;
  TodaySort _todaySort = TodaySort.manual;
  LibraryItemStatus _libraryStatusView = LibraryItemStatus.completed;
  LibraryAreaView _libraryAreaView = LibraryAreaView.library;
  AppVisualMode _visualMode = AppVisualMode.classic;
  List<AppSection> _navOrder = List<AppSection>.of(defaultNavOrder);
  DateTime? _manualLogicalDate;
  DateTime? _manualLogicalDateStartedAt;
  DateTime? _lastSavedAt;
  bool _loadedFromPersistence = false;
  bool _calendarBusy = false;
  bool _notificationBusy = false;
  bool _notificationAvailable = false;
  int _scheduledNotificationCount = 0;
  int _scheduledTaskNotificationCount = 0;
  String _notificationError = '';
  String? _pendingNotificationTaskId;
  bool _cloudBusy = false;
  DateTime? _lastCloudSyncAt;
  LocalSyncMetadata _syncMetadata = const LocalSyncMetadata();
  SyncConflict? _syncConflict;
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
  KnowledgeService get knowledge => _knowledgeService;
  IsaacSaveSyncService get isaacSaveSync => _isaacSaveSync;
  List<WardrobeItem> get wardrobeItems =>
      List<WardrobeItem>.unmodifiable(_wardrobeItems);
  List<WardrobeOutfit> get wardrobeOutfits =>
      List<WardrobeOutfit>.unmodifiable(_wardrobeOutfits);
  List<WardrobeWearLog> get wardrobeWearLogs =>
      List<WardrobeWearLog>.unmodifiable(_wardrobeWearLogs);
  List<WardrobePlanEntry> get wardrobePlanEntries =>
      List<WardrobePlanEntry>.unmodifiable(_wardrobePlanEntries);
  List<WardrobePackingList> get wardrobePackingLists =>
      List<WardrobePackingList>.unmodifiable(_wardrobePackingLists);
  List<WardrobeImportBatch> get wardrobeImportBatches =>
      List<WardrobeImportBatch>.unmodifiable(_wardrobeImportBatches);
  List<HouseholdItem> get householdItems =>
      List<HouseholdItem>.unmodifiable(_householdItems);
  List<Recipe> get recipes => List<Recipe>.unmodifiable(_recipes);
  List<WeeklyMenu> get weeklyMenus =>
      List<WeeklyMenu>.unmodifiable(_weeklyMenus);
  List<CalendarEventModel> get calendarEvents =>
      List<CalendarEventModel>.unmodifiable(_calendarEvents);
  DaySettings get settings => _daySettings;
  DaySettings get daySettings => _daySettings;
  WardrobeDisplaySettings get wardrobeDisplaySettings =>
      _wardrobeDisplaySettings;
  DeviceNotificationSettings get notificationSettings => _notificationSettings;
  CalendarIntegrationSettings get calendarSettings => _calendarSettings;
  CalendarAccount? get calendarAccount => _calendarAccount;
  AppSection get section => _section;
  LibraryItem? get openKnowledgeLibraryItem => _openKnowledgeLibraryItem;
  TodaySort get todaySort => _todaySort;
  LibraryItemStatus get libraryStatusView => _libraryStatusView;
  LibraryAreaView get libraryAreaView => _libraryAreaView;
  AppVisualMode get visualMode => _visualMode;
  List<AppSection> get navOrder => List<AppSection>.unmodifiable(_navOrder);
  DateTime? get manualLogicalDate => _activeManualLogicalDate(now);
  bool get hasManualLogicalDate => manualLogicalDate != null;
  DateTime? get lastSavedAt => _lastSavedAt;
  bool get loadedFromPersistence => _loadedFromPersistence;
  bool get calendarBusy => _calendarBusy;
  bool get notificationBusy => _notificationBusy;
  bool get notificationAvailable => _notificationAvailable;
  int get scheduledNotificationCount => _scheduledNotificationCount;
  int get scheduledTaskNotificationCount => _scheduledTaskNotificationCount;
  String get notificationError => _notificationError;
  String? get pendingNotificationTaskId => _pendingNotificationTaskId;
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
  int get lastSeenCloudRevision => _syncMetadata.lastSeenCloudRevision;
  bool get pendingLocalCloudChanges => _syncMetadata.pendingLocalChanges;
  SyncConflict? get syncConflict => _syncConflict;
  bool get hasSyncConflict => _syncConflict != null;

  @visibleForTesting
  bool shouldCreateSyncConflictForTest({
    required CloudSnapshotEnvelope remote,
    required LocalSyncMetadata metadata,
  }) {
    final previous = _syncMetadata;
    _syncMetadata = metadata;
    try {
      return _shouldCreateSyncConflict(remote);
    } finally {
      _syncMetadata = previous;
    }
  }

  @visibleForTesting
  bool shouldPullRemoteEnvelopeForTest({
    required AppStateSnapshot local,
    required CloudSnapshotEnvelope remote,
    required LocalSyncMetadata metadata,
  }) {
    final previous = _syncMetadata;
    _syncMetadata = metadata;
    try {
      return _shouldPullRemoteEnvelope(local: local, remote: remote);
    } finally {
      _syncMetadata = previous;
    }
  }

  String get calendarError => _calendarSettings.lastError;
  bool get isCalendarConnected => _calendarSettings.connected;

  DateTime get now => DateTime.now();

  void setSection(AppSection value) {
    _openKnowledgeLibraryItem = null;
    _section = value;
    _commit();
  }

  void openKnowledgeWorkspace(LibraryItem item) {
    _section = AppSection.library;
    _openKnowledgeLibraryItem = item;
    notifyListeners();
  }

  void closeKnowledgeWorkspace() {
    if (_openKnowledgeLibraryItem == null) {
      return;
    }
    _openKnowledgeLibraryItem = null;
    notifyListeners();
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

  void setLibraryStatusView(LibraryItemStatus value) {
    if (_libraryStatusView == value) {
      return;
    }
    _libraryStatusView = value;
    _commit();
  }

  void setLibraryAreaView(LibraryAreaView value) {
    if (_libraryAreaView == value) {
      return;
    }
    _libraryAreaView = value;
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
    final manual = _activeManualLogicalDate(value);
    if (manual != null) {
      return manual;
    }
    return _ruleBasedLogicalDate(value);
  }

  DateTime _ruleBasedLogicalDate(DateTime value) {
    if (value.hour < _daySettings.dayEndsAtHour) {
      final previous = value.subtract(const Duration(days: 1));
      return DateTime(previous.year, previous.month, previous.day);
    }
    return DateTime(value.year, value.month, value.day);
  }

  DateTime? _activeManualLogicalDate(DateTime value) {
    final manual = _manualLogicalDate;
    final startedAt = _manualLogicalDateStartedAt;
    if (manual == null || startedAt == null || value.isBefore(startedAt)) {
      return null;
    }
    final natural = _ruleBasedLogicalDate(value);
    if (!_sameDay(natural, manual)) {
      return manual;
    }
    return null;
  }

  void advanceToNextLogicalDay() {
    final value = now;
    final currentManual = _activeManualLogicalDate(value);
    if (currentManual != null) {
      _manualLogicalDate = currentManual.add(const Duration(days: 1));
    } else if (value.hour < _daySettings.nextDayVisibleAtHour) {
      _manualLogicalDate = DateTime(value.year, value.month, value.day);
    } else {
      _manualLogicalDate = _ruleBasedLogicalDate(value).add(
        const Duration(days: 1),
      );
    }
    _manualLogicalDateStartedAt = value;
    _commit();
  }

  void moveToPreviousLogicalDay() {
    final value = now;
    final current = _activeManualLogicalDate(value) ?? logicalDate(value);
    _manualLogicalDate = current.subtract(const Duration(days: 1));
    _manualLogicalDateStartedAt = value;
    _commit();
  }

  void clearManualLogicalDate() {
    _manualLogicalDate = null;
    _manualLogicalDateStartedAt = null;
    _commit();
  }

  bool isNextDayVisible([DateTime? instant]) {
    final value = instant ?? now;
    if (_activeManualLogicalDate(value) != null) {
      return true;
    }
    return value.hour >= _daySettings.nextDayVisibleAtHour;
  }

  List<TaskModel> tasksForToday() => _sortTasks(_tasksForDay(logicalDate()));

  List<TaskModel> tasksForDate(DateTime day) => _sortTasks(_tasksForDay(day));

  bool isTaskCompletedOnDay(TaskModel task, DateTime day) {
    if (task.recurrence.isRecurring || _recurringParentOf(task) != null) {
      return task.recurrenceCompletions.containsKey(_occurrenceKey(day));
    }
    return task.status == TaskStatus.completed;
  }

  List<TaskModel> tasksForWeek([DateTime? anchor]) {
    final start = logicalDate(anchor);
    final dates =
        List<DateTime>.generate(7, (index) => start.add(Duration(days: index)));
    final seen = <String>{};
    return dates
        .expand(_tasksForDay)
        .where((task) => seen.add(task.id))
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
        .where((task) => task.status != TaskStatus.archived)
        .toList()
      ..sort((left, right) => left.manualOrder.compareTo(right.manualOrder));
  }

  List<TaskModel> completedTasks() {
    final completed = <TaskModel>[
      ..._tasks.where(
          (task) => task.status == TaskStatus.completed && !task.isSubtask),
      ..._tasks
          .where((task) => task.recurrence.isRecurring && !task.isSubtask)
          .expand(_completedRecurringOccurrences),
    ];
    return completed
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
      wardrobeItems: wardrobeItems,
      wardrobeOutfits: wardrobeOutfits,
      wardrobeWearLogs: wardrobeWearLogs,
      wardrobePlanEntries: wardrobePlanEntries,
      wardrobePackingLists: wardrobePackingLists,
      householdItems: householdItems,
      recipes: recipes,
      weeklyMenus: weeklyMenus,
      calendarEvents: calendarEvents,
      daySettings: daySettings,
      wardrobeDisplaySettings: wardrobeDisplaySettings,
      notificationSettings: notificationSettings,
      calendarSettings: calendarSettings,
      visualMode: visualMode,
      navOrder: navOrder,
    );
  }

  WardrobeItem? wardrobeItemById(String id) {
    for (final item in _wardrobeItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<String> wardrobeImageAbsolutePath(WardrobeItem item,
      {bool thumbnail = true}) {
    final path = thumbnail && item.thumbnailPath.isNotEmpty
        ? item.thumbnailPath
        : item.imagePath;
    return _wardrobeAssets.absolutePath(path);
  }

  Future<String> wardrobeOutfitRenderAbsolutePath(WardrobeOutfit outfit) =>
      _wardrobeAssets.absolutePath(outfit.renderImagePath);

  WardrobeItem createWardrobeItem({
    required String name,
    required String category,
    String imagePath = '',
    String thumbnailPath = '',
    String imageSha256 = '',
    List<String> colors = const <String>[],
    String material = '',
    List<String> seasons = const <String>[],
    List<String> occasions = const <String>[],
    List<String> tags = const <String>[],
    double? price,
  }) {
    final instant = DateTime.now();
    final item = WardrobeItem(
      id: _id('wardrobe-item'),
      name: name.trim().isEmpty ? 'Prenda sin nombre' : name.trim(),
      category: category.trim().isEmpty ? 'Sin categoría' : category.trim(),
      imagePath: imagePath,
      thumbnailPath: thumbnailPath,
      imageSha256: imageSha256,
      colors: colors,
      material: material.trim(),
      seasons: seasons,
      occasions: occasions,
      tags: tags,
      price: price,
      createdAt: instant,
      updatedAt: instant,
    );
    _wardrobeItems.add(item);
    _commit();
    return item;
  }

  void updateWardrobeItem(
    String id, {
    String? name,
    String? category,
    List<String>? colors,
    String? material,
    List<String>? seasons,
    List<String>? occasions,
    List<String>? tags,
    bool? favorite,
    WardrobeLaundryStatus? laundryStatus,
    double? price,
    bool clearPrice = false,
  }) {
    final index = _wardrobeItems.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _wardrobeItems[index] = _wardrobeItems[index].copyWith(
      name: name?.trim(),
      category: category?.trim(),
      colors: colors,
      material: material?.trim(),
      seasons: seasons,
      occasions: occasions,
      tags: tags,
      favorite: favorite,
      laundryStatus: laundryStatus,
      price: price,
      clearPrice: clearPrice,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void toggleWardrobeFavorite(String id) {
    final index = _wardrobeItems.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final item = _wardrobeItems[index];
    _wardrobeItems[index] = item.copyWith(
      favorite: !item.favorite,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void setWardrobeLaundryStatus(
    Iterable<String> ids,
    WardrobeLaundryStatus status,
  ) {
    final selected = ids.toSet();
    for (var index = 0; index < _wardrobeItems.length; index++) {
      if (selected.contains(_wardrobeItems[index].id)) {
        _wardrobeItems[index] = _wardrobeItems[index].copyWith(
          laundryStatus: status,
          updatedAt: DateTime.now(),
        );
      }
    }
    _commit();
  }

  void archiveWardrobeItem(String id) {
    final index = _wardrobeItems.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _wardrobeItems[index] = _wardrobeItems[index].copyWith(
      archived: true,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void deleteWardrobeItem(String id) {
    _wardrobeItems.removeWhere((item) => item.id == id);
    for (var index = 0; index < _wardrobeOutfits.length; index++) {
      final outfit = _wardrobeOutfits[index];
      _wardrobeOutfits[index] = WardrobeOutfit(
        id: outfit.id,
        name: outfit.name,
        itemIds: outfit.itemIds.where((itemId) => itemId != id).toList(),
        occasion: outfit.occasion,
        tags: outfit.tags,
        renderImagePath: outfit.renderImagePath,
        createdAt: outfit.createdAt,
      );
    }
    _wardrobePlanEntries.removeWhere(
        (entry) => entry.itemIds.length == 1 && entry.itemIds.single == id);
    for (var index = 0; index < _wardrobePackingLists.length; index++) {
      final list = _wardrobePackingLists[index];
      _wardrobePackingLists[index] = list.copyWith(
        entries: list.entries.where((entry) => entry.itemId != id).toList(),
      );
    }
    _commit();
  }

  WardrobeOutfit createWardrobeOutfit({
    required String name,
    required List<String> itemIds,
    String occasion = '',
    List<String> tags = const <String>[],
  }) {
    final outfit = WardrobeOutfit(
      id: _id('wardrobe-outfit'),
      name: name.trim().isEmpty ? 'Conjunto sin nombre' : name.trim(),
      itemIds:
          itemIds.where((id) => wardrobeItemById(id) != null).toSet().toList(),
      occasion: occasion.trim(),
      tags: tags,
      createdAt: DateTime.now(),
    );
    _wardrobeOutfits.add(outfit);
    _commit();
    return outfit;
  }

  WardrobeOutfit updateWardrobeOutfit({
    required String id,
    required String name,
    required List<String> itemIds,
    String occasion = '',
    List<String> tags = const <String>[],
  }) {
    final index = _wardrobeOutfits.indexWhere((outfit) => outfit.id == id);
    if (index == -1) throw StateError('No se encuentra el conjunto.');
    final updated = _wardrobeOutfits[index].copyWith(
      name: name.trim().isEmpty ? 'Conjunto sin nombre' : name.trim(),
      itemIds: itemIds
          .where((itemId) => wardrobeItemById(itemId) != null)
          .toSet()
          .toList(),
      occasion: occasion.trim(),
      tags: tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(),
    );
    _wardrobeOutfits[index] = updated;
    _commit();
    return updated;
  }

  void deleteWardrobeOutfit(String id) {
    final outfit =
        _wardrobeOutfits.where((value) => value.id == id).firstOrNull;
    _wardrobeOutfits.removeWhere((outfit) => outfit.id == id);
    _wardrobePlanEntries.removeWhere((entry) => entry.outfitId == id);
    _commit();
    if (outfit != null && outfit.renderImagePath.isNotEmpty) {
      unawaited(_wardrobeAssets.deleteAsset(outfit.renderImagePath));
    }
  }

  Future<void> importWardrobeOutfitRender(
      String outfitId, String sourcePath) async {
    final index =
        _wardrobeOutfits.indexWhere((outfit) => outfit.id == outfitId);
    if (index == -1) throw StateError('No se encuentra el conjunto.');
    final previous = _wardrobeOutfits[index].renderImagePath;
    final relativePath =
        await _wardrobeAssets.importOutfitRender(outfitId, sourcePath);
    _wardrobeOutfits[index] =
        _wardrobeOutfits[index].copyWith(renderImagePath: relativePath);
    _commit();
    if (previous.isNotEmpty && previous != relativePath) {
      await _wardrobeAssets.deleteAsset(previous);
    }
  }

  Future<void> clearWardrobeOutfitRender(String outfitId) async {
    final index =
        _wardrobeOutfits.indexWhere((outfit) => outfit.id == outfitId);
    if (index == -1) return;
    final previous = _wardrobeOutfits[index].renderImagePath;
    _wardrobeOutfits[index] =
        _wardrobeOutfits[index].copyWith(renderImagePath: '');
    _commit();
    if (previous.isNotEmpty) await _wardrobeAssets.deleteAsset(previous);
  }

  WardrobeWearLog recordWardrobeWear({
    required DateTime date,
    required List<String> itemIds,
    String? outfitId,
    String label = '',
  }) {
    final ids =
        itemIds.where((id) => wardrobeItemById(id) != null).toSet().toList();
    final log = WardrobeWearLog(
      id: _id('wardrobe-wear'),
      date: date,
      itemIds: ids,
      outfitId: outfitId,
      label: label.trim(),
    );
    _wardrobeWearLogs.add(log);
    for (var index = 0; index < _wardrobeItems.length; index++) {
      final item = _wardrobeItems[index];
      if (ids.contains(item.id)) {
        _wardrobeItems[index] = item.copyWith(
          useCount: item.useCount + 1,
          lastUsedAt: date,
          updatedAt: DateTime.now(),
        );
      }
    }
    _commit();
    return log;
  }

  WardrobePlanEntry setWardrobePlan({
    required DateTime date,
    required List<String> itemIds,
    String? outfitId,
    WardrobeWeather weather = WardrobeWeather.mild,
    String occasion = '',
  }) {
    _wardrobePlanEntries.removeWhere((entry) => _sameDay(entry.date, date));
    final entry = WardrobePlanEntry(
      id: _id('wardrobe-plan'),
      date: date,
      itemIds: itemIds,
      outfitId: outfitId,
      weather: weather,
      occasion: occasion.trim(),
    );
    _wardrobePlanEntries.add(entry);
    _commit();
    return entry;
  }

  WardrobePackingList createWardrobePackingList({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final list = WardrobePackingList(
      id: _id('wardrobe-packing'),
      name: name.trim().isEmpty ? 'Nuevo viaje' : name.trim(),
      startDate: startDate,
      endDate: endDate,
    );
    _wardrobePackingLists.add(list);
    _commit();
    return list;
  }

  void addWardrobePackingItem(String listId, String itemId,
      {int quantity = 1}) {
    final index = _wardrobePackingLists.indexWhere((list) => list.id == listId);
    if (index == -1 || wardrobeItemById(itemId) == null) return;
    final list = _wardrobePackingLists[index];
    final entries = List<WardrobePackingEntry>.from(list.entries)
      ..removeWhere((entry) => entry.itemId == itemId)
      ..add(WardrobePackingEntry(itemId: itemId, quantity: max(1, quantity)));
    _wardrobePackingLists[index] = list.copyWith(entries: entries);
    _commit();
  }

  void toggleWardrobePackingItem(String listId, String itemId) {
    final index = _wardrobePackingLists.indexWhere((list) => list.id == listId);
    if (index == -1) return;
    final list = _wardrobePackingLists[index];
    _wardrobePackingLists[index] = list.copyWith(
      entries: list.entries
          .map((entry) => entry.itemId == itemId
              ? entry.copyWith(packed: !entry.packed)
              : entry)
          .toList(),
    );
    _commit();
  }

  List<WardrobeItem> wardrobeSuggestions({
    WardrobeWeather weather = WardrobeWeather.mild,
    String occasion = '',
    int limit = 8,
  }) {
    final candidates = _wardrobeItems
        .where((item) => !item.archived)
        .where((item) => item.laundryStatus == WardrobeLaundryStatus.available)
        .where((item) =>
            occasion.isEmpty ||
            item.occasions.isEmpty ||
            item.occasions
                .any((value) => value.toLowerCase() == occasion.toLowerCase()))
        .toList();
    int score(WardrobeItem item) {
      var value = item.favorite ? 12 : 0;
      value += max(0, 10 - item.useCount);
      final weatherTag = switch (weather) {
        WardrobeWeather.hot => 'calor',
        WardrobeWeather.mild => 'templado',
        WardrobeWeather.cold => 'frío',
        WardrobeWeather.rain => 'lluvia',
      };
      if (item.tags.map((tag) => tag.toLowerCase()).contains(weatherTag)) {
        value += 15;
      }
      if (item.lastUsedAt == null ||
          DateTime.now().difference(item.lastUsedAt!).inDays > 14) {
        value += 8;
      }
      return value;
    }

    candidates.sort((left, right) => score(right).compareTo(score(left)));
    return candidates.take(limit).toList();
  }

  Future<WardrobeImportBatch> stageWardrobeImportDirectory(String path) async {
    final batch =
        await _wardrobeAssets.stageManifestDirectory(path, wardrobeItems);
    _wardrobeImportBatches.add(batch);
    await _persist();
    return batch;
  }

  void updateWardrobeImportItem(
    String batchId,
    String itemId, {
    String? name,
    String? category,
    List<String>? colors,
    String? material,
    List<String>? seasons,
    List<String>? occasions,
    List<String>? tags,
  }) {
    final batchIndex =
        _wardrobeImportBatches.indexWhere((batch) => batch.id == batchId);
    if (batchIndex == -1) return;
    final batch = _wardrobeImportBatches[batchIndex];
    _wardrobeImportBatches[batchIndex] = batch.copyWith(
      items: batch.items
          .map((item) => item.id == itemId
              ? item.copyWith(
                  name: name,
                  category: category,
                  colors: colors,
                  material: material,
                  seasons: seasons,
                  occasions: occasions,
                  tags: tags)
              : item)
          .toList(),
    );
    _commit();
  }

  Future<int> approveWardrobeImport(String batchId) async {
    final batchIndex =
        _wardrobeImportBatches.indexWhere((batch) => batch.id == batchId);
    if (batchIndex == -1) return 0;
    final batch = _wardrobeImportBatches[batchIndex];
    final assets = await _wardrobeAssets.approveBatch(batch);
    final instant = DateTime.now();
    final createdIds = <String>[];
    try {
      for (final asset in assets) {
        final item = asset.importItem;
        final id = _id('wardrobe-item');
        createdIds.add(id);
        _wardrobeItems.add(WardrobeItem(
          id: id,
          name: item.name,
          category: item.category,
          imagePath: asset.imagePath,
          thumbnailPath: asset.thumbnailPath,
          imageSha256: asset.sha256,
          colors: item.colors,
          material: item.material,
          seasons: item.seasons,
          occasions: item.occasions,
          tags: item.tags,
          createdAt: instant,
          updatedAt: instant,
        ));
      }
      _wardrobeImportBatches[batchIndex] = batch.copyWith(
        status: WardrobeImportStatus.approved,
      );
      await _persist();
      await _wardrobeAssets.deleteImportBatch(batch.id);
      return assets.length;
    } catch (_) {
      _wardrobeItems.removeWhere((item) => createdIds.contains(item.id));
      _wardrobeImportBatches[batchIndex] = batch;
      await _wardrobeAssets.rollbackApprovedAssets(assets);
      rethrow;
    }
  }

  Future<void> discardWardrobeImport(String batchId) async {
    final index =
        _wardrobeImportBatches.indexWhere((batch) => batch.id == batchId);
    if (index == -1) return;
    final batch = _wardrobeImportBatches[index];
    _wardrobeImportBatches[index] =
        batch.copyWith(status: WardrobeImportStatus.discarded);
    await _persist();
    await _wardrobeAssets.deleteImportBatch(batch.id);
  }

  Future<void> reloadWardrobeImports() async {
    final persisted = await _store.load();
    if (persisted == null) return;
    _applySnapshot(persisted);
    notifyListeners();
  }

  HouseholdItem? householdItemById(String id) {
    for (final item in _householdItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<String> householdImageAbsolutePath(
    HouseholdItem item, {
    bool thumbnail = true,
  }) {
    final path = thumbnail && item.thumbnailPath.isNotEmpty
        ? item.thumbnailPath
        : item.imagePath;
    return _householdAssets.absolutePath(path);
  }

  Future<String> householdDocumentAbsolutePath(String relativePath) =>
      _householdAssets.absolutePath(relativePath);

  HouseholdItem createHouseholdItem({
    required String name,
    required String category,
    String brand = '',
    String model = '',
    String serialNumber = '',
    String location = '',
    String notes = '',
    String manualSourceUrl = '',
    String retailer = '',
    DateTime? purchaseDate,
    DateTime? warrantyUntil,
    double? price,
    List<String> tags = const <String>[],
  }) {
    final instant = DateTime.now();
    final item = HouseholdItem(
      id: _id('household-item'),
      name: name.trim().isEmpty ? 'Artículo sin nombre' : name.trim(),
      category: category.trim().isEmpty ? 'Sin categoría' : category.trim(),
      brand: brand.trim(),
      model: model.trim(),
      serialNumber: serialNumber.trim(),
      location: location.trim(),
      notes: notes.trim(),
      manualSourceUrl: manualSourceUrl.trim(),
      retailer: retailer.trim(),
      purchaseDate: purchaseDate,
      warrantyUntil: warrantyUntil,
      price: price,
      tags: tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(),
      createdAt: instant,
      updatedAt: instant,
    );
    _householdItems.add(item);
    _commit();
    return item;
  }

  void updateHouseholdItem(
    String id, {
    String? name,
    String? category,
    String? brand,
    String? model,
    String? serialNumber,
    String? location,
    String? notes,
    String? manualSourceUrl,
    String? retailer,
    DateTime? purchaseDate,
    bool clearPurchaseDate = false,
    DateTime? warrantyUntil,
    bool clearWarrantyUntil = false,
    double? price,
    bool clearPrice = false,
    List<String>? tags,
  }) {
    final index = _householdItems.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _householdItems[index] = _householdItems[index].copyWith(
      name: name?.trim(),
      category: category?.trim(),
      brand: brand?.trim(),
      model: model?.trim(),
      serialNumber: serialNumber?.trim(),
      location: location?.trim(),
      notes: notes?.trim(),
      manualSourceUrl: manualSourceUrl?.trim(),
      retailer: retailer?.trim(),
      purchaseDate: purchaseDate,
      clearPurchaseDate: clearPurchaseDate,
      warrantyUntil: warrantyUntil,
      clearWarrantyUntil: clearWarrantyUntil,
      price: price,
      clearPrice: clearPrice,
      tags: tags
          ?.map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(),
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  Future<void> importHouseholdImage(String id, String sourcePath) async {
    final index = _householdItems.indexWhere((item) => item.id == id);
    if (index == -1) throw StateError('No se encuentra el artículo.');
    final previousImage = _householdItems[index].imagePath;
    final previousThumbnail = _householdItems[index].thumbnailPath;
    final imported = await _householdAssets.importImage(id, sourcePath);
    _householdItems[index] = _householdItems[index].copyWith(
      imagePath: imported.imagePath,
      thumbnailPath: imported.thumbnailPath,
      imageSha256: imported.sha256,
      updatedAt: DateTime.now(),
    );
    _commit();
    for (final path in <String>[previousImage, previousThumbnail]) {
      if (path.isNotEmpty &&
          path != imported.imagePath &&
          path != imported.thumbnailPath) {
        await _householdAssets.deleteAsset(path);
      }
    }
  }

  Future<void> importHouseholdManual(String id, String sourcePath) async {
    await _importHouseholdPdf(id, sourcePath, manual: true);
  }

  Future<void> importHouseholdInvoice(String id, String sourcePath) async {
    await _importHouseholdPdf(id, sourcePath, manual: false);
  }

  Future<void> _importHouseholdPdf(
    String id,
    String sourcePath, {
    required bool manual,
  }) async {
    final index = _householdItems.indexWhere((item) => item.id == id);
    if (index == -1) throw StateError('No se encuentra el artículo.');
    final previous = manual
        ? _householdItems[index].manualPath
        : _householdItems[index].invoicePath;
    final imported = await _householdAssets.importPdf(
      id,
      sourcePath,
      kind: manual ? 'manuals' : 'invoices',
    );
    _householdItems[index] = _householdItems[index].copyWith(
      manualPath: manual ? imported : null,
      invoicePath: manual ? null : imported,
      updatedAt: DateTime.now(),
    );
    _commit();
    if (previous.isNotEmpty && previous != imported) {
      await _householdAssets.deleteAsset(previous);
    }
  }

  void archiveHouseholdItem(String id) {
    final index = _householdItems.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _householdItems[index] = _householdItems[index].copyWith(
      archived: true,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void deleteHouseholdItem(String id) {
    final item = householdItemById(id);
    if (item == null) return;
    _householdItems.removeWhere((value) => value.id == id);
    _commit();
    for (final path in <String>[
      item.imagePath,
      item.thumbnailPath,
      item.manualPath,
      item.invoicePath,
    ]) {
      if (path.isNotEmpty) unawaited(_householdAssets.deleteAsset(path));
    }
  }

  Recipe? recipeById(String id) {
    for (final recipe in _recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  WeeklyMenu? weeklyMenuById(String id) {
    for (final menu in _weeklyMenus) {
      if (menu.id == id) return menu;
    }
    return null;
  }

  List<Recipe> recipesForWeeklyMenu(WeeklyMenu menu) => menu.allRecipeIds
      .map(recipeById)
      .whereType<Recipe>()
      .toList(growable: false);

  Future<String> weeklyMenuImageAbsolutePath(
    WeeklyMenu menu, {
    bool thumbnail = true,
  }) {
    final path = thumbnail && menu.thumbnailPath.isNotEmpty
        ? menu.thumbnailPath
        : menu.imagePath;
    return _recipeAssets.absolutePath(path);
  }

  WeeklyMenu createWeeklyMenu({
    required String title,
    String description = '',
    int people = 1,
    int totalPriceCents = 0,
    List<String> recipeIds = const <String>[],
    List<WeeklyMenuEntry> mealEntries = const <WeeklyMenuEntry>[],
    List<WeeklyMenuShoppingItem> shoppingItems =
        const <WeeklyMenuShoppingItem>[],
    String sourceUrl = '',
    String imageSourceUrl = '',
  }) {
    final instant = DateTime.now();
    final validRecipeIds =
        recipeIds.where((id) => recipeById(id) != null).toSet().toList();
    final validEntries = mealEntries
        .where((entry) => recipeById(entry.recipeId) != null)
        .toList();
    final resolvedEntries = validEntries.isNotEmpty
        ? validEntries
        : <WeeklyMenuEntry>[
            for (var index = 0; index < validRecipeIds.length; index++)
              WeeklyMenuEntry(
                id: _id('weekly-meal'),
                day: WeeklyMenuDay.values[index % WeeklyMenuDay.values.length],
                mealType: WeeklyMealType.lunch,
                recipeId: validRecipeIds[index],
              ),
          ];
    final menu = WeeklyMenu(
      id: _id('weekly-menu'),
      title: title.trim().isEmpty ? 'Menú semanal' : title.trim(),
      description: description.trim(),
      people: people.clamp(1, 1000),
      totalPriceCents: totalPriceCents.clamp(0, 100000000),
      recipeIds:
          resolvedEntries.map((entry) => entry.recipeId).toSet().toList(),
      shoppingListRecipeIds: shoppingItems.isEmpty
          ? const <String>[]
          : resolvedEntries.map((entry) => entry.recipeId).toSet().toList(),
      mealEntries: resolvedEntries,
      shoppingItems:
          shoppingItems.where((item) => item.name.trim().isNotEmpty).toList(),
      sourceUrl: sourceUrl.trim(),
      imageSourceUrl: imageSourceUrl.trim(),
      createdAt: instant,
      updatedAt: instant,
    );
    _weeklyMenus.add(menu);
    _commit();
    return menu;
  }

  void setWeeklyMenuMeal(
    String menuId, {
    required WeeklyMenuDay day,
    required WeeklyMealType mealType,
    String? recipeId,
  }) {
    final index = _weeklyMenus.indexWhere((menu) => menu.id == menuId);
    if (index == -1) return;
    final entries = _weeklyMenus[index]
        .mealEntries
        .where((entry) => entry.day != day || entry.mealType != mealType)
        .toList();
    if (recipeId != null && recipeById(recipeId) != null) {
      entries.add(WeeklyMenuEntry(
        id: _id('weekly-meal'),
        day: day,
        mealType: mealType,
        recipeId: recipeId,
      ));
    }
    entries.sort((left, right) {
      final dayOrder = left.day.index.compareTo(right.day.index);
      return dayOrder != 0
          ? dayOrder
          : left.mealType.index.compareTo(right.mealType.index);
    });
    _weeklyMenus[index] = _weeklyMenus[index].copyWith(
      recipeIds: entries.map((entry) => entry.recipeId).toSet().toList(),
      mealEntries: entries,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  TaskModel createWeeklyMenuShoppingTask(
    String menuId, {
    DateTime? scheduledAt,
    List<String> selectedEntryIds = const <String>[],
  }) {
    final menu = weeklyMenuById(menuId);
    if (menu == null) throw StateError('No se encuentra el menú semanal.');
    final availableEntries = menu.mealEntries
        .where((entry) => recipeById(entry.recipeId) != null)
        .toList();
    final requestedIds = selectedEntryIds.toSet();
    final selectedEntries = requestedIds.isEmpty
        ? availableEntries
        : availableEntries
            .where((entry) => requestedIds.contains(entry.id))
            .toList();
    if (selectedEntries.isEmpty) {
      throw StateError('Selecciona al menos una comida del menú.');
    }
    final selectedIds = selectedEntries.map((entry) => entry.id).toSet();
    final completeMenu = availableEntries.isNotEmpty &&
        selectedIds.length == availableEntries.length &&
        availableEntries.every((entry) => selectedIds.contains(entry.id));
    final curatedSelection =
        _weeklyMenuSelectionUsesCuratedList(menu, selectedEntries);
    final shoppingItems = curatedSelection
        ? menu.shoppingItems
        : _shoppingItemsForWeeklyMenuEntries(selectedEntries);
    if (shoppingItems.isEmpty) {
      throw StateError('Las recetas elegidas no tienen ingredientes.');
    }
    final category = _ensureTaskCategory(
      'Compras',
      const Color(0xFFDBA62D),
      Icons.shopping_cart_rounded,
    );
    final date = scheduledAt ?? logicalDate();
    final price = curatedSelection && menu.totalPriceCents > 0
        ? ' · Presupuesto aproximado: ${_formatEuroCents(menu.totalPriceCents)}.'
        : '';
    final selectedDays = selectedEntries.map((entry) => entry.day).toSet();
    final scope = completeMenu
        ? 'semana completa'
        : '${selectedEntries.length} ${selectedEntries.length == 1 ? 'comida' : 'comidas'} · '
            '${selectedDays.length} ${selectedDays.length == 1 ? 'día' : 'días'}';
    final task = createTask(
      title: completeMenu
          ? 'Comprar ${menu.title}'
          : 'Comprar selección de ${menu.title}',
      description: 'Lista de compra del menú para ${menu.people} '
          '${menu.people == 1 ? 'persona' : 'personas'} · $scope$price',
      categoryIds: <String>[category.id],
      scheduledAt: date,
    );
    final seen = <String>{};
    for (final item in shoppingItems) {
      final key = item.name.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      createTask(
        title: item.name.trim(),
        description: <String>[
          if (item.group.trim().isNotEmpty) item.group.trim(),
          if (item.priceCents > 0)
            'Precio orientativo: ${_formatEuroCents(item.priceCents)}',
        ].join(' · '),
        categoryIds: <String>[category.id],
        scheduledAt: date,
        parentTaskId: task.id,
      );
    }
    return taskById(task.id) ?? task;
  }

  List<WeeklyMenuShoppingItem> weeklyMenuShoppingItemsForSelection(
    String menuId,
    Iterable<String> selectedEntryIds,
  ) {
    final menu = weeklyMenuById(menuId);
    if (menu == null) return const <WeeklyMenuShoppingItem>[];
    final selectedIds = selectedEntryIds.toSet();
    if (selectedIds.isEmpty) return const <WeeklyMenuShoppingItem>[];
    final available = menu.mealEntries
        .where((entry) => recipeById(entry.recipeId) != null)
        .toList();
    final selected =
        available.where((entry) => selectedIds.contains(entry.id)).toList();
    final curatedSelection =
        _weeklyMenuSelectionUsesCuratedList(menu, selected);
    return curatedSelection
        ? List<WeeklyMenuShoppingItem>.unmodifiable(menu.shoppingItems)
        : List<WeeklyMenuShoppingItem>.unmodifiable(
            _shoppingItemsForWeeklyMenuEntries(selected),
          );
  }

  bool weeklyMenuSelectionUsesCuratedList(
    String menuId,
    Iterable<String> selectedEntryIds,
  ) {
    final menu = weeklyMenuById(menuId);
    if (menu == null) return false;
    final selectedIds = selectedEntryIds.toSet();
    final selected = menu.mealEntries
        .where((entry) => selectedIds.contains(entry.id))
        .toList();
    return _weeklyMenuSelectionUsesCuratedList(menu, selected);
  }

  bool _weeklyMenuSelectionUsesCuratedList(
    WeeklyMenu menu,
    List<WeeklyMenuEntry> selectedEntries,
  ) {
    if (menu.shoppingItems.isEmpty || menu.shoppingListRecipeIds.isEmpty) {
      return false;
    }
    final selectedRecipeIds =
        selectedEntries.map((entry) => entry.recipeId).toList();
    final selectedSet = selectedRecipeIds.toSet();
    final curatedSet = menu.shoppingListRecipeIds.toSet();
    return selectedRecipeIds.length == selectedSet.length &&
        selectedSet.length == curatedSet.length &&
        selectedSet.containsAll(curatedSet);
  }

  List<WeeklyMenuShoppingItem> _shoppingItemsForWeeklyMenuEntries(
    Iterable<WeeklyMenuEntry> entries,
  ) {
    final items = <WeeklyMenuShoppingItem>[];
    final seen = <String>{};
    final recipeIds = entries.map((entry) => entry.recipeId).toSet();
    for (final recipeId in recipeIds) {
      final recipe = recipeById(recipeId);
      if (recipe == null) continue;
      for (final ingredient in recipe.ingredients) {
        for (final label
            in _recipeIngredientClassifier.shoppingLabels(ingredient)) {
          final key = label.trim().toLowerCase();
          if (key.isEmpty || !seen.add(key)) continue;
          items.add(WeeklyMenuShoppingItem(
            name: label.trim(),
            group: recipe.title,
          ));
        }
      }
    }
    return items;
  }

  String _formatEuroCents(int cents) {
    final euros = cents / 100;
    return '${euros.toStringAsFixed(cents % 100 == 0 ? 0 : 2).replaceAll('.', ',')} €';
  }

  Future<String> recipeImageAbsolutePath(
    Recipe recipe, {
    bool thumbnail = true,
  }) {
    final path = thumbnail && recipe.thumbnailPath.isNotEmpty
        ? recipe.thumbnailPath
        : recipe.imagePath;
    return _recipeAssets.absolutePath(path);
  }

  Recipe createRecipe({
    required String title,
    String description = '',
    String category = 'Sin categoría',
    String cuisine = '',
    int servings = 1,
    int prepMinutes = 0,
    int cookMinutes = 0,
    List<RecipeIngredient> ingredients = const <RecipeIngredient>[],
    List<String> instructions = const <String>[],
    List<String> tags = const <String>[],
    String sourceUrl = '',
    String imageSourceUrl = '',
  }) {
    final instant = DateTime.now();
    final recipe = Recipe(
      id: _id('recipe'),
      title: title.trim().isEmpty ? 'Receta sin nombre' : title.trim(),
      description: description.trim(),
      category: category.trim().isEmpty ? 'Sin categoría' : category.trim(),
      cuisine: cuisine.trim(),
      servings: servings.clamp(1, 1000),
      prepMinutes: prepMinutes.clamp(0, 10080),
      cookMinutes: cookMinutes.clamp(0, 10080),
      ingredients: _normalizedRecipeIngredients(ingredients),
      instructions: instructions
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      tags: tags
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(),
      sourceUrl: sourceUrl.trim(),
      imageSourceUrl: imageSourceUrl.trim(),
      createdAt: instant,
      updatedAt: instant,
    );
    _recipes.add(recipe);
    _commit();
    return recipe;
  }

  void updateRecipe(
    String id, {
    String? title,
    String? description,
    String? category,
    String? cuisine,
    int? servings,
    int? prepMinutes,
    int? cookMinutes,
    List<RecipeIngredient>? ingredients,
    List<String>? instructions,
    List<String>? tags,
    String? sourceUrl,
  }) {
    final index = _recipes.indexWhere((recipe) => recipe.id == id);
    if (index == -1) return;
    _recipes[index] = _recipes[index].copyWith(
      title: title?.trim(),
      description: description?.trim(),
      category:
          category?.trim().isEmpty == true ? 'Sin categoría' : category?.trim(),
      cuisine: cuisine?.trim(),
      servings: servings?.clamp(1, 1000),
      prepMinutes: prepMinutes?.clamp(0, 10080),
      cookMinutes: cookMinutes?.clamp(0, 10080),
      ingredients: ingredients == null
          ? null
          : _normalizedRecipeIngredients(ingredients),
      instructions: instructions
          ?.map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      tags: tags
          ?.map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(),
      sourceUrl: sourceUrl?.trim(),
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  Future<void> importRecipeImage(String id, String sourcePath) async {
    final index = _recipes.indexWhere((recipe) => recipe.id == id);
    if (index == -1) throw StateError('No se encuentra la receta.');
    final previousImage = _recipes[index].imagePath;
    final previousThumbnail = _recipes[index].thumbnailPath;
    final imported = await _recipeAssets.importImage(id, sourcePath);
    _recipes[index] = _recipes[index].copyWith(
      imagePath: imported.imagePath,
      thumbnailPath: imported.thumbnailPath,
      imageSha256: imported.sha256,
      updatedAt: DateTime.now(),
    );
    _commit();
    for (final path in <String>[previousImage, previousThumbnail]) {
      if (path.isNotEmpty &&
          path != imported.imagePath &&
          path != imported.thumbnailPath) {
        await _recipeAssets.deleteAsset(path);
      }
    }
  }

  Future<void> importRecipeImageFromUrl(String id, String sourceUrl) async {
    final index = _recipes.indexWhere((recipe) => recipe.id == id);
    if (index == -1) throw StateError('No se encuentra la receta.');
    final imported = await _recipeAssets.importImageFromUrl(id, sourceUrl);
    _recipes[index] = _recipes[index].copyWith(
      imagePath: imported.imagePath,
      thumbnailPath: imported.thumbnailPath,
      imageSha256: imported.sha256,
      imageSourceUrl: sourceUrl,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  Future<Recipe> importRecipeFromUrl(String sourceUrl) async {
    final imported = await _recipeImporter.importUrl(sourceUrl);
    final recipe = _createImportedRecipe(imported);
    if (imported.imageSourceUrl.isNotEmpty) {
      try {
        await importRecipeImageFromUrl(recipe.id, imported.imageSourceUrl);
      } catch (_) {
        // La receta sigue siendo útil aunque la página bloquee su imagen.
      }
    }
    return recipeById(recipe.id) ?? recipe;
  }

  Recipe importRecipeFromJson(String source) {
    return _createImportedRecipe(_recipeImporter.importJson(source));
  }

  Recipe _createImportedRecipe(ImportedRecipeData imported) => createRecipe(
        title: imported.title,
        description: imported.description,
        category: imported.category,
        cuisine: imported.cuisine,
        servings: imported.servings,
        prepMinutes: imported.prepMinutes,
        cookMinutes: imported.cookMinutes,
        ingredients: imported.ingredients,
        instructions: imported.instructions,
        tags: imported.tags,
        sourceUrl: imported.sourceUrl,
        imageSourceUrl: imported.imageSourceUrl,
      );

  void toggleRecipeFavorite(String id) {
    final index = _recipes.indexWhere((recipe) => recipe.id == id);
    if (index == -1) return;
    _recipes[index] = _recipes[index].copyWith(
      favorite: !_recipes[index].favorite,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void archiveRecipe(String id) {
    final index = _recipes.indexWhere((recipe) => recipe.id == id);
    if (index == -1) return;
    _recipes[index] = _recipes[index].copyWith(
      archived: true,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void deleteRecipe(String id) {
    final recipe = recipeById(id);
    if (recipe == null) return;
    _recipes.removeWhere((value) => value.id == id);
    _commit();
    for (final path in <String>[recipe.imagePath, recipe.thumbnailPath]) {
      if (path.isNotEmpty) unawaited(_recipeAssets.deleteAsset(path));
    }
  }

  TaskModel createRecipeShoppingTask(
    String recipeId, {
    DateTime? scheduledAt,
  }) {
    final recipe = recipeById(recipeId);
    if (recipe == null) throw StateError('No se encuentra la receta.');
    if (recipe.ingredients.isEmpty) {
      throw StateError('La receta no tiene ingredientes.');
    }
    final category = _ensureTaskCategory(
      'Compras',
      const Color(0xFFDBA62D),
      Icons.shopping_cart_rounded,
    );
    final date = scheduledAt ?? logicalDate();
    final task = createTask(
      title: 'Comprar ingredientes para ${recipe.title}',
      description: 'Lista generada desde Recetas · ${recipe.servings} '
          '${recipe.servings == 1 ? 'ración' : 'raciones'}.',
      categoryIds: <String>[category.id],
      scheduledAt: date,
    );
    final shoppingLabels = <String>[];
    final seenLabels = <String>{};
    for (final ingredient in recipe.ingredients) {
      for (final label
          in _recipeIngredientClassifier.shoppingLabels(ingredient)) {
        final key = label.trim().toLowerCase();
        if (key.isNotEmpty && seenLabels.add(key)) shoppingLabels.add(label);
      }
    }
    for (final label in shoppingLabels) {
      createTask(
        title: label,
        categoryIds: <String>[category.id],
        scheduledAt: date,
        parentTaskId: task.id,
      );
    }
    return taskById(task.id) ?? task;
  }

  List<RecipeIngredient> _normalizedRecipeIngredients(
    Iterable<RecipeIngredient> ingredients,
  ) {
    return ingredients
        .map((value) => value.copyWith(
              text: value.text.trim(),
              group: value.group.trim(),
            ))
        .where((value) => value.text.isNotEmpty)
        .map(_recipeIngredientClassifier.classify)
        .toList();
  }

  TaskModel createRecipeCookingTask(
    String recipeId, {
    DateTime? scheduledAt,
  }) {
    final recipe = recipeById(recipeId);
    if (recipe == null) throw StateError('No se encuentra la receta.');
    final category = _ensureTaskCategory(
      'Cocina',
      const Color(0xFFC7744E),
      Icons.restaurant_rounded,
    );
    final date = scheduledAt ?? logicalDate();
    final time = recipe.totalMinutes > 0
        ? 'Tiempo estimado: ${recipe.totalMinutes} min.'
        : 'Tiempo estimado pendiente.';
    final task = createTask(
      title: 'Preparar ${recipe.title}',
      description: '$time · ${recipe.servings} '
          '${recipe.servings == 1 ? 'ración' : 'raciones'}.',
      categoryIds: <String>[category.id],
      scheduledAt: date,
    );
    for (var index = 0; index < recipe.instructions.length; index++) {
      createTask(
        title: '${index + 1}. ${recipe.instructions[index]}',
        categoryIds: <String>[category.id],
        scheduledAt: date,
        parentTaskId: task.id,
      );
    }
    return taskById(task.id) ?? task;
  }

  CategoryModel _ensureTaskCategory(
    String name,
    Color color,
    IconData icon,
  ) {
    for (final category in _categories) {
      if (category.name.toLowerCase() == name.toLowerCase()) return category;
    }
    return createCategory(
      name: name,
      description: 'Creada automáticamente desde Recetas.',
      colorValue: color.toARGB32(),
      icon: icon,
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
    final occurrence = _parseRecurringOccurrenceId(taskId);
    if (occurrence != null) {
      _setRecurringOccurrenceCompleted(
        occurrence.taskId,
        occurrence.key,
        completed: false,
      );
      _commit();
      return;
    }
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    final task = _tasks[index];
    final recurringParent = _recurringParentOf(task);
    if (task.recurrence.isRecurring || recurringParent != null) {
      final key = _occurrenceKey(logicalDate());
      final targetId = task.id;
      final isCompleted = task.recurrenceCompletions.containsKey(key);
      _setRecurringOccurrenceCompleted(
        targetId,
        key,
        completed: !isCompleted,
      );
      if (!isCompleted) {
        unawaited(_feedback.playTaskCompleted());
      }
      _commit();
      return;
    }
    final willComplete = task.status != TaskStatus.completed;
    final completedAt = willComplete ? DateTime.now() : null;
    _tasks[index] = task.copyWith(
      status: willComplete ? TaskStatus.completed : TaskStatus.active,
      completedAt: completedAt,
      clearCompletedAt: !willComplete,
    );
    _setSubtasksCompletion(task.id, willComplete, completedAt);
    if (task.calendarLink != null && _calendarSettings.connected) {
      await syncTaskToCalendar(taskId, silent: true);
    }
    if (willComplete) {
      unawaited(_feedback.playTaskCompleted());
    }
    _commit();
  }

  void reopenTask(String taskId) {
    final occurrence = _parseRecurringOccurrenceId(taskId);
    if (occurrence != null) {
      _setRecurringOccurrenceCompleted(
        occurrence.taskId,
        occurrence.key,
        completed: false,
      );
      _commit();
      return;
    }
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    _tasks[index] = _tasks[index].copyWith(
      status: TaskStatus.active,
      clearCompletedAt: true,
    );
    _setSubtasksCompletion(taskId, false, null);
    _commit();
  }

  void reopenTasks(Iterable<String> taskIds) {
    final ids = taskIds.toSet();
    if (ids.isEmpty) {
      return;
    }
    var changed = false;
    for (final id in ids) {
      final occurrence = _parseRecurringOccurrenceId(id);
      if (occurrence != null) {
        _setRecurringOccurrenceCompleted(
          occurrence.taskId,
          occurrence.key,
          completed: false,
        );
        changed = true;
      }
    }
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (!ids.contains(task.id) || task.status != TaskStatus.completed) {
        continue;
      }
      _tasks[i] = task.copyWith(
        status: TaskStatus.active,
        clearCompletedAt: true,
      );
      _setSubtasksCompletion(task.id, false, null);
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

  void _setSubtasksCompletion(
    String parentTaskId,
    bool completed,
    DateTime? completedAt,
  ) {
    for (var i = 0; i < _tasks.length; i++) {
      final subtask = _tasks[i];
      if (subtask.parentTaskId != parentTaskId) {
        continue;
      }
      _tasks[i] = subtask.copyWith(
        status: completed ? TaskStatus.completed : TaskStatus.active,
        completedAt: completedAt,
        clearCompletedAt: !completed,
      );
    }
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
      final recurringParent = _recurringParentOf(task);
      if (task.recurrence.isRecurring || recurringParent != null) {
        final key = _occurrenceKey(logicalDate());
        _setRecurringOccurrenceCompleted(
          task.id,
          key,
          completed: true,
        );
        changed = true;
        continue;
      }
      _tasks[i] = task.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime.now(),
      );
      _setSubtasksCompletion(task.id, true, _tasks[i].completedAt);
      changed = true;
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

  void updateWardrobeDisplaySettings(WardrobeDisplaySettings value) {
    _wardrobeDisplaySettings = value;
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
      final remote = await _cloudService.fetchEnvelope();
      if (_shouldCreateSyncConflict(remote)) {
        _syncConflict = SyncConflict(
          local: local,
          remote: remote!,
          expectedRevision: _syncMetadata.lastSeenCloudRevision,
        );
      } else if (_shouldPullRemoteEnvelope(local: local, remote: remote)) {
        _applySnapshot(remote!.snapshot);
        await _store.save(remote.snapshot);
        await _markCloudEnvelopeSeen(remote, pendingLocalChanges: false);
        _loadedFromPersistence = true;
      } else {
        final result = await _cloudService.pushEnvelope(
          snapshot: local,
          expectedRevision: _syncMetadata.lastSeenCloudRevision,
        );
        await _handleCloudPushResult(result);
        if (result.hasConflict) {
          return;
        }
      }
      await _knowledgeService.ensureLibraryRoots(_libraryItems);
      if (_cloudService is SupabaseCloudSyncRepository) {
        await _cloudService.syncKnowledgeBackup(_knowledgeService);
      }
      _lastCloudSyncAt = DateTime.now();
    } catch (_) {
      // Keep local state intact when cloud sync fails.
    } finally {
      _cloudBusy = false;
      notifyListeners();
    }
  }

  bool _shouldCreateSyncConflict(CloudSnapshotEnvelope? remote) {
    if (remote == null) {
      return false;
    }
    if (!_syncMetadata.pendingLocalChanges) {
      return false;
    }
    if (remote.revision <= _syncMetadata.lastSeenCloudRevision) {
      return false;
    }
    return true;
  }

  bool _shouldPullRemoteEnvelope({
    required AppStateSnapshot local,
    required CloudSnapshotEnvelope? remote,
  }) {
    if (remote == null) {
      return false;
    }
    // Un snapshot local pendiente nunca debe sustituirse automáticamente.
    // Si la nube avanzó, el push generará un conflicto revisable y conservará
    // los datos de este dispositivo hasta que el usuario decida.
    if (_syncMetadata.pendingLocalChanges) {
      return false;
    }
    if (remote.revision > _syncMetadata.lastSeenCloudRevision) {
      return true;
    }
    return _shouldPullRemoteSnapshot(local: local, remote: remote.snapshot);
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

  Future<void> resolveSyncConflictWithRemote() async {
    final conflict = _syncConflict;
    if (conflict == null) {
      return;
    }
    _applySnapshot(conflict.remote.snapshot);
    await _store.save(conflict.remote.snapshot);
    await _markCloudEnvelopeSeen(conflict.remote, pendingLocalChanges: false);
    _syncConflict = null;
    _lastCloudSyncAt = DateTime.now();
    notifyListeners();
  }

  Future<void> resolveSyncConflictKeepingLocal() async {
    final conflict = _syncConflict;
    if (conflict == null) {
      return;
    }
    _cloudBusy = true;
    notifyListeners();
    try {
      final result = await _cloudService.pushEnvelope(
        snapshot: conflict.local,
        expectedRevision: conflict.remote.revision,
      );
      await _handleCloudPushResult(result);
      if (!result.hasConflict) {
        _syncConflict = null;
        _lastCloudSyncAt = DateTime.now();
      }
    } finally {
      _cloudBusy = false;
      notifyListeners();
    }
  }

  Future<void> _handleCloudPushResult(
    CloudPushResult result,
  ) async {
    if (result.hasConflict && result.conflict != null) {
      _syncConflict = result.conflict;
      await _store.saveSyncMetadata(
        _syncMetadata.copyWith(pendingLocalChanges: true),
      );
      return;
    }
    _syncConflict = null;
    if (result.envelope != null) {
      await _markCloudEnvelopeSeen(
        result.envelope!,
        pendingLocalChanges: false,
      );
      return;
    }
    if (result.pushed) {
      await _store.saveSyncMetadata(
        _syncMetadata.copyWith(pendingLocalChanges: false),
      );
    }
  }

  Future<void> _markCloudEnvelopeSeen(
    CloudSnapshotEnvelope envelope, {
    required bool pendingLocalChanges,
  }) async {
    _syncMetadata = _syncMetadata.copyWith(
      deviceId: _syncMetadata.deviceId.isNotEmpty
          ? _syncMetadata.deviceId
          : _cloudService.currentDeviceId,
      lastSeenCloudRevision: envelope.revision,
      pendingLocalChanges: pendingLocalChanges,
      lastCloudHash: envelope.stateHash,
    );
    await _store.saveSyncMetadata(_syncMetadata);
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
      _notificationAvailable = granted;
      _notificationError = granted ? '' : _notificationService.permissionIssue;
      _notificationSettings = _notificationSettings.copyWith(
        permissionGranted: granted,
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
    try {
      _notificationAvailable = await _notificationService.isAvailable();
      if (!_notificationAvailable) {
        _scheduledNotificationCount = 0;
        _scheduledTaskNotificationCount = 0;
        _notificationError =
            'Las notificaciones no están disponibles en este dispositivo.';
        notifyListeners();
        return;
      }
      await _notificationService.syncSchedules(
        plans: plans,
        notificationSettings: notificationSettings,
      );
      _scheduledNotificationCount = await _notificationService.pendingCount();
      _scheduledTaskNotificationCount =
          plans.where((plan) => plan.taskId != null).length;
      _notificationAvailable = true;
      _notificationError = '';
    } catch (error) {
      _scheduledNotificationCount = 0;
      _scheduledTaskNotificationCount = 0;
      _notificationAvailable = false;
      _notificationError = error.toString();
    }
    notifyListeners();
  }

  Future<bool> sendTestNotification() async {
    _notificationBusy = true;
    notifyListeners();
    try {
      final granted = await _notificationService.requestPermissions();
      if (!granted) {
        _notificationAvailable = false;
        _notificationError = _notificationService.permissionIssue;
        return false;
      }
      await _notificationService.showTest();
      _notificationAvailable = true;
      _notificationError = '';
      return true;
    } catch (error) {
      _notificationAvailable = false;
      _notificationError = error.toString();
      return false;
    } finally {
      _notificationBusy = false;
      notifyListeners();
    }
  }

  String? takeNotificationTaskToOpen() {
    final taskId = _pendingNotificationTaskId;
    _pendingNotificationTaskId = null;
    return taskId;
  }

  void _handleNotificationAction(NotificationAction action) {
    _section = AppSection.today;
    _pendingNotificationTaskId = action.taskId;
    notifyListeners();
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
    LibraryItemStatus status = LibraryItemStatus.completed,
    DateTime? completedDate,
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
    final normalizedCompletedDate = status == LibraryItemStatus.completed
        ? completedDate ?? logicalDate()
        : null;
    final item = LibraryItem(
      id: _id('library'),
      type: type,
      title: title.trim(),
      status: status,
      completedDate: normalizedCompletedDate,
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
    var existingIndex = _libraryItems.indexWhere(
      (existing) => _isSameLibraryEntry(existing, item),
    );
    if (existingIndex == -1 && status == LibraryItemStatus.completed) {
      existingIndex = _libraryItems.indexWhere((existing) {
        if (existing.status == LibraryItemStatus.completed ||
            existing.type != item.type ||
            _libraryTitleKey(existing.title) != _libraryTitleKey(item.title)) {
          return false;
        }
        final goal = _libraryGoals.cast<LibraryGoal?>().firstWhere(
              (candidate) => candidate?.id == existing.linkedGoalId,
              orElse: () => null,
            );
        return goal != null && goal.targetYear == normalizedCompletedDate?.year;
      });
    }
    if (existingIndex != -1) {
      final existing = _libraryItems[existingIndex];
      final merged = _mergeLibraryItems(existing, item).copyWith(
        id: existing.id,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
      _libraryItems[existingIndex] = merged;
      _syncLibraryGoalFromItem(merged, now);
      unawaited(_knowledgeService.syncLibraryItem(merged));
      _commit();
      return _libraryItems[existingIndex];
    }
    _libraryItems.add(item);
    _syncLibraryGoalFromItem(item, now);
    unawaited(_knowledgeService.syncLibraryItem(item));
    _commit();
    return _libraryItems.firstWhere(
      (value) => value.id == item.id,
      orElse: () => item,
    );
  }

  void updateLibraryItem(LibraryItem updated) {
    final index = _libraryItems.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      return;
    }
    final now = DateTime.now();
    final next = updated.copyWith(
      completedDate: updated.status == LibraryItemStatus.completed
          ? updated.completedDate ?? logicalDate()
          : null,
      clearCompletedDate: updated.status != LibraryItemStatus.completed,
      updatedAt: now,
    );
    _libraryItems[index] = next;
    _syncLibraryGoalFromItem(next, now);
    unawaited(_knowledgeService.syncLibraryItem(next));
    _commit();
  }

  void updateLibraryItemStatus(
    String itemId,
    LibraryItemStatus status, {
    DateTime? completedDate,
  }) {
    final index = _libraryItems.indexWhere((item) => item.id == itemId);
    if (index == -1 || _libraryItems[index].status == status) {
      return;
    }
    final now = DateTime.now();
    final item = _libraryItems[index];
    final next = item.copyWith(
      status: status,
      completedDate: status == LibraryItemStatus.completed
          ? completedDate ?? logicalDate()
          : null,
      clearCompletedDate: status != LibraryItemStatus.completed,
      updatedAt: now,
    );
    _libraryItems[index] = next;
    _syncLibraryGoalFromItem(next, now);
    _commit();
  }

  void deleteLibraryItem(String itemId) {
    final itemIndex = _libraryItems.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) {
      return;
    }
    _knowledgeService.trashForOwner('libraryItem', itemId);
    if (_openKnowledgeLibraryItem?.id == itemId) {
      _openKnowledgeLibraryItem = null;
    }
    final deleted = _libraryItems.removeAt(itemIndex);
    final goalIndex = _libraryGoals.indexWhere(
      (goal) =>
          goal.id == deleted.linkedGoalId ||
          goal.linkedLibraryItemId == deleted.id,
    );
    if (goalIndex != -1) {
      final now = DateTime.now();
      final goal = _libraryGoals[goalIndex].copyWith(
        status: LibraryGoalStatus.pending,
        clearLinkedLibraryItemId: true,
        updatedAt: now,
      );
      final replacement = _libraryItemFromGoal(
        goal,
        _id('library'),
        LibraryItemStatus.pending,
        null,
        deleted.rating,
        now,
        now,
      );
      _libraryItems.add(replacement);
      unawaited(_knowledgeService.syncLibraryItem(replacement));
      _libraryGoals[goalIndex] = goal.copyWith(
        linkedLibraryItemId: replacement.id,
        updatedAt: now,
      );
    }
    _commit();
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
    _syncLibraryItemFromGoal(goal, now);
    _commit();
    return _libraryGoals.firstWhere((item) => item.id == goal.id);
  }

  void updateLibraryGoal(LibraryGoal updated) {
    final index = _libraryGoals.indexWhere((goal) => goal.id == updated.id);
    if (index == -1) {
      return;
    }
    final now = DateTime.now();
    final next = updated.copyWith(updatedAt: now);
    _libraryGoals[index] = next;
    _syncLibraryItemFromGoal(next, now);
    _commit();
  }

  void deleteLibraryGoal(String goalId) {
    final index = _libraryGoals.indexWhere((goal) => goal.id == goalId);
    if (index == -1) {
      return;
    }
    final deleted = _libraryGoals.removeAt(index);
    final itemIndex = _libraryItems.indexWhere(
      (item) =>
          item.id == deleted.linkedLibraryItemId ||
          item.linkedGoalId == deleted.id,
    );
    if (itemIndex != -1) {
      _libraryItems[itemIndex] = _libraryItems[itemIndex].copyWith(
        clearLinkedGoalId: true,
        updatedAt: DateTime.now(),
      );
    }
    _commit();
  }

  void toggleLibraryGoalCompleted(String goalId) {
    final index = _libraryGoals.indexWhere((goal) => goal.id == goalId);
    if (index == -1) {
      return;
    }
    final goal = _libraryGoals[index];
    final willComplete = !goal.isCompleted;
    final now = DateTime.now();
    _libraryGoals[index] = goal.copyWith(
      status: willComplete
          ? LibraryGoalStatus.completed
          : LibraryGoalStatus.pending,
      updatedAt: now,
    );
    _syncLibraryItemFromGoal(
      _libraryGoals[index],
      now,
      reopenAsPending: !willComplete,
    );
    _commit();
  }

  bool _syncLibraryItemFromGoal(
    LibraryGoal goal,
    DateTime now, {
    bool reopenAsPending = false,
  }) {
    final goalIndex = _libraryGoals.indexWhere((item) => item.id == goal.id);
    if (goalIndex == -1) {
      return false;
    }
    final normalizedTitle = _libraryTitleKey(goal.title);
    var linkedIndex = goal.linkedLibraryItemId == null
        ? -1
        : _libraryItems
            .indexWhere((item) => item.id == goal.linkedLibraryItemId);

    if (!goal.isCompleted &&
        linkedIndex != -1 &&
        _libraryItems[linkedIndex].status == LibraryItemStatus.completed &&
        !reopenAsPending) {
      final historical = _libraryItems[linkedIndex];
      _libraryItems[linkedIndex] = historical.copyWith(
        clearLinkedGoalId: true,
        updatedAt: now,
      );
      linkedIndex = -1;
    }

    final matchIndex = linkedIndex != -1
        ? linkedIndex
        : _libraryItems.indexWhere((item) {
            if (item.type != goal.type ||
                _libraryTitleKey(item.title) != normalizedTitle ||
                item.linkedGoalId != null) {
              return false;
            }
            if (goal.isCompleted) {
              return item.status == LibraryItemStatus.completed &&
                  item.completedDate?.year == goal.targetYear;
            }
            return item.status != LibraryItemStatus.completed;
          });

    if (matchIndex != -1) {
      final item = _libraryItems[matchIndex];
      final status = goal.isCompleted
          ? LibraryItemStatus.completed
          : reopenAsPending
              ? LibraryItemStatus.pending
              : item.status == LibraryItemStatus.inProgress
                  ? LibraryItemStatus.inProgress
                  : LibraryItemStatus.pending;
      final completedDate = status == LibraryItemStatus.completed
          ? item.completedDate ?? logicalDate()
          : null;
      final synced = _libraryItemFromGoal(
        goal,
        item.id,
        status,
        completedDate,
        item.rating,
        item.createdAt,
        now,
      );
      _libraryItems[matchIndex] = synced;
      _libraryGoals[goalIndex] = goal.copyWith(
        status: status == LibraryItemStatus.completed
            ? LibraryGoalStatus.completed
            : LibraryGoalStatus.pending,
        linkedLibraryItemId: synced.id,
        updatedAt: now,
      );
      return true;
    }

    final status = goal.isCompleted
        ? LibraryItemStatus.completed
        : LibraryItemStatus.pending;
    final item = _libraryItemFromGoal(
      goal,
      _id('library'),
      status,
      status == LibraryItemStatus.completed ? logicalDate() : null,
      null,
      now,
      now,
    );
    _libraryItems.add(item);
    _libraryGoals[goalIndex] = goal.copyWith(
      linkedLibraryItemId: item.id,
      updatedAt: now,
    );
    return true;
  }

  bool _syncCompletedLibraryGoalsIntoItems() {
    var changed = false;
    for (final goal in List<LibraryGoal>.of(_libraryGoals)) {
      final linked = goal.linkedLibraryItemId == null
          ? null
          : _libraryItems.cast<LibraryItem?>().firstWhere(
                (item) => item?.id == goal.linkedLibraryItemId,
                orElse: () => null,
              );
      if (linked == null || linked.linkedGoalId != goal.id) {
        changed = _syncLibraryItemFromGoal(goal, DateTime.now()) || changed;
      }
    }
    changed = _deduplicateLibraryItems() || changed;
    return changed;
  }

  LibraryItem _libraryItemFromGoal(
    LibraryGoal goal,
    String itemId,
    LibraryItemStatus status,
    DateTime? completedDate,
    double? rating,
    DateTime createdAt,
    DateTime updatedAt,
  ) {
    return LibraryItem(
      id: itemId,
      type: goal.type,
      title: goal.title.trim(),
      status: status,
      completedDate: completedDate,
      coverUrl: goal.coverUrl,
      rating: rating,
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
      linkedGoalId: goal.id,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  void _syncLibraryGoalFromItem(LibraryItem item, DateTime now) {
    final itemYear = item.completedDate?.year;
    final goalIndex = _libraryGoals.indexWhere(
      (goal) =>
          goal.id == item.linkedGoalId ||
          (goal.linkedLibraryItemId == null &&
              goal.type == item.type &&
              _libraryTitleKey(goal.title) == _libraryTitleKey(item.title) &&
              (item.status != LibraryItemStatus.completed ||
                  goal.targetYear == itemYear)),
    );
    if (goalIndex == -1) {
      return;
    }
    final goal = _libraryGoals[goalIndex];
    _libraryGoals[goalIndex] = goal.copyWith(
      type: item.type,
      title: item.title,
      status: item.status == LibraryItemStatus.completed
          ? LibraryGoalStatus.completed
          : LibraryGoalStatus.pending,
      linkedLibraryItemId: item.id,
      coverUrl: item.coverUrl,
      clearCoverUrl: item.coverUrl == null,
      note: item.note,
      clearNote: item.note == null,
      platform: item.platform,
      clearPlatform: item.platform == null,
      developer: item.developer,
      clearDeveloper: item.developer == null,
      author: item.author,
      clearAuthor: item.author == null,
      mediaType: item.mediaType,
      clearMediaType: item.mediaType == null,
      releaseYear: item.releaseYear,
      clearReleaseYear: item.releaseYear == null,
      creatorOrDirector: item.creatorOrDirector,
      clearCreatorOrDirector: item.creatorOrDirector == null,
      genre: item.genre,
      clearGenre: item.genre == null,
      format: item.format,
      clearFormat: item.format == null,
      duration: item.duration,
      clearDuration: item.duration == null,
      pages: item.pages,
      clearPages: item.pages == null,
      country: item.country,
      clearCountry: item.country == null,
      updatedAt: now,
    );
    final itemIndex = _libraryItems.indexWhere((value) => value.id == item.id);
    if (itemIndex != -1 && _libraryItems[itemIndex].linkedGoalId != goal.id) {
      _libraryItems[itemIndex] = _libraryItems[itemIndex].copyWith(
        linkedGoalId: goal.id,
        updatedAt: now,
      );
    }
  }

  bool _deduplicateLibraryItems() {
    var changed = false;
    for (var i = 0; i < _libraryItems.length; i++) {
      var base = _libraryItems[i];
      for (var j = _libraryItems.length - 1; j > i; j--) {
        final candidate = _libraryItems[j];
        if (!_isSameLibraryEntry(base, candidate)) {
          continue;
        }
        final merged = _mergeLibraryItems(base, candidate);
        _libraryItems[i] = merged;
        base = merged;
        for (var goalIndex = 0; goalIndex < _libraryGoals.length; goalIndex++) {
          final goal = _libraryGoals[goalIndex];
          if (goal.linkedLibraryItemId == candidate.id ||
              goal.linkedLibraryItemId == merged.id) {
            _libraryGoals[goalIndex] =
                goal.copyWith(linkedLibraryItemId: merged.id);
          }
        }
        _libraryItems.removeAt(j);
        changed = true;
      }
    }
    return changed;
  }

  bool _isSameLibraryEntry(LibraryItem left, LibraryItem right) {
    if (left.type != right.type ||
        _libraryTitleKey(left.title) != _libraryTitleKey(right.title)) {
      return false;
    }
    if (left.linkedGoalId != null &&
        right.linkedGoalId != null &&
        left.linkedGoalId != right.linkedGoalId) {
      return false;
    }
    if (left.status == LibraryItemStatus.completed ||
        right.status == LibraryItemStatus.completed) {
      return left.status == LibraryItemStatus.completed &&
          right.status == LibraryItemStatus.completed &&
          left.completedDate?.year == right.completedDate?.year;
    }
    return true;
  }

  LibraryItem _mergeLibraryItems(LibraryItem keeper, LibraryItem incoming) {
    final preferIncoming = incoming.linkedGoalId != null;
    final primary = preferIncoming ? incoming : keeper;
    final secondary = preferIncoming ? keeper : incoming;
    final status = incoming.status == LibraryItemStatus.completed
        ? LibraryItemStatus.completed
        : primary.status == LibraryItemStatus.inProgress ||
                secondary.status == LibraryItemStatus.inProgress
            ? LibraryItemStatus.inProgress
            : primary.status;
    final primaryDate = primary.completedDate;
    final secondaryDate = secondary.completedDate;
    return primary.copyWith(
      id: keeper.id,
      title: primary.title.trim().isEmpty ? secondary.title : primary.title,
      status: status,
      completedDate: status == LibraryItemStatus.completed
          ? primaryDate == null
              ? secondaryDate
              : secondaryDate == null || primaryDate.isBefore(secondaryDate)
                  ? primaryDate
                  : secondaryDate
          : null,
      clearCompletedDate: status != LibraryItemStatus.completed,
      coverUrl: primary.coverUrl ?? secondary.coverUrl,
      rating: primary.rating ?? secondary.rating,
      note: primary.note ?? secondary.note,
      platform: primary.platform ?? secondary.platform,
      developer: primary.developer ?? secondary.developer,
      author: primary.author ?? secondary.author,
      mediaType: primary.mediaType ?? secondary.mediaType,
      releaseYear: primary.releaseYear ?? secondary.releaseYear,
      creatorOrDirector:
          primary.creatorOrDirector ?? secondary.creatorOrDirector,
      genre: primary.genre ?? secondary.genre,
      format: primary.format ?? secondary.format,
      duration: primary.duration ?? secondary.duration,
      pages: primary.pages ?? secondary.pages,
      country: primary.country ?? secondary.country,
      linkedGoalId: primary.linkedGoalId ?? secondary.linkedGoalId,
      createdAt: keeper.createdAt.isBefore(incoming.createdAt)
          ? keeper.createdAt
          : incoming.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  String _libraryTitleKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+', unicode: true), '');
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
    _syncMetadata = await _store.loadSyncMetadata();
    final persisted = await _store.load();
    if (persisted != null) {
      _applySnapshot(persisted);
      _loadedFromPersistence = true;
      final normalized = _normalizeLoadedSpanishText();
      final syncedLibraryGoals = _syncCompletedLibraryGoalsIntoItems();
      if (persisted.schemaVersion < 4 || normalized || syncedLibraryGoals) {
        await _persist();
      }
    } else {
      _clearStateToDefaults();
    }
    await _knowledgeService.initialize();
    await _knowledgeService.ensureLibraryRoots(_libraryItems);
    if (!_isFlutterTest) {
      unawaited(_isaacSaveSync.start());
    }
    final session = await _store.loadCalendarSession();
    await _calendarService.restoreSession(session);
    _calendarAccount = await _calendarService.getAccount();
    if (_calendarAccount != null) {
      _calendarSettings = _calendarSettings.copyWith(
        connected: true,
        connectedEmail: _calendarAccount!.email,
      );
    }
    if (!_isFlutterTest) {
      unawaited(_initializeStartupIntegrations());
    }
  }

  Future<void> _initializeStartupIntegrations() async {
    if (_calendarAccount != null) {
      unawaited(refreshCalendarEvents());
    }
    try {
      _cloudBusy = true;
      notifyListeners();
      await _cloudService.initialize().timeout(const Duration(seconds: 12));
      if (_syncMetadata.deviceId.isEmpty &&
          _cloudService.currentDeviceId.isNotEmpty) {
        _syncMetadata = _syncMetadata.copyWith(
          deviceId: _cloudService.currentDeviceId,
        );
        await _store.saveSyncMetadata(_syncMetadata);
      }
      if (_cloudService.isAuthenticated) {
        await syncWithCloud().timeout(const Duration(seconds: 12));
      }
    } catch (_) {
      // La app debe abrirse aunque la red o Supabase fallen durante el arranque.
    } finally {
      _cloudBusy = false;
      notifyListeners();
    }
    await _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();
      await rescheduleTaskReminders();
    } catch (error) {
      _notificationAvailable = false;
      _scheduledNotificationCount = 0;
      _scheduledTaskNotificationCount = 0;
      _notificationError = error.toString();
      notifyListeners();
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
    _wardrobeItems
      ..clear()
      ..addAll(snapshot.wardrobeItems);
    _wardrobeOutfits
      ..clear()
      ..addAll(snapshot.wardrobeOutfits);
    _wardrobeWearLogs
      ..clear()
      ..addAll(snapshot.wardrobeWearLogs);
    _wardrobePlanEntries
      ..clear()
      ..addAll(snapshot.wardrobePlanEntries);
    _wardrobePackingLists
      ..clear()
      ..addAll(snapshot.wardrobePackingLists);
    _wardrobeImportBatches
      ..clear()
      ..addAll(snapshot.wardrobeImportBatches);
    _householdItems
      ..clear()
      ..addAll(snapshot.householdItems);
    _recipes
      ..clear()
      ..addAll(snapshot.recipes);
    _weeklyMenus
      ..clear()
      ..addAll(snapshot.weeklyMenus);
    _calendarEvents
      ..clear()
      ..addAll(snapshot.calendarEvents);
    _daySettings = snapshot.daySettings;
    _wardrobeDisplaySettings = snapshot.wardrobeDisplaySettings;
    _notificationSettings = snapshot.schemaVersion < 4
        ? const DeviceNotificationSettings()
        : snapshot.notificationSettings;
    _calendarSettings = snapshot.calendarSettings;
    _section = snapshot.section;
    _todaySort = snapshot.todaySort;
    _libraryStatusView = snapshot.libraryStatusView;
    _libraryAreaView = snapshot.libraryAreaView;
    // Phantom ya no forma parte de la interfaz. Los snapshots antiguos siguen
    // siendo compatibles, pero la aplicación vuelve siempre al tema clásico.
    _visualMode = AppVisualMode.classic;
    _manualLogicalDate = snapshot.manualLogicalDate;
    _manualLogicalDateStartedAt = snapshot.manualLogicalDateStartedAt;
    _navOrder = _normalizeNavOrder(snapshot.navOrder);
    _syncCompletedLibraryGoalsIntoItems();
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

    for (var i = 0; i < _libraryItems.length; i++) {
      final item = _libraryItems[i];
      final cleaned = item.copyWith(
        title: _cleanSpanishText(item.title),
        note: _cleanNullableSpanishText(item.note),
        platform: _cleanNullableSpanishText(item.platform),
        developer: _cleanNullableSpanishText(item.developer),
        author: _cleanNullableSpanishText(item.author),
        creatorOrDirector: _cleanNullableSpanishText(item.creatorOrDirector),
        genre: _cleanNullableSpanishText(item.genre),
        format: _cleanNullableSpanishText(item.format),
        duration: _cleanNullableSpanishText(item.duration),
        pages: _cleanNullableSpanishText(item.pages),
        country: _cleanNullableSpanishText(item.country),
      );
      if (cleaned.toJson().toString() != item.toJson().toString()) {
        _libraryItems[i] = cleaned;
        changed = true;
      }
    }

    for (var i = 0; i < _libraryGoals.length; i++) {
      final goal = _libraryGoals[i];
      final cleaned = goal.copyWith(
        title: _cleanSpanishText(goal.title),
        note: _cleanNullableSpanishText(goal.note),
        platform: _cleanNullableSpanishText(goal.platform),
        developer: _cleanNullableSpanishText(goal.developer),
        author: _cleanNullableSpanishText(goal.author),
        creatorOrDirector: _cleanNullableSpanishText(goal.creatorOrDirector),
        genre: _cleanNullableSpanishText(goal.genre),
        format: _cleanNullableSpanishText(goal.format),
        duration: _cleanNullableSpanishText(goal.duration),
        pages: _cleanNullableSpanishText(goal.pages),
        country: _cleanNullableSpanishText(goal.country),
      );
      if (cleaned.toJson().toString() != goal.toJson().toString()) {
        _libraryGoals[i] = cleaned;
        changed = true;
      }
    }

    for (var i = 0; i < _wardrobeItems.length; i++) {
      final item = _wardrobeItems[i];
      final cleaned = item.copyWith(
        name: _cleanSpanishText(item.name),
        category: _cleanSpanishText(item.category),
        colors: item.colors.map(_cleanSpanishText).toList(),
        material: _cleanSpanishText(item.material),
        seasons: item.seasons.map(_cleanSpanishText).toList(),
        occasions: item.occasions.map(_cleanSpanishText).toList(),
        tags: item.tags.map(_cleanSpanishText).toList(),
      );
      if (cleaned.toJson().toString() != item.toJson().toString()) {
        _wardrobeItems[i] = cleaned;
        changed = true;
      }
    }

    for (var i = 0; i < _wardrobeOutfits.length; i++) {
      final outfit = _wardrobeOutfits[i];
      final cleaned = outfit.copyWith(
        name: _cleanSpanishText(outfit.name),
        occasion: _cleanSpanishText(outfit.occasion),
        tags: outfit.tags.map(_cleanSpanishText).toList(),
      );
      if (cleaned.toJson().toString() != outfit.toJson().toString()) {
        _wardrobeOutfits[i] = cleaned;
        changed = true;
      }
    }

    for (var i = 0; i < _recipes.length; i++) {
      final recipe = _recipes[i];
      final cleaned = recipe.copyWith(
        title: _cleanSpanishText(recipe.title),
        description: _cleanSpanishText(recipe.description),
        category: _cleanSpanishText(recipe.category),
        cuisine: _cleanSpanishText(recipe.cuisine),
        ingredients: _normalizedRecipeIngredients(
          recipe.ingredients.map(
            (ingredient) => ingredient.copyWith(
              text: _cleanSpanishText(ingredient.text),
              group: _cleanSpanishText(ingredient.group),
            ),
          ),
        ),
        instructions: recipe.instructions.map(_cleanSpanishText).toList(),
        tags: recipe.tags.map(_cleanSpanishText).toList(),
      );
      if (cleaned.toJson().toString() != recipe.toJson().toString()) {
        _recipes[i] = cleaned;
        changed = true;
      }
    }

    for (var i = 0; i < _weeklyMenus.length; i++) {
      final menu = _weeklyMenus[i];
      final cleaned = menu.copyWith(
        title: _cleanSpanishText(menu.title),
        description: _cleanSpanishText(menu.description),
        shoppingItems: menu.shoppingItems
            .map((item) => WeeklyMenuShoppingItem(
                  name: _cleanSpanishText(item.name),
                  group: _cleanSpanishText(item.group),
                  priceCents: item.priceCents,
                ))
            .toList(),
      );
      if (cleaned.toJson().toString() != menu.toJson().toString()) {
        _weeklyMenus[i] = cleaned;
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
    var result = value
        .replaceAll('ÃƒÆ’Ã‚Â¡', 'á')
        .replaceAll('ÃƒÆ’Ã‚Â©', 'é')
        .replaceAll('ÃƒÆ’Ã‚Â­', 'í')
        .replaceAll('ÃƒÆ’Ã‚Â³', 'ó')
        .replaceAll('ÃƒÆ’Ã‚Âº', 'ú')
        .replaceAll('ÃƒÆ’Ã‚Â±', 'ñ')
        .replaceAll('ÃƒÂ¡', 'á')
        .replaceAll('ÃƒÂ©', 'é')
        .replaceAll('ÃƒÂ­', 'í')
        .replaceAll('ÃƒÂ³', 'ó')
        .replaceAll('ÃƒÂº', 'ú')
        .replaceAll('ÃƒÂ±', 'ñ')
        .replaceAll('ÃƒÂ«', 'ë')
        .replaceAll('ÃƒÂ¯', 'ï')
        .replaceAll('ÃƒÂ¼', 'ü')
        .replaceAll('ÃƒÂ§', 'ç');
    for (var pass = 0; pass < 4; pass++) {
      final decoded = _decodeMojibakeOnce(result);
      if (decoded == result) break;
      result = decoded;
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
    _syncMetadata = _syncMetadata.copyWith(
      deviceId: _syncMetadata.deviceId.isNotEmpty
          ? _syncMetadata.deviceId
          : _cloudService.currentDeviceId,
      pendingLocalChanges: true,
    );
    await _store.saveSyncMetadata(_syncMetadata);
    if (_cloudService.isAuthenticated && _syncConflict == null) {
      try {
        final result = await _cloudService.pushEnvelope(
          snapshot: snapshot,
          expectedRevision: _syncMetadata.lastSeenCloudRevision,
        );
        await _handleCloudPushResult(result);
        if (!result.hasConflict) {
          _lastCloudSyncAt = DateTime.now();
        }
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
      wardrobeItems: wardrobeItems,
      wardrobeOutfits: wardrobeOutfits,
      wardrobeWearLogs: wardrobeWearLogs,
      wardrobePlanEntries: wardrobePlanEntries,
      wardrobePackingLists: wardrobePackingLists,
      wardrobeImportBatches: wardrobeImportBatches,
      householdItems: householdItems,
      recipes: recipes,
      weeklyMenus: weeklyMenus,
      calendarEvents: calendarEvents,
      daySettings: daySettings,
      wardrobeDisplaySettings: wardrobeDisplaySettings,
      notificationSettings: notificationSettings,
      calendarSettings: calendarSettings,
      section: section,
      todaySort: todaySort,
      libraryStatusView: libraryStatusView,
      libraryAreaView: libraryAreaView,
      visualMode: visualMode,
      manualLogicalDate: _manualLogicalDate,
      manualLogicalDateStartedAt: _manualLogicalDateStartedAt,
      navOrder: navOrder,
      updatedAt: DateTime.now(),
      schemaVersion: 4,
      lastModifiedBy: _cloudService.currentEmail.isNotEmpty
          ? _cloudService.currentEmail
          : 'local-device',
    );
  }

  List<TaskModel> _tasksForDay(DateTime day) {
    final logicalToday = logicalDate();
    final occurrenceKey = _occurrenceKey(day);
    final isToday = _sameDay(day, logicalToday);
    return _tasks
        .where((task) => task.status == TaskStatus.active)
        .where((task) => !task.isSubtask)
        .where((task) {
      if (task.recurrence.isRecurring &&
          task.recurrenceCompletions.containsKey(occurrenceKey)) {
        return false;
      }
      if (task.recurrence.isRecurring) {
        if (!isToday &&
            task.recurrence.type == RecurrenceType.daily) {
          return false;
        }
        return _recursOnDay(task, day);
      }
      final scheduled = task.scheduledAt;
      if (scheduled == null) {
        return true;
      }
      if (isToday && scheduled.isBefore(logicalToday)) {
        return true;
      }
      return _sameDay(scheduled, day);
    }).toList();
  }

  bool _recursOnDay(TaskModel task, DateTime day) {
    final start = task.scheduledAt == null
        ? day
        : DateTime(
            task.scheduledAt!.year,
            task.scheduledAt!.month,
            task.scheduledAt!.day,
          );
    final target = DateTime(day.year, day.month, day.day);
    if (target.isBefore(start)) {
      return false;
    }
    final days = target.difference(start).inDays;
    switch (task.recurrence.type) {
      case RecurrenceType.none:
        return false;
      case RecurrenceType.daily:
      case RecurrenceType.everyXDays:
        return days % task.recurrence.interval == 0;
      case RecurrenceType.weekly:
        return days % (7 * task.recurrence.interval) == 0;
      case RecurrenceType.yearly:
        return target.month == start.month &&
            target.day == start.day &&
            (target.year - start.year) % task.recurrence.interval == 0;
    }
  }

  Iterable<TaskModel> _completedRecurringOccurrences(TaskModel task) {
    return task.recurrenceCompletions.entries.map((entry) {
      final day = DateTime.tryParse(entry.key) ?? entry.value;
      return task.copyWith(
        id: _recurringOccurrenceId(task.id, entry.key),
        status: TaskStatus.completed,
        scheduledAt: day,
        completedAt: entry.value,
      );
    });
  }

  String _recurringOccurrenceId(String taskId, String key) => '$taskId::$key';

  ({String taskId, String key})? _parseRecurringOccurrenceId(String id) {
    final separator = id.indexOf('::');
    if (separator == -1) {
      return null;
    }
    return (
      taskId: id.substring(0, separator),
      key: id.substring(separator + 2),
    );
  }

  String _occurrenceKey(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }

  TaskModel? _recurringParentOf(TaskModel task) {
    final parentId = task.parentTaskId;
    if (parentId == null) {
      return null;
    }
    final parent = taskById(parentId);
    if (parent == null || !parent.recurrence.isRecurring) {
      return null;
    }
    return parent;
  }

  void _setRecurringOccurrenceCompleted(
    String taskId,
    String key, {
    required bool completed,
  }) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    final task = _tasks[index];
    final completions = Map<String, DateTime>.from(task.recurrenceCompletions);
    if (completed) {
      completions[key] = DateTime.now();
    } else {
      completions.remove(key);
    }
    _tasks[index] = task.copyWith(recurrenceCompletions: completions);
  }

  List<TaskModel> _sortTasks(List<TaskModel> list) {
    final sorted = List<TaskModel>.from(list);
    switch (_todaySort) {
      case TodaySort.manual:
        sorted.sort(
            (left, right) => left.manualOrder.compareTo(right.manualOrder));
        break;
      case TodaySort.category:
        final names = <String, String>{};
        for (final category in _categories) {
          names.putIfAbsent(category.id, () => category.name);
        }
        String label(TaskModel task) => task.categoryIds.isEmpty
            ? 'zzz'
            : names[task.categoryIds.first] ?? 'zzz';
        sorted.sort((left, right) => label(left).compareTo(label(right)));
        break;
      case TodaySort.time:
        sorted.sort(
          (left, right) => (left.scheduledAt ?? logicalDate())
              .compareTo(right.scheduledAt ?? logicalDate()),
        );
        break;
      case TodaySort.project:
        final names = <String, String>{};
        for (final project in _projects) {
          names.putIfAbsent(project.id, () => project.name);
        }
        String label(TaskModel task) => task.projectIds.isEmpty
            ? 'zzz'
            : names[task.projectIds.first] ?? 'zzz';
        sorted.sort((left, right) => label(left).compareTo(label(right)));
        break;
      case TodaySort.priority:
        sorted.sort((left, right) =>
            right.priority.index.compareTo(left.priority.index));
        break;
    }
    return sorted;
  }

  double _nextManualOrder({String? parentTaskId}) {
    final pool = _tasks.where((task) => task.parentTaskId == parentTaskId);
    if (pool.isEmpty) {
      return 0;
    }
    return pool.map((task) => task.manualOrder).reduce(max) + 1;
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
    _wardrobeItems.clear();
    _wardrobeOutfits.clear();
    _wardrobeWearLogs.clear();
    _wardrobePlanEntries.clear();
    _wardrobePackingLists.clear();
    _wardrobeImportBatches.clear();
    _householdItems.clear();
    _recipes.clear();
    _weeklyMenus.clear();
    _calendarEvents.clear();
    _daySettings = const DaySettings();
    _wardrobeDisplaySettings = const WardrobeDisplaySettings();
    _notificationSettings = const DeviceNotificationSettings();
    _calendarSettings = const CalendarIntegrationSettings();
    _calendarAccount = null;
    _section = AppSection.today;
    _todaySort = TodaySort.manual;
    _libraryStatusView = LibraryItemStatus.completed;
    _libraryAreaView = LibraryAreaView.library;
    _visualMode = AppVisualMode.classic;
    _manualLogicalDate = null;
    _manualLogicalDateStartedAt = null;
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
    unawaited(_notificationActionSubscription.cancel());
    _feedback.dispose();
    unawaited(_isaacSaveSync.dispose());
    _knowledgeService.dispose();
    super.dispose();
  }
}

class _InMemoryTodoStateRepository implements TodoStateRepository {
  _InMemoryTodoStateRepository(this._snapshot);

  AppStateSnapshot? _snapshot;
  String? _calendarSession;
  LocalSyncMetadata _syncMetadata = const LocalSyncMetadata();

  @override
  Future<AppStateSnapshot?> load() async => _snapshot;

  @override
  Future<void> save(AppStateSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<String?> loadCalendarSession() async => _calendarSession;

  @override
  Future<void> saveCalendarSession(String encodedSession) async {
    _calendarSession = encodedSession;
  }

  @override
  Future<void> clearCalendarSession() async {
    _calendarSession = null;
  }

  @override
  Future<LocalSyncMetadata> loadSyncMetadata() async => _syncMetadata;

  @override
  Future<void> saveSyncMetadata(LocalSyncMetadata metadata) async {
    _syncMetadata = metadata;
  }
}
