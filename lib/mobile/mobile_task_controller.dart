import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import 'mobile_background_sync.dart';
import 'mobile_lan_client.dart';
import 'mobile_lan_store.dart';
import 'mobile_notification_service.dart';
import 'mobile_task_snapshot.dart';

class MobileTaskController extends ChangeNotifier {
  MobileTaskController({
    MobileLanStore? store,
    MobileLanClient? client,
    MobileNotificationService? notifications,
  })  : _store = store ?? MobileLanStore(),
        _client = client ?? MobileLanClient(),
        _notifications = notifications ?? MobileNotificationService();

  final MobileLanStore _store;
  final MobileLanClient _client;
  final MobileNotificationService _notifications;
  StreamSubscription<MobileNotificationOpen>? _notificationSubscription;

  LanConnectionConfig? _config;
  MobileTaskSnapshot? _snapshot;
  bool _initializing = true;
  bool _syncing = false;
  String _error = '';
  String? _taskToOpen;
  MobileNotificationOpen? _activeAlarm;
  MobileNotificationPermissionState? _permissions;

  LanConnectionConfig? get config => _config;
  MobileTaskSnapshot? get snapshot => _snapshot;
  bool get initializing => _initializing;
  bool get syncing => _syncing;
  bool get paired => _config != null;
  String get error => _error;
  MobileNotificationPermissionState? get permissions => _permissions;
  MobileNotificationOpen? get activeAlarm => _activeAlarm;
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
    _initializing = false;
    notifyListeners();
    if (_config != null) {
      await scheduleMobileDailySync();
      unawaited(sync());
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
      await _store.saveToken(result.token);
      await _store.saveConfig(result.config);
      _config = result.config;
      await scheduleMobileDailySync();
      _syncing = false;
      await sync();
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
      var updated = current.copyWith(
        endpoint: result.endpoint,
        lastSyncAt: DateTime.now(),
      );
      if (result.changed && result.snapshot != null) {
        final next = MobileTaskSnapshot.fromJson(result.snapshot!);
        await _store.saveSnapshot(result.snapshot!);
        await _notifications.syncSnapshot(next);
        _snapshot = next;
        updated = updated.copyWith(revision: next.revision);
      }
      _config = updated;
      await _store.saveConfig(updated);
      return true;
    } catch (error) {
      _error = _friendlyError(error);
      return false;
    } finally {
      _syncing = false;
      notifyListeners();
    }
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
    await cancelMobileDailySync();
    await _notifications.cancelAllTodoNotifications();
    await _store.clear();
    _config = null;
    _snapshot = null;
    _error = '';
    notifyListeners();
  }

  TaskModel? taskById(String id) => _snapshot?.taskById(id);

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
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
