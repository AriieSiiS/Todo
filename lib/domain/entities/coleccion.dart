import 'dart:convert';

import 'library_item.dart';

/// Parte de una saga, como «Saga principal» o «Spin-offs».
class GrupoColeccion {
  const GrupoColeccion({required this.nombre, required this.obras});

  final String nombre;
  final List<LibraryItem> obras;
}

/// Saga del catálogo de Colecciones. Sus obras no pertenecen a la Biblioteca:
/// se describen con [LibraryItem] para reutilizar sus campos y sus fichas.
class Coleccion {
  const Coleccion({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.portadas,
    required this.grupos,
  });

  final String id;
  final String nombre;
  final String descripcion;
  final List<String> portadas;
  final List<GrupoColeccion> grupos;

  List<LibraryItem> get obras => [for (final grupo in grupos) ...grupo.obras];

  /// Lee el contenido de `assets/colecciones/colecciones.json`.
  static List<Coleccion> desdeJson(String texto) {
    final datos = jsonDecode(texto) as Map<String, dynamic>;
    return (datos['colecciones'] as List)
        .cast<Map<String, dynamic>>()
        .map(_coleccion)
        .toList();
  }

  static Coleccion _coleccion(Map<String, dynamic> datos) {
    final nombre = datos['nombre'] as String;
    LibraryItem obra(Map<String, dynamic> campos) => LibraryItem.fromJson({
          ...campos,
          'status': 'pending',
          'universeName': datos['universo'],
          'collectionName': nombre,
          'showCollectionNumber': campos['collectionNumber'] != null,
        });
    return Coleccion(
      id: datos['id'] as String,
      nombre: nombre,
      descripcion: datos['descripcion'] as String,
      portadas: (datos['portadas'] as List).cast<String>(),
      grupos: [
        for (final grupo
            in (datos['grupos'] as List).cast<Map<String, dynamic>>())
          GrupoColeccion(
            nombre: grupo['nombre'] as String,
            obras: (grupo['obras'] as List)
                .cast<Map<String, dynamic>>()
                .map(obra)
                .toList(),
          ),
      ],
    );
  }
}
