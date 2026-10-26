import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/data/local_store_file_backed.dart';
import 'package:todo/data/repositories/local_todo_state_repository.dart';
import 'package:todo/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _FailingStore store;
  late TodoWorkspace workspace;

  AppStateSnapshot snapshot({String day = '2026-10-02'}) =>
      AppStateSnapshot.fromJson({
        'tasks': [
          TaskModel(
                  id: 'vencida',
                  title: 'Llamar',
                  scheduledAt: DateTime(2026, 10, 1),
                  manualOrder: 1)
              .toJson(),
          TaskModel(
              id: 'rutina',
              title: 'Cuidados',
              scheduledAt: DateTime(2026, 9, 1),
              recurrence: const RecurrenceRule(type: RecurrenceType.daily),
              subtaskIds: const ['sub-a', 'sub-b']).toJson(),
          const TaskModel(id: 'sub-a', title: 'Agua', parentTaskId: 'rutina')
              .toJson(),
          const TaskModel(id: 'sub-b', title: 'Comida', parentTaskId: 'rutina')
              .toJson(),
          const TaskModel(
                  id: 'privada',
                  title: 'Archivada',
                  status: TaskStatus.archived)
              .toJson(),
        ],
        'manualLogicalDate': '${day}T00:00:00.000',
        'manualLogicalDateStartedAt': DateTime.now().toIso8601String(),
        'schemaVersion': 12,
      });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('todo-kindle-');
    store = _FailingStore(directory);
    workspace = TodoWorkspace.createForTest(
        snapshot: snapshot(), stateRepository: LocalTodoStateRepository(store));
  });
  tearDown(() async {
    workspace.dispose();
    await directory.delete(recursive: true);
  });

  Future<Map<String, dynamic>> agenda() =>
      workspace.executeAgentCommand('get_kindle_agenda', {});

  Future<Map<String, dynamic>> group(List<String> ids) async {
    final data = await agenda();
    final task = (data['days'][0]['tasks'] as List)
        .firstWhere((task) => task['id'] == 'rutina');
    return {
      'request_id': 'kindle-marca-0001',
      'root_task_id': 'rutina',
      'occurrence_date': data['logical_date'],
      'expected_version': task['task_version'],
      'task_ids': ids,
    };
  }

  test('la agenda coincide con Hoy, conserva el orden e incluye subtareas',
      () async {
    final data = await agenda();
    expect(data['logical_date'], '2026-10-02');
    expect(data['days'], hasLength(7));
    expect((data['days'][0]['tasks'] as List).map((task) => task['id']),
        workspace.tasksForToday().map((task) => task.id));
    final task = (data['days'][0]['tasks'] as List)
        .firstWhere((task) => task['id'] == 'rutina');
    expect(task['subtasks'], hasLength(2));
    expect(task, isNot(contains('calendarLink')));
  });

  test(
      'dos subtareas hermanas se completan juntas y el recibo sobrevive al reinicio',
      () async {
    final args = await group(['sub-a', 'sub-b']);
    final result =
        await workspace.executeAgentCommand('complete_kindle_group', args);
    expect(result['savedLocally'], true);
    final saved = await store.load();
    workspace.dispose();
    workspace = TodoWorkspace.createForTest(
        snapshot: saved, stateRepository: LocalTodoStateRepository(store));
    expect(await workspace.executeAgentCommand('complete_kindle_group', args),
        result);
    expect(workspace.taskById('sub-a')!.recurrenceCompletions.keys,
        ['2026-10-02']);
    expect(workspace.taskById('sub-b')!.recurrenceCompletions.keys,
        ['2026-10-02']);
  });

  test('una marca sin conexión conserva su fecha después del cambio de día',
      () async {
    final args = await group(['rutina']);
    final changed = snapshot(day: '2026-10-03');
    workspace.dispose();
    workspace = TodoWorkspace.createForTest(
        snapshot: changed, stateRepository: LocalTodoStateRepository(store));
    await workspace.executeAgentCommand('complete_kindle_group', args);
    expect(workspace.taskById('rutina')!.recurrenceCompletions.keys,
        ['2026-10-02']);
    expect(
        workspace.tasksForToday().map((task) => task.id), contains('rutina'));
  });

  test('un conflicto no aplica ninguna de las marcas del grupo', () async {
    final args = await group(['sub-a', 'sub-b']);
    workspace.updateTask(
        workspace.taskById('sub-b')!.copyWith(title: 'Comida nueva'));
    final result =
        await workspace.executeAgentCommand('complete_kindle_group', args);
    expect(result['status'], 'conflict');
    expect(workspace.taskById('sub-a')!.recurrenceCompletions, isEmpty);
    expect(result['current'], isNotNull);
  });

  test('una ocurrencia omitida requiere revisión', () async {
    final args = await group(['rutina']);
    workspace.updateTask(workspace
        .taskById('rutina')!
        .copyWith(skippedRecurrenceOccurrences: {'2026-10-02'}));
    final result =
        await workspace.executeAgentCommand('complete_kindle_group', args);
    expect(result['status'], 'conflict');
    expect(workspace.taskById('rutina')!.recurrenceCompletions, isEmpty);
  });

  test('rechaza mezclar familias y completar fechas futuras', () async {
    final args = await group(['sub-a', 'vencida']);
    expect(
        (await workspace.executeAgentCommand(
            'complete_kindle_group', args))['status'],
        'conflict');
    expect(workspace.taskById('sub-a')!.recurrenceCompletions, isEmpty);
    await expectLater(
        workspace.executeAgentCommand('complete_kindle_group', {
          ...await group(['rutina']),
          'occurrence_date': '2026-10-04',
        }),
        throwsFormatException);
  });

  test('una marca ya resuelta no vuelve a abrir una rutina', () async {
    final args = await group(['rutina']);
    await workspace.executeAgentCommand('complete_kindle_group', args);
    final result =
        await workspace.executeAgentCommand('complete_kindle_group', {
      ...args,
      'request_id': 'kindle-marca-0002',
    });
    expect(result['status'], 'saved');
    expect(workspace.taskById('rutina')!.recurrenceCompletions, hasLength(1));
  });

  test('un fallo de guardado conserva el grupo para un reintento idéntico',
      () async {
    final args = await group(['sub-a', 'sub-b']);
    store.failWrites = true;
    await expectLater(
        workspace.executeAgentCommand('complete_kindle_group', args),
        throwsA(isA<FileSystemException>()));
    store.failWrites = false;
    final result =
        await workspace.executeAgentCommand('complete_kindle_group', args);
    expect(result['savedLocally'], true);
    expect((await store.load())!.agentOperationReceipts,
        contains(args['request_id']));
    expect(workspace.taskById('sub-a')!.recurrenceCompletions, hasLength(1));
  });

  test('salir espera al grupo en curso y rechaza operaciones nuevas', () async {
    final args = await group(['rutina']);
    store.barrier = Completer<void>();
    final command =
        workspace.executeAgentCommand('complete_kindle_group', args);
    while (!store.saveEntered) {
      await Future<void>.delayed(Duration.zero);
    }
    var exited = false;
    final exit = workspace.prepareForExit().then((_) => exited = true);
    await Future<void>.delayed(Duration.zero);
    expect(exited, false);
    await expectLater(
        workspace.executeAgentCommand('get_today', {}), throwsStateError);
    store.barrier!.complete();
    await command;
    await exit;
    expect((await store.load())!.agentOperationReceipts,
        contains(args['request_id']));
  });
}

class _FailingStore extends FileBackedLocalStore {
  _FailingStore(Directory directory) : super(baseDirectory: directory);
  bool failWrites = false;
  bool saveEntered = false;
  Completer<void>? barrier;
  @override
  Future<void> save(AppStateSnapshot snapshot) async {
    saveEntered = true;
    if (failWrites) {
      throw const FileSystemException('Fallo de escritura simulado');
    }
    await barrier?.future;
    await super.save(snapshot);
  }
}
