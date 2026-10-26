import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'domain/enums.dart';
import 'domain/library_item.dart';
import 'domain/library_reading.dart';
import 'domain/task.dart';
import 'domain/settings.dart';
import 'task_agenda.dart';

part 'kindle_tasks.dart';
part 'kindle_reading.dart';

/// Operaciones Kindle independientes de Flutter y de su persistencia concreta.
class KindleWorkspace {
  KindleWorkspace({
    required List<TaskModel> tasks,
    required List<LibraryItem> books,
    required Map<String, dynamic> receipts,
    required TaskAgenda agenda,
    required this.save,
    this.source = 'app',
  })  : _tasks = tasks,
        _libraryItems = books,
        _agentOperationReceipts = receipts,
        _agenda = agenda;

  final List<TaskModel> _tasks;
  final List<LibraryItem> _libraryItems;
  final Map<String, dynamic> _agentOperationReceipts;
  final TaskAgenda _agenda;
  final Future<void> Function() save;
  final String source;
  DaySettings get _daySettings => _agenda.daySettings;

  static const schemas = <String, Set<String>>{
    'get_kindle_agenda': {'start_date'},
    'get_kindle_books': {},
    'complete_kindle_group': {
      'request_id',
      'root_task_id',
      'occurrence_date',
      'expected_version',
      'task_ids'
    },
    'sync_kindle_book': {
      'request_id',
      'document_id',
      'source_id',
      'sequence',
      'title',
      'author',
      'library_item_id',
      'observed_at',
      'progress',
      'page',
      'total_pages',
      'position',
      'chapter',
      'statistics',
      'quotes'
    },
  };

  Future<Map<String, dynamic>> execute(
      String name, Map<String, dynamic> args) async {
    final allowed = schemas[name];
    if (allowed == null || args.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('La operación Kindle no es válida.');
    }
    if (name == 'get_kindle_books') return _kindleBooks();
    if (name == 'get_kindle_agenda') {
      final raw = args['start_date'];
      if (raw == null || raw == '') return _kindleAgenda(logicalDate());
      final day = raw is String ? DateTime.tryParse(raw) : null;
      if (day == null || _occurrenceKey(day) != raw) {
        throw const FormatException('La fecha de la agenda no es válida.');
      }
      return _kindleAgenda(day);
    }
    final id = args['request_id'];
    if (id is! String || !RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(id)) {
      throw const FormatException(
          'El identificador de operación no es válido.');
    }
    final fingerprint = _agentDigest({'name': name, 'arguments': args});
    final receipt = _agentOperationReceipts[id] as Map?;
    if (receipt != null) {
      if (receipt['fingerprint'] != fingerprint) {
        throw const FormatException(
            'request_id ya se utilizó para una operación diferente.');
      }
      await save();
      return Map<String, dynamic>.from(receipt['result'] as Map);
    }
    if (_agentOperationReceipts.length >= 10000) {
      throw const FormatException(
          'El registro de operaciones está lleno. Revisa la conexión desde Todo.');
    }
    return name == 'complete_kindle_group'
        ? _completeKindleGroup(args, id, fingerprint)
        : _syncKindleBook(args, id, fingerprint);
  }

  static String digest(Object? value) {
    Object? ordered(Object? item) {
      if (item is Map) {
        final keys = item.keys.cast<String>().toList()..sort();
        return {for (final key in keys) key: ordered(item[key])};
      }
      return item is List ? item.map(ordered).toList() : item;
    }

    return sha256.convert(utf8.encode(jsonEncode(ordered(value)))).toString();
  }

  String _agentDigest(Object? value) => digest(value);
  String _occurrenceKey(DateTime day) => TaskAgenda.occurrenceKey(day);
  DateTime logicalDate() => _agenda.logicalDate();
  DateTime? _activeManualLogicalDate(DateTime day) =>
      _agenda.activeManualDate(day);
  List<TaskModel> tasksForDate(DateTime day) =>
      _agenda.sortTasks(_agenda.tasksForDay(day));
  bool _recursOnDay(TaskModel task, DateTime day) =>
      TaskAgenda.recursOnDay(task, day);
  TaskModel? taskById(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  void _setRecurringOccurrenceCompleted(String id, String key,
      {required bool completed}) {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) return;
    final task = _tasks[index];
    final values = Map<String, DateTime>.from(task.recurrenceCompletions);
    if (completed) {
      values[key] = DateTime.now();
    } else {
      values.remove(key);
    }
    _tasks[index] = task.copyWith(recurrenceCompletions: values);
  }

  String _libraryTitleKey(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+', unicode: true), '');

  Future<Map<String, dynamic>> _finishAgentOperation(
      String id, String fingerprint, Map<String, dynamic> payload) async {
    final result = <String, dynamic>{
      ...payload,
      'request_id': id,
      'savedLocally': true,
      'source': source
    };
    _agentOperationReceipts[id] = {
      'fingerprint': fingerprint,
      'result': result
    };
    await save();
    return jsonDecode(jsonEncode(result)) as Map<String, dynamic>;
  }
}
