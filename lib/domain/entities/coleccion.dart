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
    this.fondo,
  });

  /// Imagen apaisada de la saga para el fondo de su vista, si la tiene.
  final String? fondo;

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
  ///
  /// Cada obra existe una sola vez. Una colección puede mostrar obras de otra
  /// sin copiarlas: con `{"ref": "coleccion/obra"}` dentro de un apartado, o
  /// incluyendo colecciones enteras. Un universo incluye todas las colecciones
  /// cuyo `universo` es su nombre (Agatha Christie incluye Hércules Poirot), y
  /// también las que indique `incluye`. Las colecciones incluidas siguen
  /// existiendo por separado.
  static List<Coleccion> desdeJson(String texto) {
    final datos = jsonDecode(texto) as Map<String, dynamic>;
    final crudas = (datos['colecciones'] as List).cast<Map<String, dynamic>>();
    // 1. Obras propias de cada colección, una instancia por obra.
    final obras = <String, LibraryItem>{};
    for (final campos in crudas) {
      for (final grupo in (campos['grupos'] as List).cast<Map>()) {
        for (final entrada in (grupo['obras'] as List).cast<Map>()) {
          if (entrada['ref'] != null) continue;
          final obra = _obra(campos, entrada.cast<String, dynamic>());
          obras[obra.catalogKeys.single] = obra;
        }
      }
    }
    // 2. Colecciones con sus apartados; las referencias usan esas instancias.
    final propias = {
      for (final campos in crudas)
        campos['id'] as String: _coleccion(campos, obras),
    };
    // 3. Universos y colecciones incluidas.
    String clave(String? nombre) => (nombre ?? '').trim().toLowerCase();
    final universoDe = {
      for (final campos in crudas)
        campos['id'] as String: clave(campos['universo'] as String?),
    };
    final incluyeDe = {
      for (final campos in crudas)
        campos['id'] as String:
            (campos['incluye'] as List? ?? const []).cast<String>(),
    };
    List<String> incluidas(String id) {
      final nombres = propias[id]!.nombres.map(clave).toSet();
      return [
        ...incluyeDe[id]!.where(propias.containsKey),
        for (final otra in propias.keys)
          if (otra != id &&
              !incluyeDe[id]!.contains(otra) &&
              nombres.contains(universoDe[otra]))
            otra,
      ];
    }

    Coleccion completa(String id, Set<String> visitadas) {
      final base = propias[id]!;
      final hijas = [
        for (final otra in incluidas(id))
          if (!visitadas.contains(otra)) completa(otra, {...visitadas, id}),
      ];
      return _conIncluidas(base, hijas);
    }

    return [for (final campos in crudas) completa(campos['id'] as String, {})];
  }

  /// Añade los apartados de [otras] tras los propios, sin repetir obras que
  /// ya estén en la colección.
  static Coleccion _conIncluidas(Coleccion coleccion, List<Coleccion> otras) {
    if (otras.isEmpty) return coleccion;
    final vistas = Set<LibraryItem>.identity()..addAll(coleccion.obras);
    final grupos = [...coleccion.grupos];
    for (final otra in otras) {
      for (final grupo in otra.grupos) {
        final nuevas = [
          for (final obra in grupo.obras)
            if (vistas.add(obra)) obra,
        ];
        if (nuevas.isEmpty) continue;
        // El apartado lleva delante el nombre de su colección, salvo que ya
        // lo contenga: «Hércules Poirot · Relatos», «Inquisidor Eisenhorn».
        final propio =
            grupo.nombre.toLowerCase().contains(otra.nombre.toLowerCase()) ||
                otra.nombre.toLowerCase().contains(grupo.nombre.toLowerCase());
        grupos.add(GrupoColeccion(
          nombre: propio ? grupo.nombre : '${otra.nombre} · ${grupo.nombre}',
          obras: nuevas,
        ));
      }
    }
    return Coleccion(
      id: coleccion.id,
      nombre: coleccion.nombre,
      alias: coleccion.alias,
      fondo: coleccion.fondo,
      fechasPrevistas: {
        for (final otra in otras) ...otra.fechasPrevistas,
        ...coleccion.fechasPrevistas,
      },
      grupos: grupos,
    );
  }

  static LibraryItem _obra(
    Map<String, dynamic> datos,
    Map<String, dynamic> campos,
  ) =>
      LibraryItem.fromJson({
        ...campos,
        'status': 'pending',
        'universeName': datos['universo'],
        'collectionName': campos['collectionName'] ?? datos['nombre'],
        'showCollectionNumber': campos['collectionNumber'] != null,
        'catalogKeys': ['${datos['id']}/${campos['id']}'],
      });

  static Coleccion _coleccion(
    Map<String, dynamic> datos,
    Map<String, LibraryItem> obras,
  ) {
    final grupos = (datos['grupos'] as List).cast<Map<String, dynamic>>();
    return Coleccion(
      id: datos['id'] as String,
      nombre: datos['nombre'] as String,
      alias: (datos['alias'] as List? ?? const []).cast<String>(),
      fondo: datos['fondo'] as String?,
      fechasPrevistas: {
        for (final grupo in grupos)
          for (final campos
              in (grupo['obras'] as List).cast<Map<String, dynamic>>())
            if (campos['fechaPrevista'] is String)
              campos['id'] as String: campos['fechaPrevista'] as String,
      },
      grupos: [
        for (final grupo in grupos)
          GrupoColeccion(
            nombre: grupo['nombre'] as String,
            obras: [
              for (final entrada
                  in (grupo['obras'] as List).cast<Map<String, dynamic>>())
                if (entrada['ref'] == null)
                  obras['${datos['id']}/${entrada['id']}']!
                else if (obras[entrada['ref']] != null)
                  obras[entrada['ref']]!,
            ],
          ),
      ],
    );
  }
}
