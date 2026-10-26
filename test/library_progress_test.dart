import 'package:flutter_test/flutter_test.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';

LibraryItem _serie({int? actual, int? total, int? temporada}) => LibraryItem(
  id: 'serie-1',
  type: LibraryItemType.movieSeries,
  mediaType: LibraryMediaType.series,
  title: 'Una serie',
  status: LibraryItemStatus.inProgress,
  progressCurrent: actual,
  progressTotal: total,
  progressSeason: temporada,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

void main() {
  test('el progreso manual se conserva en el JSON', () {
    final restaurado = LibraryItem.fromJson(
      _serie(actual: 3, total: 9, temporada: 1).toJson(),
    );

    expect(restaurado.progressCurrent, 3);
    expect(restaurado.progressTotal, 9);
    expect(restaurado.progressSeason, 1);
  });

  test('un snapshot antiguo sin progreso carga con valores nulos', () {
    final json = _serie(actual: 3, total: 9, temporada: 1).toJson()
      ..remove('progressCurrent')
      ..remove('progressTotal')
      ..remove('progressSeason');

    final restaurado = LibraryItem.fromJson(json);

    expect(restaurado.progressCurrent, isNull);
    expect(restaurado.progressTotal, isNull);
    expect(restaurado.progressSeason, isNull);
  });

  test('el texto del progreso distingue series y manga', () {
    expect(
      textoProgresoManual(_serie(actual: 3, total: 9, temporada: 1)),
      'T1 · 3 / 9 episodios',
    );
    expect(textoProgresoManual(_serie(actual: 3)), '3 episodios');
    // En curso sin dato cuenta como el primero; pendiente sin dato, nada.
    expect(textoProgresoManual(_serie()), '1 episodio');
    expect(
        textoProgresoManual(_serie().copyWith(status: LibraryItemStatus.pending)),
        isNull);
    final manga = LibraryItem(
      id: 'manga-1',
      type: LibraryItemType.book,
      title: 'Un manga',
      creatorOrDirector: 'Manga',
      status: LibraryItemStatus.inProgress,
      progressCurrent: 24,
      progressTotal: 86,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );
    expect(textoProgresoManual(manga), '24 / 86 capítulos');
    expect(fraccionProgresoManual(manga), closeTo(24 / 86, 1e-9));
  });

  test('una película o un libro corriente no admiten progreso manual', () {
    final pelicula = LibraryItem(
      id: 'peli',
      type: LibraryItemType.movieSeries,
      mediaType: LibraryMediaType.movie,
      title: 'Peli',
      progressCurrent: 1,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );
    expect(admiteProgresoManual(pelicula), isFalse);
    expect(textoProgresoManual(pelicula), isNull);
    expect(conUnaUnidadMasDeProgreso(pelicula).progressCurrent, 1);
  });

  test('marcar una unidad suma uno y no pasa del total', () {
    var item = _serie(actual: 7, total: 9);
    item = conUnaUnidadMasDeProgreso(item);
    expect(item.progressCurrent, 8);
    item = conUnaUnidadMasDeProgreso(item);
    expect(item.progressCurrent, 9);
    item = conUnaUnidadMasDeProgreso(item);
    expect(item.progressCurrent, 9);
    expect(conUnaUnidadMasDeProgreso(_serie()).progressCurrent, 2);
    final pendiente = _serie(total: 12).copyWith(status: LibraryItemStatus.pending);
    expect(conUnaUnidadMasDeProgreso(pendiente).progressCurrent, 1);
    expect(pendiente.status, LibraryItemStatus.pending);
  });

  test('el workspace marca la unidad, no completa y permite deshacer', () {
    final controller = TodoWorkspace.createForTest();
    final creada = controller.createLibraryItem(
      type: LibraryItemType.movieSeries,
      title: 'Anime de prueba',
      mediaType: LibraryMediaType.series,
      status: LibraryItemStatus.inProgress,
      progressCurrent: 8,
      progressTotal: 9,
      progressSeason: 1,
    );

    final resultado = controller.marcarUnidadDeProgreso(creada.id)!;

    expect(resultado.anterior.progressCurrent, 8);
    expect(resultado.nuevo.progressCurrent, 9);
    expect(resultado.nuevo.status, LibraryItemStatus.inProgress);

    controller.updateLibraryItem(resultado.anterior);
    expect(
      controller.libraryItems
          .firstWhere((i) => i.id == creada.id)
          .progressCurrent,
      8,
    );
    expect(controller.marcarUnidadDeProgreso('no-existe'), isNull);
  });
}
