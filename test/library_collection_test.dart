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
}
