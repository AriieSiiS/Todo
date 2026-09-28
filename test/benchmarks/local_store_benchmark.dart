import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/data/local_store_file_backed.dart';
import 'package:todo/domain/models.dart';

// Ejecutar con flutter test test/benchmarks/local_store_benchmark.dart --no-pub.
void main() {
  test('compara consultas de un estado sin cambios con 10000 tareas', () async {
    SharedPreferences.setMockInitialValues({});
    final root = await Directory.systemTemp.createTemp('todo-medicion-');
    addTearDown(() => root.delete(recursive: true));
    final store = FileBackedLocalStore(baseDirectory: root);
    await store.save(AppStateSnapshot.fromJson({
      'tasks': [
        for (var i = 0; i < 10000; i++)
          TaskModel(id: '$i', title: 'Tarea $i').toJson()
      ],
    }));
    for (var i = 0; i < 5; i++) {
      await store.load();
      await store.loadIfChanged();
    }
    final full = Stopwatch();
    final unchanged = Stopwatch();
    for (var i = 0; i < 20; i++) {
      full.start();
      await store.load();
      full.stop();
      unchanged.start();
      expect(await store.loadIfChanged(), isNull);
      unchanged.stop();
    }
    // Medición informativa: no exige tiempos concretos en equipos distintos.
    // ignore: avoid_print
    print('20 lecturas: ${full.elapsedMilliseconds} ms; '
        '20 consultas sin cambios: ${unchanged.elapsedMilliseconds} ms.');
  });
}
