import 'package:flutter_test/flutter_test.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';

void main() {
  test('la saga de una obra se conserva en el JSON', () {
    final item = LibraryItem(
      id: 'libro-carl-2',
      type: LibraryItemType.book,
      title: 'El juicio final de Carl',
      collectionName: 'Carl el mazmorrero',
      collectionNumber: 2,
      showCollectionNumber: true,
      createdAt: DateTime(2026, 9, 6),
      updatedAt: DateTime(2026, 9, 6),
    );

    final restored = LibraryItem.fromJson(item.toJson());

    expect(restored.collectionName, 'Carl el mazmorrero');
    expect(restored.collectionNumber, 2);
    expect(restored.showCollectionNumber, isTrue);
  });

  test('el workspace normaliza los datos de una saga', () {
    final controller = TodoWorkspace.createForTest();

    final item = controller.createLibraryItem(
      type: LibraryItemType.game,
      title: 'Segunda entrega',
      collectionName: '  Mi saga  ',
      collectionNumber: 2,
      showCollectionNumber: true,
    );

    expect(item.collectionName, 'Mi saga');
    expect(item.collectionNumber, 2);
    expect(item.showCollectionNumber, isTrue);
  });

  test('el universo cuelga de la saga y se conserva en el JSON', () {
    final controller = TodoWorkspace.createForTest();

    final item = controller.createLibraryItem(
      type: LibraryItemType.book,
      title: 'Horus Rising',
      universeName: '  Warhammer 40.000 ',
      collectionName: 'La Herejía de Horus',
      collectionNumber: 1,
    );
    final restored = LibraryItem.fromJson(item.toJson());

    expect(restored.universeName, 'Warhammer 40.000');
    expect(restored.collectionName, 'La Herejía de Horus');
    expect(restored.collectionNumber, 1);
    expect(
      LibraryItem.fromJson({...item.toJson()}..remove('universeName'))
          .universeName,
      isNull,
    );
  });

  test('guarda temporadas, rewatch y publicación de un manga', () {
    final item = LibraryItem(
      id: 'serie-manga',
      type: LibraryItemType.movieSeries,
      title: 'Serie en emisión',
      mediaType: LibraryMediaType.series,
      rewatchCount: 2,
      seasonCount: 2,
      nextSeasonConfirmed: true,
      createdAt: DateTime(2026, 9, 18),
      updatedAt: DateTime(2026, 9, 18),
    );
    final manga = LibraryItem(
      id: 'manga',
      type: LibraryItemType.book,
      title: 'Manga en curso',
      creatorOrDirector: 'Manga',
      publicationStatus: LibraryPublicationStatus.ongoing,
      createdAt: DateTime(2026, 9, 18),
      updatedAt: DateTime(2026, 9, 18),
    );

    final restoredItem = LibraryItem.fromJson(item.toJson());
    final restoredManga = LibraryItem.fromJson(manga.toJson());

    expect(restoredItem.rewatchCount, 2);
    expect(restoredItem.seasonCount, 2);
    expect(restoredItem.nextSeasonConfirmed, isTrue);
    expect(restoredManga.publicationStatus, LibraryPublicationStatus.ongoing);
  });
}
