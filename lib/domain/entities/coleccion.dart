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
    required this.alias,
    required this.grupos,
    this.fechasPrevistas = const {},
  });

  /// Fecha prevista de salida de las obras que aún no han salido, por su id.
  /// Una cadena vacía indica que todavía no hay fecha.
  final Map<String, String> fechasPrevistas;

  final String id;
  final String nombre;

  /// Otros nombres de saga o universo que abren esta colección.
  final List<String> alias;
  final List<GrupoColeccion> grupos;

  List<String> get nombres => [nombre, ...alias];

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
          'collectionName': campos['collectionName'] ?? nombre,
          'showCollectionNumber': campos['collectionNumber'] != null,
        });
    final grupos = (datos['grupos'] as List).cast<Map<String, dynamic>>();
    return Coleccion(
      id: datos['id'] as String,
      nombre: nombre,
      alias: (datos['alias'] as List? ?? const []).cast<String>(),
      fechasPrevistas: {
        for (final grupo in grupos)
          for (final campos
              in (grupo['obras'] as List).cast<Map<String, dynamic>>())
            if (campos['fechaPrevista'] is String)
              campos['id'] as String: campos['fechaPrevista'] as String,
      },
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
