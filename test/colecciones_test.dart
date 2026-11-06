import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';

void main() {
  final colecciones = Coleccion.desdeJson(
    File('assets/colecciones/colecciones.json').readAsStringSync(),
  );

  test('el catálogo tiene la saga Persona completa y sin repetidos', () {
    final persona = colecciones.singleWhere((c) => c.id == 'persona');

    expect(persona.grupos.map((grupo) => grupo.nombre),
        ['Saga principal', 'Spin-offs']);
    expect(persona.obras.map((obra) => obra.id).toSet(),
        hasLength(persona.obras.length));
    expect(persona.obras.map((obra) => obra.title),
        containsAll(['Persona 3 Reload', 'Persona 5 Royal', 'Persona 6']));
  });

  test('cada obra llega lista para la Biblioteca y con portada real', () {
    for (final coleccion in colecciones) {
      for (final obra in coleccion.obras) {
        expect(File(obra.coverUrl!).existsSync(), isTrue, reason: obra.title);
        expect(obra.status, LibraryItemStatus.pending);
        expect(obra.note, isNotEmpty, reason: obra.title);
        expect(obra.genre, isNotEmpty, reason: obra.title);
      }
    }
  });

  test('cada colección tiene obras únicas', () {
    expect(colecciones.map((coleccion) => coleccion.id).toSet(),
        hasLength(colecciones.length));
    for (final coleccion in colecciones) {
      expect(coleccion.obras.map((obra) => obra.id).toSet(),
          hasLength(coleccion.obras.length),
          reason: coleccion.nombre);
    }
  });

  test('las obras quitadas se guardan y se pueden recuperar', () {
    final controller = TodoWorkspace.createForTest();

    controller.setCollectionWorkHidden('persona/persona-3', true);
    final copia = AppVisibilitySettings.fromJson(
      controller.visibilitySettings.toJson(),
    );
    expect(copia.hiddenCollectionWorks, ['persona/persona-3']);

    controller.setSectionVisible(AppSection.recipes, false);
    expect(controller.visibilitySettings.hiddenCollectionWorks,
        ['persona/persona-3'],
        reason: 'ocultar una sección no debe perder las obras quitadas');

    controller.setCollectionWorkHidden('persona/persona-3', false);
    expect(controller.visibilitySettings.hiddenCollectionWorks, isEmpty);
  });
}
