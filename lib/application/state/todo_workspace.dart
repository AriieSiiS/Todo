import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../config/supabase_config.dart';
import '../../core/date/date_helpers.dart';
import '../../data/local_store.dart';
import 'package:todo_core/runtime_writer_lock.dart';
import 'package:todo_core/kindle_workspace.dart';
import 'package:todo_core/task_agenda.dart';
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
import '../../services/plant_asset_service.dart';
import '../../services/important_alarm_service.dart';
import '../../services/recipe_asset_service.dart';
import '../../services/recipe_import_service.dart';
import '../../services/supabase_cloud_service.dart';
import '../../services/task_feedback_service.dart';
import '../../services/task_scheduler_service.dart';
import '../../services/wardrobe_asset_service.dart';
import '../../services/agent_bridge_service.dart';
import '../../services/shopping_price_service.dart';
import '../../services/steam_service.dart';

part 'todo_workspace_agent.dart';
part 'todo_workspace_biblioteca.dart';
part 'todo_workspace_calendario.dart';
part 'todo_workspace_compras.dart';
part 'todo_workspace_diario.dart';
part 'todo_workspace_enfoque.dart';
part 'todo_workspace_gastos.dart';
part 'todo_workspace_hogar.dart';
part 'todo_workspace_notificaciones.dart';
part 'todo_workspace_nube.dart';
part 'todo_workspace_plantas.dart';
part 'todo_workspace_recetas.dart';
part 'todo_workspace_resumen.dart';
part 'todo_workspace_ropa.dart';
part 'todo_workspace_viajes.dart';
part 'todo_workspace_tareas.dart';

class TodoWorkspace extends ChangeNotifier {
  TodoWorkspace._(
      this._store,
      this._cloudService,
      this._calendarService,
      this._notificationService,
      this._importantAlarmService,
      this._scheduler,
      this._feedback,
      this._knowledgeService,
      {PlantAssetService? plantAssets,
      ShoppingPriceService? priceService,
      SteamService? steamService})
      : _plantAssets = plantAssets ?? PlantAssetService(),
        steam = steamService ?? SteamService(),
        priceTracking = priceService ?? ShoppingPriceService() {
    _isaacSaveSync = IsaacSaveSyncService(_knowledgeService);
    _notificationActionSubscription =
        _notificationService.actions.listen(_handleNotificationAction);
    _importantAlarmService.addListener(_handleImportantAlarmChange);
  }

  static Future<TodoWorkspace> create({String? initialImportantAlarmId}) async {
    final controller = TodoWorkspace._(
      LocalTodoStateRepository(LocalStore()),
      SupabaseCloudSyncRepository(SupabaseCloudService()),
      CalendarServiceRepository(createCalendarService()),
      NotificationServiceRepository(createNotificationService()),
      ImportantAlarmService(),
      TaskSchedulerService(),
      TaskFeedbackService(),
      KnowledgeService(),
    );
    try {
      controller._writerLock = await RuntimeWriterLock.acquire(RuntimeWriterLock.defaultDirectory());
      await controller._load();
      controller.resumeFocusAfterStartup();
      await controller._importantAlarmService.initialize(
        initialAlarmId: initialImportantAlarmId,
      );
    } catch (_) {
      controller.dispose();
      rethrow;
    }
    if (!controller._isFlutterTest) {
      controller._agentBridge =
          AgentBridgeService(controller.executeAgentCommand);
      // Una conexión de agente fallida no impide utilizar Todo.
      try {
        await controller._agentBridge!.start();
      } catch (error) {
        debugPrint(
            'No se pudo iniciar el puente local de Todo: ${error.runtimeType}');
      }
      unawaited(controller._initializeStartupIntegrations());
      unawaited(controller.priceTracking.start());
      controller._externalWardrobePoll = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(controller._mergeExternalWardrobeItems()),
      );
    }
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
    AppSection.plants,
    AppSection.recipes,
    AppSection.journal,
    AppSection.trips,
    AppSection.focus,
    AppSection.completed,
    AppSection.settings,
  ];

  @visibleForTesting
  static TodoWorkspace createForTest({
    AppStateSnapshot? snapshot,
    PlantAssetService? plantAssets,
    TodoStateRepository? stateRepository,
    ShoppingPriceService? priceService,
    SteamService? steamService,
  }) {
    final controller = TodoWorkspace._(
      stateRepository ?? _InMemoryTodoStateRepository(snapshot),
      SupabaseCloudSyncRepository(SupabaseCloudService()),
      CalendarServiceRepository(createCalendarService()),
      NotificationServiceRepository(createNotificationService()),
      ImportantAlarmService(enabled: false),
      TaskSchedulerService(),
      TaskFeedbackService(enabled: false),
      KnowledgeService.inMemory(),
      plantAssets: plantAssets,
      priceService: priceService ?? ShoppingPriceService(enabled: false),
      steamService: steamService,
    );
    if (snapshot != null) {
      controller._applySnapshot(snapshot);
      controller._migrateLegacyChecklistsToSubtasks();
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
  final ShoppingPriceService priceTracking;
  final SteamService steam;
  final CloudSyncRepository _cloudService;
  final CalendarRepository _calendarService;
  final NotificationRepository _notificationService;
  final ImportantAlarmService _importantAlarmService;
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
  final List<ShoppingItem> _shoppingItems = <ShoppingItem>[];
  final List<Plant> _plants = <Plant>[];
  final List<Recipe> _recipes = <Recipe>[];
  final List<WeeklyMenu> _weeklyMenus = <WeeklyMenu>[];
  final List<JournalEntry> _journalEntries = <JournalEntry>[];
  final List<Trip> _trips = <Trip>[];
  final List<FocusSession> _focusSessions = <FocusSession>[];
  ActiveFocus? _activeFocus;
  final List<CalendarEventModel> _calendarEvents = <CalendarEventModel>[];
  final WardrobeAssetService _wardrobeAssets = WardrobeAssetService();
  final HouseholdAssetService _householdAssets = HouseholdAssetService();
  final HouseholdAssetService _journalAssets =
      HouseholdAssetService(directoryName: 'journal');
  final HouseholdAssetService _tripAssets =
      HouseholdAssetService(directoryName: 'trips');
  final HouseholdAssetService _shoppingAssets =
      HouseholdAssetService(directoryName: 'shopping');
  final PlantAssetService _plantAssets;
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
  List<AppSection> _navOrder = List<AppSection>.of(defaultNavOrder);
  AppVisibilitySettings _visibilitySettings = const AppVisibilitySettings();
  DateTime? _manualLogicalDate;
  DateTime? _manualLogicalDateStartedAt;
  DateTime? _lastSavedAt;
  String _saveError = '';
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
  RuntimeWriterLock? _writerLock;
  Timer? _externalWardrobePoll;
  Timer? _focusTimer;
  bool _checkingExternalWardrobe = false;
  AgentBridgeService? _agentBridge;
  Future<void> _agentCommandQueue = Future<void>.value();
  bool _agentClosing = false;
  final Map<String, dynamic> _agentOperationReceipts = {};

  void _notifyAgentChange() => notifyListeners();

  /// Permite que las extensiones por área avisen a la interfaz del cambio.
  void _notifyChanged() => notifyListeners();

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
  List<ShoppingItem> get shoppingItems =>
      List<ShoppingItem>.unmodifiable(_shoppingItems);
  List<Plant> get plants => List<Plant>.unmodifiable(_plants);
  List<Recipe> get recipes => List<Recipe>.unmodifiable(_recipes);
  List<WeeklyMenu> get weeklyMenus =>
      List<WeeklyMenu>.unmodifiable(_weeklyMenus);
  List<JournalEntry> get journalEntries =>
      List<JournalEntry>.unmodifiable(_journalEntries);
  List<Trip> get trips => List<Trip>.unmodifiable(_trips);
  List<FocusSession> get focusSessions =>
      List<FocusSession>.unmodifiable(_focusSessions);
  ActiveFocus? get activeFocus => _activeFocus;
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
  List<AppSection> get navOrder => List<AppSection>.unmodifiable(_navOrder);
  AppVisibilitySettings get visibilitySettings => _visibilitySettings;
  List<AppSection> get visibleNavOrder =>
      navOrder.where(_visibilitySettings.sectionVisible).toList();

  void setSectionVisible(AppSection section, bool visible) {
    if (section == AppSection.settings) return;
    final hidden = _visibilitySettings.hiddenSections.toSet();
    if (visible) {
      hidden.remove(section.name);
    } else {
      hidden.add(section.name);
    }
    _visibilitySettings = AppVisibilitySettings(
      hiddenSections: hidden.toList(),
      hiddenTabs: _visibilitySettings.hiddenTabs,
    );
    if (!_visibilitySettings.sectionVisible(_section)) {
      _section = visibleNavOrder.first;
      _openKnowledgeLibraryItem = null;
    }
    _commit();
  }

  void setTabVisible(AppSection section, String tab, bool visible) {
    if (!(AppVisibilitySettings.tabs[section]?.containsKey(tab) ?? false)) {
      return;
    }
    final current = _visibilitySettings.visibleTabs(section);
    if (!visible && current.length == 1 && current.contains(tab)) return;
    final hidden = (_visibilitySettings.hiddenTabs[section.name] ?? []).toSet();
    if (visible) {
      hidden.remove(tab);
    } else {
      hidden.add(tab);
    }
    _visibilitySettings = AppVisibilitySettings(
      hiddenSections: _visibilitySettings.hiddenSections,
      hiddenTabs: {
        ..._visibilitySettings.hiddenTabs,
        section.name: hidden.toList()
      },
    );
    _commit();
  }

  DateTime? get manualLogicalDate => _activeManualLogicalDate(now);
  bool get hasManualLogicalDate => manualLogicalDate != null;
  DateTime? get lastSavedAt => _lastSavedAt;
  String get saveError => _saveError;
  bool get loadedFromPersistence => _loadedFromPersistence;
  bool get calendarBusy => _calendarBusy;
  bool get notificationBusy => _notificationBusy;
  bool get notificationAvailable => _notificationAvailable;
  int get scheduledNotificationCount => _scheduledNotificationCount;
  int get scheduledTaskNotificationCount => _scheduledTaskNotificationCount;
  String get notificationError => _notificationError;
  String? get pendingNotificationTaskId => _pendingNotificationTaskId;
  ImportantAlarmOccurrence? get currentImportantAlarm =>
      _importantAlarmService.current;
  int get importantAlarmCount => _importantAlarmService.remainingCount;
  String get importantAlarmError => _importantAlarmService.lastError;
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
    _section = _visibilitySettings.sectionVisible(value)
        ? value
        : visibleNavOrder.first;
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
    final next = List<AppSection>.of(visibleNavOrder);
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
    var visibleIndex = 0;
    _navOrder = _navOrder
        .map((section) => _visibilitySettings.sectionVisible(section)
            ? next[visibleIndex++]
            : section)
        .toList();
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

  TaskAgenda get _taskAgenda => TaskAgenda(
    tasks: _tasks, daySettings: _daySettings, now: now,
    manualDate: _manualLogicalDate, manualStartedAt: _manualLogicalDateStartedAt,
    sort: _todaySort,
    categoryNames: TaskAgenda.firstNames(_categories.map((item) => (item.id, item.name))),
    projectNames: TaskAgenda.firstNames(_projects.map((item) => (item.id, item.name))),
  );

  DateTime logicalDate([DateTime? instant]) => _taskAgenda.logicalDate(instant);
  DateTime _ruleBasedLogicalDate(DateTime value) => _taskAgenda.ruleBasedLogicalDate(value);
  DateTime? _activeManualLogicalDate(DateTime value) => _taskAgenda.activeManualDate(value);

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
      shoppingItems: shoppingItems,
      plants: plants,
      recipes: recipes,
      weeklyMenus: weeklyMenus,
      journalEntries: journalEntries,
      trips: trips,
      focusSessions: focusSessions,
      calendarEvents: calendarEvents,
      daySettings: daySettings,
      wardrobeDisplaySettings: wardrobeDisplaySettings,
      visibilitySettings: visibilitySettings,
      notificationSettings: notificationSettings,
      calendarSettings: calendarSettings,
      navOrder: navOrder,
    );
  }

  void updateSettings(DaySettings value) {
    _daySettings = value;
    _commit();
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
    _ensurePlantsCategory();
    await _calendarService.disconnect();
    await _store.clearCalendarSession();
    _commit();
  }

  Future<void> _load() async {
    await SupabaseConfig.load();
    _syncMetadata = await _store.loadSyncMetadata();
    final persisted = await _store.load();
    if (persisted != null) {
      _applySnapshot(persisted);
      _loadedFromPersistence = true;
      final normalized = _normalizeLoadedSpanishText();
      final migratedChecklists = _migrateLegacyChecklistsToSubtasks();
      final syncedLibraryGoals = _syncCompletedLibraryGoalsIntoItems();
      final migratedPlants = await _prepareEmptyPlantsFeature();
      if (persisted.schemaVersion < 12 ||
          normalized ||
          migratedChecklists ||
          syncedLibraryGoals ||
          migratedPlants) {
        await _persist();
      }
    } else {
      _clearStateToDefaults();
      _ensurePlantsCategory();
      await _persist();
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
  }

  @visibleForTesting
  bool mergeExternalWardrobeItemsForTest(List<WardrobeItem> externalItems) {
    final changed = _mergeExternalWardrobeSnapshot(externalItems);
    if (changed) notifyListeners();
    return changed;
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
    _agentOperationReceipts
      ..clear()
      ..addAll(snapshot.agentOperationReceipts);
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
      ..addAll(
        snapshot.schemaVersion < 5
            ? snapshot.notes.map(
                (note) => note.status == NoteStatus.converted
                    ? note.copyWith(status: NoteStatus.inbox)
                    : note,
              )
            : snapshot.notes,
      );
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
    _shoppingItems
      ..clear()
      ..addAll(snapshot.shoppingItems);
    _plants
      ..clear()
      ..addAll(snapshot.plants);
    _recipes
      ..clear()
      ..addAll(snapshot.recipes);
    _weeklyMenus
      ..clear()
      ..addAll(snapshot.weeklyMenus);
    _journalEntries
      ..clear()
      ..addAll(snapshot.journalEntries);
    _trips
      ..clear()
      ..addAll(snapshot.trips);
    _focusSessions
      ..clear()
      ..addAll(snapshot.focusSessions);
    _activeFocus = snapshot.activeFocus;
    _calendarEvents
      ..clear()
      ..addAll(snapshot.calendarEvents);
    _daySettings = snapshot.daySettings;
    _wardrobeDisplaySettings = snapshot.wardrobeDisplaySettings;
    _visibilitySettings = snapshot.visibilitySettings;
    _notificationSettings = snapshot.schemaVersion < 4
        ? const DeviceNotificationSettings()
        : snapshot.notificationSettings;
    _calendarSettings = snapshot.calendarSettings;
    _section = snapshot.section;
    _todaySort = snapshot.todaySort;
    _libraryStatusView = snapshot.libraryStatusView;
    _libraryAreaView = snapshot.libraryAreaView;
    _manualLogicalDate = snapshot.manualLogicalDate;
    _manualLogicalDateStartedAt = snapshot.manualLogicalDateStartedAt;
    _navOrder = _normalizeNavOrder(snapshot.navOrder);
    if (!_visibilitySettings.sectionVisible(_section)) {
      _section = visibleNavOrder.first;
    }
    _syncCompletedLibraryGoalsIntoItems();
  }

  @visibleForTesting
  Future<bool> prepareEmptyPlantsFeatureForTest() =>
      _prepareEmptyPlantsFeature();

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
        category: WardrobeTaxonomy.normalizeCategory(
          _cleanSpanishText(item.category),
        ),
        colors: WardrobeTaxonomy.normalizeColors(
          item.colors.map(_cleanSpanishText),
        ),
        material: _cleanSpanishText(item.material),
        seasons: WardrobeTaxonomy.normalizeSeasons(
          item.seasons.map(_cleanSpanishText),
        ),
        occasions: WardrobeTaxonomy.normalizeOccasions(
          item.occasions.map(_cleanSpanishText),
        ),
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
      try {
        await _persist();
      } catch (_) {
        // El error queda registrado en `saveError` y la interfaz lo muestra.
        return;
      }
      if (!_isFlutterTest) {
        await rescheduleTaskReminders();
      }
    });
  }

  /// Guarda el snapshot local y registra el fallo para avisar al usuario.
  /// Vuelve a lanzar el error para que quien llama no dé el guardado por hecho.
  Future<void> _saveSnapshotTracked(AppStateSnapshot snapshot) async {
    try {
      await _store.save(snapshot);
      if (_saveError.isNotEmpty) {
        _saveError = '';
        notifyListeners();
      }
    } catch (error) {
      _saveError = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Reintenta guardar los cambios pendientes tras un fallo.
  Future<void> retrySave() async {
    try {
      await flushPendingChanges();
    } catch (_) {
      // El aviso persiste mientras `saveError` no esté vacío.
    }
  }

  Future<void> _persist() async {
    final snapshot = _buildSnapshot();
    await _saveSnapshotTracked(snapshot);
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
    // Solo Ajustes muestra la hora del último guardado y el estado de la nube;
    // avisar a toda la interfaz tras cada guardado duplicaba las reconstrucciones.
    if (_section == AppSection.settings || _cloudService.isAuthenticated) {
      notifyListeners();
    }
  }

  Future<void> flushPendingChanges() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    await _persist();
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
      shoppingItems: shoppingItems,
      plants: plants,
      recipes: recipes,
      weeklyMenus: weeklyMenus,
      journalEntries: journalEntries,
      trips: trips,
      focusSessions: focusSessions,
      activeFocus: _activeFocus,
      calendarEvents: calendarEvents,
      daySettings: daySettings,
      wardrobeDisplaySettings: wardrobeDisplaySettings,
      visibilitySettings: visibilitySettings,
      notificationSettings: notificationSettings,
      calendarSettings: calendarSettings,
      section: section,
      todaySort: todaySort,
      libraryStatusView: libraryStatusView,
      libraryAreaView: libraryAreaView,
      manualLogicalDate: _manualLogicalDate,
      manualLogicalDateStartedAt: _manualLogicalDateStartedAt,
      navOrder: navOrder,
      updatedAt: DateTime.now(),
      schemaVersion: 12,
      agentOperationReceipts: jsonDecode(jsonEncode(_agentOperationReceipts))
          as Map<String, dynamic>,
      lastModifiedBy: _cloudService.currentEmail.isNotEmpty
          ? _cloudService.currentEmail
          : 'local-device',
    );
  }

  bool _recursOnDay(TaskModel task, DateTime day) => TaskAgenda.recursOnDay(task, day);

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

  void _clearStateToDefaults() {
    _agentOperationReceipts.clear();
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
    _shoppingItems.clear();
    _plants.clear();
    _recipes.clear();
    _weeklyMenus.clear();
    _journalEntries.clear();
    _trips.clear();
    _focusSessions.clear();
    _activeFocus = null;
    _calendarEvents.clear();
    _daySettings = const DaySettings();
    _wardrobeDisplaySettings = const WardrobeDisplaySettings();
    _visibilitySettings = const AppVisibilitySettings();
    _notificationSettings = const DeviceNotificationSettings();
    _calendarSettings = const CalendarIntegrationSettings();
    _calendarAccount = null;
    _section = AppSection.today;
    _todaySort = TodaySort.manual;
    _libraryStatusView = LibraryItemStatus.completed;
    _libraryAreaView = LibraryAreaView.library;
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

  @override
  void dispose() {
    steam.dispose();
    priceTracking.dispose();
    unawaited(_agentBridge?.stop());
    unawaited(_writerLock?.release());
    _saveDebounce?.cancel();
    _externalWardrobePoll?.cancel();
    _focusTimer?.cancel();
    unawaited(_notificationActionSubscription.cancel());
    _importantAlarmService.removeListener(_handleImportantAlarmChange);
    _importantAlarmService.dispose();
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
  Future<AppStateSnapshot?> loadIfChanged() => load();

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
