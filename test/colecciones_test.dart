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

  test('los tomos leídos de un manga se guardan en su ficha', () {
    final item = LibraryItem.fromJson({
      'id': 'manga',
      'type': 'book',
      'title': 'Dig It',
      'readVolumes': [1, 2],
      'currentVolume': 3,
    });
    expect(item.readVolumes, [1, 2]);
    expect(item.currentVolume, 3);
    final otra = LibraryItem.fromJson(item.toJson());
    expect(otra.readVolumes, [1, 2]);
    expect(otra.currentVolume, 3);
    final sinLeer = item.copyWith(readVolumes: [], clearCurrentVolume: true);
    expect(sinLeer.toJson().containsKey('readVolumes'), isFalse);
    expect(sinLeer.currentVolume, isNull);
  });

  test('los tomos de un manga pertenecen a su serie', () {
    final gachiakuta = colecciones.singleWhere((c) => c.id == 'gachiakuta');
    final tomos = gachiakuta.grupos.first.obras;
    expect(tomos, hasLength(16));
    expect(tomos.every((t) => t.collectionName == 'Gachiakuta'), isTrue);
    expect(tomos.map((t) => t.collectionNumber), [for (var i = 1; i <= 16; i++) i]);
  });
}
