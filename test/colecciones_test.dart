import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
      for (final portada in coleccion.portadas) {
        expect(File(portada).existsSync(), isTrue, reason: portada);
      }
      for (final obra in coleccion.obras) {
        expect(File(obra.coverUrl!).existsSync(), isTrue, reason: obra.title);
        expect(obra.status, LibraryItemStatus.pending);
        expect(obra.collectionName, coleccion.nombre);
        expect(obra.note, isNotEmpty, reason: obra.title);
        expect(obra.genre, isNotEmpty, reason: obra.title);
        expect(obra.developer, isNotEmpty, reason: obra.title);
        expect(obra.platform, isNotEmpty, reason: obra.title);
      }
    }
  });
}
