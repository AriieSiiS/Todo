import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';

enum ImportantAlarmStatus { scheduled, active, snoozed }

class ImportantAlarmOccurrence {
  const ImportantAlarmOccurrence({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.originalTriggerAt,
    required this.triggerAt,
    required this.minutesBefore,
    required this.status,
  });

  final String id;
  final String taskId;
  final String taskTitle;
  final DateTime originalTriggerAt;
  final DateTime triggerAt;
  final int minutesBefore;
  final ImportantAlarmStatus status;

  ImportantAlarmOccurrence copyWith({
    String? id,
    DateTime? triggerAt,
    ImportantAlarmStatus? status,
  }) =>
      ImportantAlarmOccurrence(
        id: id ?? this.id,
        taskId: taskId,
        taskTitle: taskTitle,
        originalTriggerAt: originalTriggerAt,
        triggerAt: triggerAt ?? this.triggerAt,
        minutesBefore: minutesBefore,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'taskId': taskId,
        'taskTitle': taskTitle,
        'originalTriggerAt': originalTriggerAt.toIso8601String(),
        'triggerAt': triggerAt.toIso8601String(),
        'minutesBefore': minutesBefore,
        'status': status.name,
      };

  factory ImportantAlarmOccurrence.fromJson(Map<String, dynamic> json) {
    final statusName = json['status']?.toString();
    return ImportantAlarmOccurrence(
      id: json['id']?.toString() ?? '',
      taskId: json['taskId']?.toString() ?? '',
      taskTitle: json['taskTitle']?.toString() ?? 'Tarea',
      originalTriggerAt: DateTime.tryParse(
            json['originalTriggerAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
      triggerAt: DateTime.tryParse(json['triggerAt']?.toString() ?? '') ??
          DateTime.now(),
      minutesBefore: (json['minutesBefore'] as num?)?.toInt() ?? 0,
      status: ImportantAlarmStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => ImportantAlarmStatus.scheduled,
      ),
    );
  }
}

/// Mantiene el estado recuperable de las alarmas y coordina el puente nativo.
class ImportantAlarmService extends ChangeNotifier {
  ImportantAlarmService({
    this.enabled = true,
    Directory? runtimeDirectory,
  }) : _runtimeDirectoryOverride = runtimeDirectory;

  static const MethodChannel _channel = MethodChannel('todo/important_alarms');
  final bool enabled;
  final Directory? _runtimeDirectoryOverride;
  final List<ImportantAlarmOccurrence> _occurrences = [];
  bool _startedByAlarm = false;
  String _lastError = '';

  List<ImportantAlarmOccurrence> get occurrences =>
      List.unmodifiable(_occurrences);
  List<ImportantAlarmOccurrence> get activeQueue => _occurrences
      .where((item) => item.status == ImportantAlarmStatus.active)
      .toList()
    ..sort((left, right) => left.triggerAt.compareTo(right.triggerAt));
  ImportantAlarmOccurrence? get current =>
      activeQueue.isEmpty ? null : activeQueue.first;
  int get remainingCount => activeQueue.length;
  String get lastError => _lastError;

  Future<void> initialize({String? initialAlarmId}) async {
    if (!enabled) return;
    _startedByAlarm = initialAlarmId != null;
    await _load();
    _channel.setMethodCallHandler(_handleNativeCall);
    await _activateOverdue(requestedId: initialAlarmId);
  }

  Future<void> syncPlans(List<NotificationPlan> plans) async {
    if (!enabled) return;
    final importantPlans = plans
        .where((plan) => plan.isImportant && plan.alarmId != null)
        .toList();
    final planIds = importantPlans.map((plan) => plan.alarmId!).toSet();
    _occurrences.removeWhere((item) =>
        item.status == ImportantAlarmStatus.scheduled &&
        !planIds.contains(item.id));
    for (final plan in importantPlans) {
      final index = _occurrences.indexWhere((item) => item.id == plan.alarmId);
      final taskId = plan.taskId ?? '';
      final item = ImportantAlarmOccurrence(
        id: plan.alarmId!,
        taskId: taskId,
        taskTitle: plan.title,
        originalTriggerAt: plan.when,
        triggerAt: plan.when,
        minutesBefore: plan.minutesBefore,
        status: ImportantAlarmStatus.scheduled,
      );
      if (index == -1) {
        _occurrences.add(item);
      } else if (_occurrences[index].status == ImportantAlarmStatus.scheduled) {
        _occurrences[index] = item;
      }
    }
    await _persistAndSchedule();
    await _activateOverdue();
  }

  Future<void> activate(String alarmId) async {
    if (!enabled) return;
    final index = _occurrences.indexWhere((item) => item.id == alarmId);
    if (index == -1) return;
    _occurrences[index] =
        _occurrences[index].copyWith(status: ImportantAlarmStatus.active);
    await _persist();
    await _showWindow();
    notifyListeners();
  }

  Future<void> showTest() async {
    final now = DateTime.now();
    final id = 'prueba_${now.millisecondsSinceEpoch}';
    _occurrences.add(ImportantAlarmOccurrence(
      id: id,
      taskId: '',
      taskTitle: 'Prueba de alarma importante',
      originalTriggerAt: now,
      triggerAt: now.add(const Duration(minutes: 10)),
      minutesBefore: 0,
      status: ImportantAlarmStatus.scheduled,
    ));
    await _persistAndSchedule();
    final programmingError = _lastError;
    final index = _occurrences.indexWhere((item) => item.id == id);
    _occurrences[index] = _occurrences[index].copyWith(
      triggerAt: now,
      status: ImportantAlarmStatus.active,
    );
    await _persist();
    if (enabled) {
      try {
        await _channel.invokeMethod<void>('syncAlarms', const []);
      } catch (error) {
        _lastError = programmingError.isNotEmpty
            ? programmingError
            : 'No se pudo retirar la programación de prueba: $error';
      }
    }
    if (programmingError.isNotEmpty) _lastError = programmingError;
    await _showWindow();
    notifyListeners();
  }

  void reportAudioError(Object error) {
    _lastError =
        'La alarma está visible, pero no se pudo reproducir el sonido: '
        '$error';
    notifyListeners();
  }

  Future<void> stopCurrent({bool keepApplicationOpen = false}) async {
    final item = current;
    if (item == null) return;
    _occurrences.removeWhere((candidate) => candidate.id == item.id);
    await _persistAndSchedule();
    notifyListeners();
    if (current == null) {
      await _restoreWindow(
        closeApplication: _startedByAlarm && !keepApplicationOpen,
      );
      _startedByAlarm = false;
    } else {
      await _showWindow();
    }
  }

  Future<void> snoozeCurrent() async {
    final item = current;
    if (item == null) return;
    final triggerAt = DateTime.now().add(const Duration(minutes: 5));
    final snoozedId =
        '${item.id}_pospuesta_${triggerAt.millisecondsSinceEpoch}';
    _occurrences.removeWhere((candidate) => candidate.id == item.id);
    _occurrences.add(item.copyWith(
      id: snoozedId,
      triggerAt: triggerAt,
      status: ImportantAlarmStatus.snoozed,
    ));
    await _persistAndSchedule();
    notifyListeners();
    if (current == null) {
      await _restoreWindow(closeApplication: _startedByAlarm);
      _startedByAlarm = false;
    } else {
      await _showWindow();
    }
  }

  Future<void> _activateOverdue({String? requestedId}) async {
    final now = DateTime.now();
    var changed = false;
    for (var index = 0; index < _occurrences.length; index++) {
      final item = _occurrences[index];
      if (item.status == ImportantAlarmStatus.active ||
          item.id == requestedId ||
          !item.triggerAt.isAfter(now)) {
        if (item.status != ImportantAlarmStatus.active) {
          _occurrences[index] =
              item.copyWith(status: ImportantAlarmStatus.active);
          changed = true;
        }
      }
    }
    if (changed) await _persist();
    if (current != null) await _showWindow();
    notifyListeners();
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'importantAlarmActivated') {
      await activate(call.arguments?.toString() ?? '');
    } else if (call.method == 'alarmCloseRequested') {
      await stopCurrent();
    }
  }

  Future<void> _showWindow() async {
    if (!enabled) return;
    try {
      await _channel.invokeMethod<void>('showAlarmWindow', <String, dynamic>{
        'startedByAlarm': _startedByAlarm,
      });
      await _channel.invokeMethod<void>('setAlarmActive', true);
    } catch (error) {
      _lastError = 'No se pudo poner la alarma en primer plano: $error';
    }
  }

  Future<void> _restoreWindow({required bool closeApplication}) async {
    if (!enabled) return;
    try {
      await _channel.invokeMethod<void>('setAlarmActive', false);
      await _channel.invokeMethod<void>('restoreAlarmWindow', <String, dynamic>{
        'closeApplication': closeApplication,
      });
    } catch (error) {
      _lastError = 'No se pudo restaurar la ventana: $error';
    }
  }

  Future<void> _persistAndSchedule() async {
    if (!enabled) return;
    await _persist();
    try {
      await _channel.invokeMethod<void>(
        'syncAlarms',
        _occurrences
            .where((item) => item.status != ImportantAlarmStatus.active)
            .map((item) => <String, dynamic>{
                  'id': item.id,
                  'triggerAt': item.triggerAt.toIso8601String(),
                })
            .toList(),
      );
      _lastError = '';
    } catch (error) {
      _lastError = 'No se pudo programar la alarma importante: $error';
    }
  }

  Future<File> _stateFile() async {
    final directory = _runtimeDirectoryOverride ?? _defaultRuntimeDirectory();
    if (!await directory.exists()) await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}'
        'important_alarm_state.json');
  }

  Directory _defaultRuntimeDirectory() {
    final profile =
        Platform.environment['USERPROFILE'] ?? Directory.current.path;
    return Directory('$profile${Platform.pathSeparator}Documents'
        '${Platform.pathSeparator}Todo${Platform.pathSeparator}runtime');
  }

  Future<void> _load() async {
    final file = await _stateFile();
    if (!await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      final records =
          (decoded as Map<String, dynamic>)['alarms'] as List? ?? [];
      _occurrences
        ..clear()
        ..addAll(records.whereType<Map>().map((item) =>
            ImportantAlarmOccurrence.fromJson(item.cast<String, dynamic>())));
    } catch (error) {
      _lastError = 'No se pudo recuperar el estado de las alarmas: $error';
    }
  }

  Future<void> _persist() async {
    if (!enabled) return;
    final file = await _stateFile();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent(' ').convert(<String, dynamic>{
        'version': 1,
        'alarms': _occurrences.map((item) => item.toJson()).toList(),
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  @override
  void dispose() {
    if (enabled) _channel.setMethodCallHandler(null);
    super.dispose();
  }
}
