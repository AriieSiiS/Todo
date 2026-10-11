import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import 'mobile_background_sync.dart';
import 'mobile_lan_client.dart';
import 'mobile_lan_store.dart';
import 'mobile_notification_service.dart';
import 'mobile_task_snapshot.dart';
import 'mobile_wardrobe_snapshot.dart';
import 'mobile_wardrobe_store.dart';

class MobileTaskController extends ChangeNotifier {
  MobileTaskController({
    MobileLanStore? store,
    MobileLanClient? client,
    MobileNotificationService? notifications,
    MobileWardrobeStore? wardrobeStore,
  })  : _store = store ?? MobileLanStore(),
        _client = client ?? MobileLanClient(),
        _notifications = notifications ?? MobileNotificationService(),
        _wardrobeStore = wardrobeStore ?? MobileWardrobeStore();

  final MobileLanStore _store;
  final MobileLanClient _client;
  final MobileNotificationService _notifications;
  final MobileWardrobeStore _wardrobeStore;
  Future<void> _usageWrite = Future<void>.value();
  bool _disposed = false;
  int _wardrobeEpoch = 0;
  // Invalida la sincronización de tareas en curso al desconectar o cerrar.
  int _syncEpoch = 0;
  Completer<void>? _syncIdle;
  Completer<void>? _wardrobeIdle;
  StreamSubscription<MobileNotificationOpen>? _notificationSubscription;

  LanConnectionConfig? _config;
  MobileTaskSnapshot? _snapshot;
  bool _initializing = true;
  bool _syncing = false;
  String _error = '';
  String? _taskToOpen;
  MobileNotificationOpen? _activeAlarm;
  MobileNotificationPermissionState? _permissions;
  MobileWardrobeSnapshot? _wardrobeSnapshot;
  Map<String, Map<String, int>> _usedUnits = {};
  bool _wardrobeSyncing = false;
  int _wardrobeDownloaded = 0;
  int _wardrobeTotal = 0;
  int _missingPhotos = 0;
  bool _wardrobeReady = false;
  String _wardrobeError = '';

  LanConnectionConfig? get config => _config;
  MobileTaskSnapshot? get snapshot => _snapshot;
  bool get initializing => _initializing;
  bool get syncing => _syncing;
  bool get paired => _config != null;
  String get error => _error;
  MobileNotificationPermissionState? get permissions => _permissions;
  MobileNotificationOpen? get activeAlarm => _activeAlarm;
  MobileWardrobeSnapshot? get wardrobeSnapshot => _wardrobeSnapshot;
  bool get wardrobeSyncing => _wardrobeSyncing;
  int get wardrobeDownloaded => _wardrobeDownloaded;
  int get wardrobeTotal => _wardrobeTotal;
  int get missingPhotos => _missingPhotos;
  bool get wardrobeReady => _wardrobeReady;
  String get wardrobeError => _wardrobeError;

  int usedUnits(String listId, MobilePackingEntry entry) =>
      (_usedUnits[listId]?[entry.itemId] ?? 0).clamp(0, entry.quantity);

  int remainingUnits(String listId, MobilePackingEntry entry) =>
      entry.quantity - usedUnits(listId, entry);
  bool get stale =>
      _config?.lastSyncAt == null ||
      DateTime.now().difference(_config!.lastSyncAt!) >
          const Duration(hours: 26);

  List<TaskModel> get todayTasks => _snapshot?.tasksForToday() ?? const [];
  List<TaskModel> get upcomingTasks => _snapshot?.upcomingTasks() ?? const [];
  List<TaskModel> get allTasks => _snapshot?.allActiveTasks() ?? const [];

  Future<void> initialize() async {
    _notificationSubscription = _notifications.openedTasks.listen((event) {
      if (event.important) {
        _activeAlarm = event;
      } else {
        _taskToOpen = event.taskId;
      }
      notifyListeners();
    });
    await _notifications.initialize();
    _config = await _store.loadConfig();
    _snapshot = await _store.loadSnapshot();
    _wardrobeSnapshot = await _wardrobeStore.loadSnapshot();
    if (_wardrobeSnapshot != null &&
        _wardrobeSnapshot!.serverId != _config?.serverId) {
      await _wardrobeStore.clear();
      _wardrobeSnapshot = null;
    }
    _usedUnits = await _wardrobeStore.loadUsage();
    if (_wardrobeSnapshot != null) await _clampUsage(_wardrobeSnapshot!);
    await _refreshPhotoStatus();
    _initializing = false;
    notifyListeners();
    if (_config != null) {
      await scheduleMobileDailySync();
      unawaited(sync());
      unawaited(syncWardrobe());
    }
  }

  String? takeTaskToOpen() {
    final value = _taskToOpen;
    _taskToOpen = null;
    return value;
  }

  Future<void> pair(String rawQr, {String deviceName = 'Android'}) async {
    _syncing = true;
    _error = '';
    notifyListeners();
    try {
      final pairing = LanPairingData.parse(rawQr);
      final result = await _client.pair(pairing, deviceName: deviceName);
      if (_config?.serverId != null &&
          _config!.serverId != result.config.serverId) {
        await _wardrobeStore.clear();
        _wardrobeSnapshot = null;
        _usedUnits = {};
      }
      await _store.saveToken(result.token);
      await _store.saveConfig(result.config);
      _config = result.config;
      await scheduleMobileDailySync();
      _syncing = false;
      await sync();
      unawaited(syncWardrobe());
    } catch (error) {
      _error = _friendlyError(error);
      rethrow;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<bool> sync() async {
    final current = _config;
    if (current == null || _syncing) return false;
    final epoch = _syncEpoch;
    final idle = Completer<void>();
    _syncIdle = idle;
    _syncing = true;
    _error = '';
    notifyListeners();
    try {
      final token = await _store.loadToken();
      if (token == null || token.isEmpty) {
        _error = 'Falta la credencial del móvil. Vuelve a emparejarlo.';
        return false;
      }
      final result = await _client.sync(config: current, token: token);
      // Si se desconectó o se cerró mientras esperaba la respuesta, se descarta.
      if (epoch != _syncEpoch) return false;
      var updated = current.copyWith(
        endpoint: result.endpoint,
        lastSyncAt: DateTime.now(),
      );
      if (result.changed && result.snapshot != null) {
        final next = MobileTaskSnapshot.fromJson(result.snapshot!);
        await _store.saveSnapshot(result.snapshot!);
        if (epoch != _syncEpoch) return false;
        await _notifications.syncSnapshot(next);
        _snapshot = next;
        updated = updated.copyWith(revision: next.revision);
      }
      if (epoch != _syncEpoch) return false;
      _config = updated;
      await _store.saveConfig(updated);
      return true;
    } catch (error) {
      if (epoch == _syncEpoch) _error = _friendlyError(error);
      return false;
    } finally {
      _syncing = false;
      if (identical(_syncIdle, idle)) _syncIdle = null;
      idle.complete();
      notifyListeners();
    }
  }

  Future<void> syncAll() async {
    await sync();
    await syncWardrobe();
  }

  Future<bool> syncWardrobe() async {
    final current = _config;
    if (current == null || _wardrobeSyncing) return false;
    final epoch = _wardrobeEpoch;
    final idle = Completer<void>();
    _wardrobeIdle = idle;
    _wardrobeSyncing = true;
    _wardrobeError = '';
    _wardrobeDownloaded = 0;
    _wardrobeTotal = 0;
    notifyListeners();
    try {
      final token = await _store.loadToken();
      if (token == null || token.isEmpty) {
        throw StateError('Falta la credencial del móvil.');
      }
      final result = await _client.syncWardrobe(
        config: current,
        token: token,
        revision: _wardrobeSnapshot?.revision ?? '',
      );
      if (epoch != _wardrobeEpoch) return false;
      var incoming = result.changed && result.snapshot != null
          ? MobileWardrobeSnapshot.fromJson(result.snapshot!)
              .mergePrevious(_wardrobeSnapshot)
          : _wardrobeSnapshot;
      if (incoming == null) return false;
      final pending = <(MobileWardrobeItem, String, String)>[];
      for (final item in incoming.items) {
        if (item.imageAvailable &&
            item.imageSha256.isNotEmpty &&
            !await _wardrobeStore.hasImage(
                item.id, 'original', item.imageSha256)) {
          pending.add((item, 'original', item.imageSha256));
        }
        if (item.thumbnailSha256.isNotEmpty &&
            !await _wardrobeStore.hasImage(
                item.id, 'thumbnail', item.thumbnailSha256)) {
          pending.add((item, 'thumbnail', item.thumbnailSha256));
        }
      }
      _wardrobeTotal = pending.length;
      notifyListeners();
      final unavailable = <String, Set<String>>{};
      for (final (item, variant, digest) in pending) {
        if (epoch != _wardrobeEpoch) return false;
        final bytes = await _client.wardrobeImage(
          config: current,
          endpoint: result.endpoint,
          token: token,
          itemId: item.id,
          variant: variant,
        );
        if (epoch != _wardrobeEpoch) return false;
        if (bytes != null) {
          await _wardrobeStore.saveImage(item.id, variant, digest, bytes);
        } else {
          unavailable.putIfAbsent(item.id, () => <String>{}).add(variant);
        }
        _wardrobeDownloaded++;
        notifyListeners();
      }
      if (epoch != _wardrobeEpoch) return false;
      incoming = incoming.withUnavailableAssets(unavailable);
      if (result.changed || unavailable.isNotEmpty) {
        await _wardrobeStore.saveSnapshot(incoming);
      }
      _wardrobeSnapshot = incoming;
      await _clampUsage(incoming);
      await _refreshPhotoStatus();
      return true;
    } catch (error) {
      _wardrobeError = _friendlyError(error);
      await _refreshPhotoStatus();
      return false;
    } finally {
      _wardrobeSyncing = false;
      if (identical(_wardrobeIdle, idle)) _wardrobeIdle = null;
      idle.complete();
      notifyListeners();
    }
  }

  Future<void> _refreshPhotoStatus() async {
    final snapshot = _wardrobeSnapshot;
    if (snapshot == null) {
      _missingPhotos = 0;
      _wardrobeReady = false;
      return;
    }
    var missing = 0;
    var pending = 0;
    for (final item in snapshot.items) {
      if (!item.imageAvailable || item.imageSha256.isEmpty) {
        if (item.imageSha256.isEmpty ||
            !await _wardrobeStore.hasImage(
                item.id, 'original', item.imageSha256)) {
          missing++;
        }
      } else if (!await _wardrobeStore.hasImage(
          item.id, 'original', item.imageSha256)) {
        pending++;
      }
      if (item.thumbnailSha256.isNotEmpty &&
          !await _wardrobeStore.hasImage(
              item.id, 'thumbnail', item.thumbnailSha256)) {
        pending++;
      }
    }
    _missingPhotos = missing;
    _wardrobeReady = pending == 0;
    notifyListeners();
  }

  Future<void> changeUsedUnits(
      String listId, MobilePackingEntry entry, int delta) async {
    final previous = usedUnits(listId, entry);
    final next = (previous + delta).clamp(0, entry.quantity);
    if (previous == next) return;
    _usedUnits.putIfAbsent(listId, () => {})[entry.itemId] = next;
    notifyListeners();
    _usageWrite = _usageWrite.then((_) => _wardrobeStore.saveUsage(_usedUnits));
    await _usageWrite;
  }

  Future<void> _clampUsage(MobileWardrobeSnapshot snapshot) async {
    var changed = false;
    for (final list in snapshot.packingLists) {
      final tripUsage = _usedUnits[list.id];
      if (tripUsage == null) continue;
      for (final entry in list.entries) {
        final previous = tripUsage[entry.itemId];
        if (previous == null) continue;
        final clamped = previous.clamp(0, entry.quantity);
        if (clamped != previous) {
          tripUsage[entry.itemId] = clamped;
          changed = true;
        }
      }
    }
    if (changed) await _wardrobeStore.saveUsage(_usedUnits);
  }

  Future<File?> wardrobeImageFile(MobileWardrobeItem item,
      {bool original = false}) async {
    final variant = original ? 'original' : 'thumbnail';
    final digest = original ? item.imageSha256 : item.thumbnailSha256;
    final file = await _wardrobeStore.imageFile(item.id, variant, digest);
    if (file != null && await file.exists()) return file;
    if (!original) return wardrobeImageFile(item, original: true);
    return null;
  }

  Future<void> requestNotificationPermissions() async {
    _permissions = await _notifications.requestPermissions();
    final current = _snapshot;
    if (current != null) await _notifications.syncSnapshot(current);
    notifyListeners();
  }

  Future<void> stopActiveAlarm() async {
    final alarm = _activeAlarm;
    if (alarm == null) return;
    await _notifications.stopAlarm(alarm);
    _activeAlarm = null;
    notifyListeners();
  }

  Future<void> snoozeActiveAlarm() async {
    final alarm = _activeAlarm;
    if (alarm == null) return;
    await _notifications.snoozeAlarm(alarm);
    _activeAlarm = null;
    notifyListeners();
  }

  void openActiveAlarmTask() {
    final alarm = _activeAlarm;
    if (alarm == null) return;
    _taskToOpen = alarm.taskId;
    _activeAlarm = null;
    notifyListeners();
  }

  Future<void> disconnect() async {
    _wardrobeEpoch++;
    _syncEpoch++;
    await _wardrobeIdle?.future;
    await _syncIdle?.future;
    await _usageWrite;
    await cancelMobileDailySync();
    await _notifications.cancelAllTodoNotifications();
    await _store.clear();
    await _wardrobeStore.clear();
    _config = null;
    _snapshot = null;
    _wardrobeSnapshot = null;
    _usedUnits = {};
    _wardrobeReady = false;
    _error = '';
    notifyListeners();
  }

  TaskModel? taskById(String id) => _snapshot?.taskById(id);

  @override
  void dispose() {
    _disposed = true;
    _syncEpoch++;
    _wardrobeEpoch++;
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Bad state: ', '');
    if (text.contains('SocketException') || text.contains('TimeoutException')) {
      return 'No se encuentra el PC emparejado en esta red Wi-Fi. Se conserva la última copia.';
    }
    if (text.startsWith('FormatException: ')) {
      return text.substring('FormatException: '.length);
    }
    return text;
  }
}
