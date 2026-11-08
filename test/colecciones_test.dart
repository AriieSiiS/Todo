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

  test('las fichas se enlazan con su obra del catálogo por identificador', () {
    final dune = colecciones.singleWhere((c) => c.id == 'dune');
    final pelicula = dune.obras.singleWhere((o) => o.id == 'dune-2021');
    expect(pelicula.catalogKeys, ['dune/dune-2021']);

    final controller = TodoWorkspace.createForTest();
    final item = controller.createLibraryItem(
      type: LibraryItemType.movieSeries,
      title: 'Mi Dune',
      status: LibraryItemStatus.pending,
    );
    final antes = controller.libraryItems.single.updatedAt;
    controller.linkLibraryItemsToCatalog({
      item.id: ['dune/dune-2021'],
    });
    final enlazado = controller.libraryItems.single;
    expect(enlazado.catalogKeys, ['dune/dune-2021']);
    expect(enlazado.updatedAt, antes,
        reason: 'enlazar no debe cambiar el orden de Recientes');
    expect(
      LibraryItem.fromJson(enlazado.toJson()).catalogKeys,
      ['dune/dune-2021'],
    );
  });

  test('los cambios propios de una obra del catálogo se guardan', () {
    final controller = TodoWorkspace.createForTest();
    controller.setCollectionWorkEdit('souls/demons-souls', {'title': 'Otro'});
    final copia = AppVisibilitySettings.fromJson(
      controller.visibilitySettings.toJson(),
    );
    expect(copia.collectionWorkEdits['souls/demons-souls'], {'title': 'Otro'});
    controller.setCollectionWorkHidden('persona/persona-3', true);
    expect(controller.visibilitySettings.collectionWorkEdits, isNotEmpty,
        reason: 'quitar una obra no debe perder los cambios propios');
  });

  test('al disolver una colección sus fichas pierden la saga', () {
    final controller = TodoWorkspace.createForTest();
    controller.createLibraryItem(
      type: LibraryItemType.movieSeries,
      title: 'Sinister',
      status: LibraryItemStatus.completed,
      collectionName: 'Sinister',
      collectionNumber: 1,
      showCollectionNumber: true,
    );
    controller.createLibraryItem(
      type: LibraryItemType.game,
      title: 'Dark Souls III',
      collectionName: 'Dark Souls',
      universeName: 'Souls',
    );
    final antes = controller.libraryItems.first.updatedAt;
    controller.dissolveLibraryCollections(['Sinister']);
    final sinister =
        controller.libraryItems.singleWhere((i) => i.title == 'Sinister');
    expect(sinister.collectionName, isNull);
    expect(sinister.collectionNumber, isNull);
    expect(sinister.updatedAt, antes);
    final souls =
        controller.libraryItems.singleWhere((i) => i.title == 'Dark Souls III');
    expect(souls.collectionName, 'Dark Souls');
    expect(souls.universeName, 'Souls');
  });

  test('Warhammer 40.000 incluye La Herejía de Horus y Eisenhorn sin copiarlas', () {
    final warhammer = colecciones.singleWhere((c) => c.id == 'warhammer-40000');
    final herejia = colecciones.singleWhere((c) => c.id == 'la-herejia-de-horus');
    final eisenhorn = colecciones.singleWhere((c) => c.id == 'eisenhorn');
    for (final obra in [...herejia.obras, ...eisenhorn.obras]) {
      expect(warhammer.obras.any((o) => identical(o, obra)), isTrue,
          reason: obra.title);
    }
    expect(warhammer.grupos.map((g) => g.nombre),
        containsAll(['La Herejía de Horus', 'Inquisidor Eisenhorn', 'Juegos']));
    final horus = warhammer.obras.firstWhere((o) => o.title.startsWith('Horus'));
    expect(horus.catalogKeys.single, startsWith('la-herejia-de-horus/'));
  });
}
