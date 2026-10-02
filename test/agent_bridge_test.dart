import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/data/local_store_file_backed.dart';
import 'package:todo/data/repositories/local_todo_state_repository.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/services/agent_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late FileBackedLocalStore store;
  late TodoWorkspace workspace;
  late AgentBridgeService bridge;
  late HttpClient client;
  late Map<String, dynamic> session;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('todo-puente-');
    store = FileBackedLocalStore(baseDirectory: root);
    workspace = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot.fromJson({
        'tasks': [
          const TaskModel(
              id: 'original',
              title: 'Tarea original',
              scheduledAt: null,
              materials: ['Conservar material']).toJson(),
          const TaskModel(
                  id: 'rutina',
                  title: 'Regar',
                  recurrence: RecurrenceRule(type: RecurrenceType.daily))
              .toJson(),
        ],
        'manualLogicalDate': '2026-10-02T00:00:00.000',
        'manualLogicalDateStartedAt': DateTime.now().toIso8601String(),
        'schemaVersion': 11,
      }),
      stateRepository: LocalTodoStateRepository(store),
    );
    bridge = AgentBridgeService(workspace.executeAgentCommand,
        runtimeDirectory: Directory('${root.path}/runtime'));
    await bridge.start();
    session = jsonDecode(
        await File('${root.path}/runtime/agent_bridge_session.json')
            .readAsString());
    client = HttpOverrides.runWithHttpOverrides(
        () => HttpClient(), _NetworkOverrides());
  });
  tearDown(() async {
    client.close(force: true);
    await bridge.stop();
    workspace.dispose();
    await root.delete(recursive: true);
  });

  Future<(int, Map<String, dynamic>)> call(
      String name, Map<String, dynamic> arguments,
      {bool authorized = true, String? origin}) async {
    final request = await client
        .postUrl(Uri.parse('http://127.0.0.1:${session['port']}/command'));
    request.headers.contentType = ContentType.json;
    if (authorized) {
      request.headers.set('Authorization', 'Bearer ${session['token']}');
    }
    if (origin != null) request.headers.set('Origin', origin);
    request.write(jsonEncode({'name': name, 'arguments': arguments}));
    final response = await request.close();
    return (
      response.statusCode,
      jsonDecode(await utf8.decoder.bind(response).join())
          as Map<String, dynamic>
    );
  }

  Future<String> version(String taskId) async {
    final (_, result) = await call('get_task', {'task_id': taskId});
    return result['task']['task_version'] as String;
  }

  test('rechaza peticiones sin token, desde páginas web y campos no permitidos',
      () async {
    expect((await call('get_today', {}, authorized: false)).$1, 401);
    expect(
        (await call('get_today', {}, origin: 'https://ejemplo.test')).$1, 401);
    expect((await call('export_state', {})).$1, 400);
    expect(
        (await call('create_task', {
          'title': 'No crear',
          'request_id': 'peticion-001',
          'status': 'archived'
        }))
            .$1,
        400);
    expect(workspace.tasks.length, 2);
    expect(
        await File('${root.path}/runtime/todo_state.json').exists(), isFalse);
  });

  test('consulta el estado en memoria y el día lógico sin guardar archivos',
      () async {
    workspace.updateTask(
        workspace.taskById('original')!.copyWith(title: 'Edición visible'));
    final (status, today) = await call('get_today', {});
    expect(status, 200);
    expect(today['date'], '2026-10-02');
    expect(
        (today['tasks'] as List)
            .any((task) => task['title'] == 'Edición visible'),
        isTrue);
  });

  test(
      'reintentos simultáneos crean una tarea y se reconocen después de recargar',
      () async {
    final arguments = {'request_id': 'creacion-001', 'title': 'Añadir café'};
    final responses = await Future.wait(
        [for (var i = 0; i < 5; i++) call('create_task', arguments)]);
    expect(
        responses.every((response) =>
            response.$1 == 200 && response.$2['savedLocally'] == true),
        isTrue);
    final taskId = responses.first.$2['created']['id'];
    expect(
        responses.every((response) => response.$2['created']['id'] == taskId),
        isTrue);
    final saved = (await store.load())!;
    expect(saved.tasks.where((task) => task.title == 'Añadir café').length, 1);
    expect(saved.agentOperationReceipts.length, 1);
    final reloaded = TodoWorkspace.createForTest(
        snapshot: saved, stateRepository: LocalTodoStateRepository(store));
    try {
      final repeated =
          await reloaded.executeAgentCommand('create_task', arguments);
      expect(repeated['created']['id'], taskId);
      expect(reloaded.tasks.length, saved.tasks.length);
    } finally {
      reloaded.dispose();
    }
    expect(
        (await call('create_task', {...arguments, 'title': 'Otra tarea'})).$1,
        400);
  });

  test(
      'versiones antiguas no sobrescriben ediciones y se conservan otros campos y tareas',
      () async {
    final old = await version('original');
    workspace.updateTask(
        workspace.taskById('original')!.copyWith(description: 'Edición local'));
    final args = {
      'request_id': 'edicion-001',
      'task_id': 'original',
      'expected_version': old,
      'title': 'Desde ChatGPT'
    };
    expect((await call('update_task', args)).$1, 400);
    expect(workspace.taskById('original')!.title, 'Tarea original');
    final fresh = await version('original');
    workspace.updateTask(
        workspace.taskById('rutina')!.copyWith(title: 'Regar mañana'));
    expect((await call('update_task', {...args, 'expected_version': fresh})).$1,
        200);
    await workspace.flushPendingChanges();
    final saved = (await store.load())!;
    expect(saved.tasks.first.description, 'Edición local');
    expect(saved.tasks.first.materials, ['Conservar material']);
    expect(saved.tasks.last.title, 'Regar mañana');
  });

  test('un fallo de persistencia no confirma éxito y el reintento no duplica',
      () async {
    final obstruction = Directory('${root.path}/runtime/todo_state.json.tmp');
    await obstruction.create();
    final args = {'request_id': 'fallo-001', 'title': 'Guardar después'};
    final failed = await call('create_task', args);
    expect(failed.$1, 500);
    expect(failed.$2['savedLocally'], isNull);
    await obstruction.delete();
    expect((await call('create_task', args)).$1, 200);
    expect(
        (await store.load())!
            .tasks
            .where((task) => task.title == 'Guardar después')
            .length,
        1);
  });

  test('completar una rutina dos veces conserva la ocurrencia completada',
      () async {
    final args = {
      'request_id': 'rutina-001',
      'task_id': 'rutina',
      'expected_version': await version('rutina')
    };
    expect((await call('complete_task', args)).$1, 200);
    expect((await call('complete_task', args)).$1, 200);
    expect(
        (await call('complete_task', {
          ...args,
          'request_id': 'rutina-002',
          'expected_version': await version('rutina')
        }))
            .$1,
        200);
    expect(workspace.taskById('rutina')!.recurrenceCompletions.keys,
        ['2026-10-02']);
    expect(
        (await call('get_today', {}))
            .$2['tasks']
            .any((task) => task['id'] == 'rutina'),
        isFalse);
  });

  test(
      'mover conserva la hora y rechaza fechas normalizadas de forma silenciosa',
      () async {
    workspace.updateTask(workspace
        .taskById('original')!
        .copyWith(scheduledAt: DateTime(2026, 10, 2, 14, 35)));
    final args = {
      'request_id': 'mover-001',
      'task_id': 'original',
      'expected_version': await version('original')
    };
    expect((await call('move_task_to_day', {...args, 'date': '2026-02-30'})).$1,
        400);
    expect((await call('move_task_to_day', {...args, 'date': '2026-10-04'})).$1,
        200);
    expect((await store.load())!.tasks.first.scheduledAt,
        DateTime(2026, 10, 4, 14, 35));
  });
  test('un segundo puente no reemplaza la sesión del escritor activo',
      () async {
    final second = AgentBridgeService(workspace.executeAgentCommand,
        runtimeDirectory: Directory('${root.path}/runtime'));
    try {
      await expectLater(second.start(), throwsA(isA<StateError>()));
      expect(
          jsonDecode(
              await File('${root.path}/runtime/agent_bridge_session.json')
                  .readAsString()),
          session);
      expect((await call('get_today', {})).$1, 200);
    } finally {
      await second.stop();
    }
  });

  test('buscar tareas completadas por fecha conserva las tareas completadas',
      () async {
    workspace.updateTask(workspace
        .taskById('original')!
        .copyWith(scheduledAt: DateTime(2026, 10, 2, 12)));
    expect(
        (await call('complete_task', {
          'task_id': 'original',
          'request_id': 'completar-001',
          'expected_version': await version('original')
        }))
            .$1,
        200);
    final result =
        await call('list_tasks', {'status': 'completed', 'date': '2026-10-02'});
    expect(
        (result.$2['tasks'] as List).map((task) => task['id']), ['original']);
  });

  test('el cliente MCP stdio modifica Flutter a través del puente', () async {
    final python = File('mcp_server/.venv-chatgpt/Scripts/python.exe');
    if (!python.existsSync()) return;
    final result = await Process.run(python.absolute.path,
        ['-m', 'unittest', 'test_chatgpt_live.BridgeSDKTest', '-v'],
        workingDirectory: Directory('mcp_server').absolute.path,
        environment: {
          'TODO_TEST_BRIDGE_PATH': '${root.path}/runtime/todo_state.json',
          'PYTHONUTF8': '1'
        },
        stdoutEncoding: utf8,
        stderrEncoding: utf8);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(
        workspace.tasks
            .where((task) => task.title == 'Té desde stdio')
            .single
            .status,
        TaskStatus.completed);
  });
}

class _NetworkOverrides extends HttpOverrides {}
