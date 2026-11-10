import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/application/wrapped/resumen_libros.dart';
import 'package:todo/application/wrapped/wrapped_modelo.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/wrapped/wrapped_libros.dart';
import 'package:todo/presentation/wrapped/wrapped_piezas.dart';
import 'package:todo/presentation/wrapped/wrapped_reproductor.dart';

int _hora(DateTime d) => d.millisecondsSinceEpoch ~/ 1000 ~/ 3600 * 3600;

LibraryItem _libro(
  String id, {
  String? titulo,
  LibraryItemStatus estado = LibraryItemStatus.completed,
  DateTime? terminado,
  String autor = 'Autora',
  String genero = 'Misterio, detectives',
  double? nota,
  String? paginas = '300 páginas',
  String? saga,
  int? numero,
  int? ano,
  String? formato,
  List<DateTime> lecturas = const [],
  List<Map<String, dynamic>> citas = const [],
}) =>
    LibraryItem(
      id: id,
      type: LibraryItemType.book,
      title: titulo ?? 'Libro $id',
      status: estado,
      completedDate: terminado,
      author: autor,
      genre: genero,
      rating: nota,
      pages: paginas,
      collectionName: saga,
      collectionNumber: numero,
      releaseYear: ano,
      format: formato,
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
      reading: lecturas.isEmpty && citas.isEmpty
          ? null
          : LibraryReading(
              progress: .5,
              observedAt: 1,
              page: '1',
              position: '',
              documents: const [],
              cursors: const {},
              quotes: citas,
              statistics: {
                'kindle:$id': BookReadingStatistics(
                    observedAt: 1,
                    pageUnit: 'page',
                    periods: [
                      for (final d in lecturas)
                        ReadingPeriod(start: _hora(d), seconds: 1800, pages: 20)
                    ]),
              },
            ),
    );

List<LibraryItem> _biblioteca() => [
      _libro('a',
          titulo: 'Cinco cerditos',
          terminado: DateTime(2026, 2, 10),
          nota: 4,
          saga: 'Poirot',
          numero: 1,
          ano: 1942,
          formato: 'Físico'),
      _libro('b',
          titulo: 'Muerte en el Nilo',
          terminado: DateTime(2026, 5, 3),
          nota: 5,
          saga: 'Poirot',
          numero: 2,
          ano: 1937,
          formato: 'eBook',
          lecturas: [
            for (var d = 1; d <= 5; d++) DateTime(2026, 5, d, 23),
            DateTime(2026, 5, 9, 22),
          ],
          citas: [
            {
              'id': 'c1',
              'text':
                  'Una cita con la longitud justa para ser la elegida del año.',
              'observed_at':
                  DateTime(2026, 5, 2).millisecondsSinceEpoch ~/ 1000,
              'note': 'me encanta',
            }
          ]),
      _libro('c',
          titulo: 'Diablo en la cocina',
          terminado: DateTime(2026, 8, 1),
          nota: 1,
          autor: 'Otro',
          genero: 'Romance',
          ano: 2025),
      _libro('d', titulo: 'Del año pasado', terminado: DateTime(2025, 6, 1)),
      _libro('e',
          titulo: 'Poirot tres',
          estado: LibraryItemStatus.pending,
          saga: 'Poirot',
          numero: 3),
    ];

void main() {
  group('ajustes del Wrapped', () {
    test('los ajustes del año se combinan con los generales', () {
      final ajustes = AjustesWrapped.desdeJson({
        'publicacion': {'mes': 12, 'dia': 30, 'hora': 9},
        'libros': {
          'paleta': 'oro',
          'ocultar': ['notas']
        },
        'libros-2026': {
          'portada': 'Circe',
          'ocultar': ['cita']
        },
        'desconocido': {'x': 1},
      });
      final a = ajustes.para(WrappedTipo.libros, 2026);
      expect(a.portada, 'Circe');
      expect(a.paleta, 'oro');
      expect(a.ocultar, containsAll(['notas', 'cita']));
      expect(ajustes.para(WrappedTipo.libros, 2027).portada, isNull);
      expect(ajustes.publicacion(2026), DateTime(2026, 12, 30, 9));
      final vuelta = AjustesWrapped.desdeJson(ajustes.toJson());
      expect(vuelta.para(WrappedTipo.libros, 2026).portada, 'Circe');
      expect(vuelta.toJson().containsKey('desconocido'), isFalse);
    });

    test('publicar en enero se refiere al año ya cerrado', () {
      final ajustes = AjustesWrapped.desdeJson({
        'publicacion': {'mes': 1, 'dia': 1, 'hora': 0}
      });
      expect(ajustes.publicacion(2026), DateTime(2027, 1, 1));
    });

    test('se avisa desde la fecha de publicación hasta que se ve', () {
      const ajustes = AjustesWrapped();
      bool conDatos(WrappedTipo t, int y) => y == 2026;
      List<WrappedListo> listos(DateTime ahora, EstadoWrapped e) =>
          wrappedsListos(
              ahora: ahora, ajustes: ajustes, estado: e, conDatos: conDatos);
      const vacio = EstadoWrapped();
      expect(listos(DateTime(2026, 12, 31, 9), vacio), isEmpty);
      expect(listos(DateTime(2026, 12, 31, 10), vacio),
          [const WrappedListo(WrappedTipo.libros, 2026)]);
      expect(listos(DateTime(2027, 1, 20), vacio), hasLength(1));
      expect(listos(DateTime(2027, 3, 1), vacio), isEmpty);
      final visto =
          vacio.marcarVisto(WrappedTipo.libros, 2026, DateTime(2027, 1, 2));
      expect(listos(DateTime(2027, 1, 3), visto), isEmpty);
      expect(
          wrappedsListos(
              ahora: DateTime(2026, 12, 31, 12),
              ajustes: const AjustesWrapped(automatico: false),
              estado: vacio,
              conDatos: conDatos),
          isEmpty);
    });

    test('el almacén guarda, conserva claves ajenas y lee el estado', () {
      final carpeta = Directory.systemTemp.createTempSync('wrapped');
      addTearDown(() => carpeta.deleteSync(recursive: true));
      final almacen = AlmacenWrapped(carpeta: carpeta);
      expect(almacen.leerAjustes().diaPublicacion, 31);
      expect(File(almacen.rutaAjustes).existsSync(), isTrue);
      File(almacen.rutaAjustes).writeAsStringSync(
          '{"nota": "a mano", "libros-2026": {"portada": "Circe"}}');
      final leidos = almacen.leerAjustes();
      almacen.guardarAjustes(leidos.conTipo(WrappedTipo.libros, 2026,
          const AjustesWrappedTipo(destacado: 'Rudin')));
      final texto = File(almacen.rutaAjustes).readAsStringSync();
      expect(texto, contains('"nota": "a mano"'));
      expect(texto, contains('Rudin'));
      expect(texto, isNot(contains('Circe')));
      almacen.guardarEstado(const EstadoWrapped()
          .marcarAvisado(WrappedTipo.libros, 2026, DateTime(2026, 12, 31)));
      expect(almacen.leerEstado().avisado(WrappedTipo.libros, 2026), isTrue);
    });
  });

  group('resumen de libros', () {
    test('calcula libros, Kindle, rachas, sagas y destacados', () {
      final r = ResumenLibros.calcular(biblioteca: _biblioteca(), year: 2026);
      expect(r.terminados.map((l) => l.id), ['a', 'b', 'c']);
      expect(r.terminadosAnterior, 1);
      expect(r.paginas, 900);
      expect(r.segundos, 6 * 1800);
      expect(r.paginasKindle, 120);
      expect(r.rachaMaxima, 5);
      expect(r.inicioRacha, DateTime(2026, 5, 1));
      expect(r.finRacha, DateTime(2026, 5, 5));
      expect(r.libroDelAno?.id, 'b');
      expect(r.portada?.id, 'b');
      expect(r.peorValorado?.id, 'c');
      expect(r.notaMedia, closeTo(10 / 3, .001));
      expect(r.autores.first.nombre, 'Autora');
      expect(r.autores.first.libros, hasLength(2));
      expect(r.autores.first.nuevo, isFalse);
      expect(r.generos.first.key, 'Misterio');
      expect(r.sagas.single.nombre, 'Poirot');
      expect(r.sagas.single.siguiente?.titulo, 'Poirot tres');
      expect(r.anoMasAntiguo, 1937);
      expect(r.anoMasReciente, 2025);
      expect(r.fisicos, 1);
      expect(r.digitales, 1);
      expect(r.citaDestacada?.nota, 'me encanta');
      expect(r.pendientes, 1);
      expect(r.libroMasRapido?.id, 'b');
      expect(r.diasLibroMasRapido, 3);
    });

    test('las variables eligen portada, destacado y excluyen libros', () {
      final r = ResumenLibros.calcular(
        biblioteca: _biblioteca(),
        year: 2026,
        ajustes: const AjustesWrappedTipo(
            portada: 'cinco cerditos',
            destacado: 'DIABLO EN LA COCINA',
            excluir: ['Muerte en el Nilo']),
      );
      expect(r.portada?.id, 'a');
      expect(r.libroDelAno?.id, 'c');
      expect(r.terminados.map((l) => l.id), ['a', 'c']);
      expect(r.hayKindle, isFalse);
    });

    test('un año sin nada no tiene datos', () {
      final r = ResumenLibros.calcular(biblioteca: _biblioteca(), year: 2020);
      expect(r.hayDatos, isFalse);
      expect(diapositivasLibros(r).single.id, 'inicio');
    });

    test('las diapositivas respetan las ocultas', () {
      final r = ResumenLibros.calcular(
          biblioteca: _biblioteca(),
          year: 2026,
          ajustes: const AjustesWrappedTipo(ocultar: ['kindle', 'resumen']));
      final ids = diapositivasLibros(r).map((d) => d.id).toList();
      expect(ids.first, 'inicio');
      expect(ids, isNot(contains('kindle')));
      expect(ids, isNot(contains('resumen')));
      expect(ids, contains('calendario'));
      for (final id in ids) {
        expect(diapositivasDeLibros.containsKey(id), isTrue, reason: id);
      }
    });
  });

  testWidgets('todas las diapositivas se dibujan sin desbordes',
      (tester) async {
    TipografiaWrapped.usarFuentesLocales = true;
    final r = ResumenLibros.calcular(biblioteca: _biblioteca(), year: 2026);
    final slides = diapositivasLibros(r);
    expect(slides.length, greaterThan(10));
    tester.view.physicalSize = const Size(anchoLienzo, altoLienzo);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final slide in slides) {
      for (final t in [0.0, .3, 1.0]) {
        await tester.pumpWidget(MaterialApp(
          home: Material(
            child: SizedBox(
              width: anchoLienzo,
              height: altoLienzo,
              child: Builder(builder: (c) => slide.construir(c, t)),
            ),
          ),
        ));
        expect(tester.takeException(), isNull, reason: '${slide.id} t=$t');
      }
    }
  });

  testWidgets('el reproductor avanza, pausa y se cierra', (tester) async {
    TipografiaWrapped.usarFuentesLocales = true;
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final r = ResumenLibros.calcular(biblioteca: _biblioteca(), year: 2026);
    final slides = diapositivasLibros(r);
    await tester.pumpWidget(MaterialApp(
      home: ReproductorWrapped(
        tipo: WrappedTipo.libros,
        year: 2026,
        diapositivas: slides,
        segundosPorDiapositiva: 3,
      ),
    ));
    await tester.pump();
    expect(wrappedReproduciendo.value, isTrue);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.byTooltip('Pausar'), findsOneWidget);
    await tester.tap(find.byTooltip('Pausar'));
    await tester.pump();
    expect(find.byTooltip('Reanudar'), findsOneWidget);
    expect(
        find.byTooltip('Descargar el vídeo entero con música'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(wrappedReproduciendo.value, isFalse);
  });
}
