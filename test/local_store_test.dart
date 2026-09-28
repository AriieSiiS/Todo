import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/data/local_store_file_backed.dart';
import 'package:todo/data/runtime_state_paths.dart';
import 'package:todo/domain/models.dart';

void main() {
  late Directory root;
  late FileBackedLocalStore store;
  late File state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('todo-auditoria-store-');
    store = FileBackedLocalStore(baseDirectory: root);
    state = File('${root.path}/runtime/${RuntimeStatePaths.stateFileName}');
  });
  tearDown(() => root.delete(recursive: true));

  AppStateSnapshot snapshot(String title) => AppStateSnapshot.fromJson({
        'tasks': [TaskModel(id: 'tarea', title: title).toJson()],
      });

  test(
      'los guardados simultáneos conservan el último estado y sus preferencias',
      () async {
    final writes = [
      for (var i = 0; i < 24; i++) store.save(snapshot('Tarea $i')),
    ];
    final read = store.load();
    await Future.wait(writes);
    expect((await read)!.tasks.single.title, 'Tarea 23');
    final preferences = await SharedPreferences.getInstance();
    expect(
        AppStateSnapshot.fromEncodedJson(
                preferences.getString('todo.snapshot.v1')!)
            .tasks
            .single
            .title,
        'Tarea 23');
    expect(await File('${state.path}.tmp').exists(), isFalse);
    expect(await File('${state.path}.previous').exists(), isFalse);
  });

  test('un guardado fallido no bloquea operaciones posteriores', () async {
    final session = File(
        '${root.path}/runtime/${RuntimeStatePaths.calendarSessionFileName}');
    await Directory('${session.path}.tmp').create(recursive: true);
    await expectLater(
        store.saveCalendarSession('{}'), throwsA(isA<FileSystemException>()));
    await store.save(snapshot('Después del fallo'));
    expect((await store.load())!.tasks.single.title, 'Después del fallo');
  });

  test(
      'la consulta periódica detecta cambios externos sin reutilizar listas mutables',
      () async {
    await store.save(snapshot('Primera'));
    final first = await store.loadIfChanged();
    expect(first!.tasks.single.title, 'Primera');
    first.tasks.clear();
    expect(await store.loadIfChanged(), isNull);
    expect((await store.load())!.tasks.single.title, 'Primera');
    await state.writeAsString(snapshot('Segunda').toEncodedJson());
    expect((await store.loadIfChanged())!.tasks.single.title, 'Segunda');
    expect(await store.loadIfChanged(), isNull);
  });

  test('recupera la copia anterior si el temporal está incompleto', () async {
    await state.parent.create(recursive: true);
    await File('${state.path}.tmp').writeAsString('{');
    await File('${state.path}.previous')
        .writeAsString(snapshot('Recuperada').toEncodedJson());
    expect((await store.load())!.tasks.single.title, 'Recuperada');
    expect(jsonDecode(await state.readAsString()), isA<Map>());
  });

  test('cerrar la sesión impide recuperar credenciales de temporales antiguos',
      () async {
    await store.saveCalendarSession('{"sesion":"antigua"}');
    final session = File(
        '${root.path}/runtime/${RuntimeStatePaths.calendarSessionFileName}');
    await File('${session.path}.tmp').writeAsString('{"sesion":"antigua"}');
    await File('${session.path}.previous')
        .writeAsString('{"sesion":"antigua"}');
    await store.clearCalendarSession();
    expect(await store.loadCalendarSession(), isNull);
    expect(await File('${session.path}.tmp').exists(), isFalse);
    expect(await File('${session.path}.previous').exists(), isFalse);
  });
}
