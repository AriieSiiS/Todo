import 'package:flutter_test/flutter_test.dart';
import 'package:todo/domain/models.dart';

void main() {
  test('la categoría elegida en Biblioteca se conserva en el snapshot', () {
    final restored = AppStateSnapshot.fromJson(
        AppStateSnapshot.fromJson({'tasks': [], 'libraryTypeView': 'book'})
            .toJson());
    expect(restored.libraryTypeView, LibraryItemType.book);
    expect(AppStateSnapshot.fromJson({'tasks': []}).libraryTypeView, isNull);
  });
}
