import 'package:flutter_test/flutter_test.dart';
import 'package:todo/domain/models.dart';

void main() {
  test('el club de lectura se guarda y se recupera del snapshot', () {
    final ajustes = AppVisibilitySettings(
      hiddenSections: const ['plants'],
      readingClubVisible: false,
      readingClubMeetings: [
        ReadingClubMeeting(
          id: 'club-1',
          bookId: 'library-1',
          club: 'Novela negra',
          date: DateTime(2027, 3, 11),
          pendingConfirmation: true,
        ),
      ],
    );

    final json = ajustes.toJson();
    expect(json['readingClubMeetings'], [
      {
        'id': 'club-1',
        'bookId': 'library-1',
        'club': 'Novela negra',
        'date': '2027-03-11',
        'pendingConfirmation': true,
      }
    ]);

    final leidos = AppVisibilitySettings.fromJson(json);
    expect(leidos.readingClubVisible, isFalse);
    expect(leidos.hiddenSections, ['plants']);
    final sesion = leidos.readingClubMeetings.single;
    expect(sesion.club, 'Novela negra');
    expect(sesion.date, DateTime(2027, 3, 11));
    expect(sesion.pendingConfirmation, isTrue);
  });

  test('sin datos el club se muestra y no tiene sesiones', () {
    final ajustes = AppVisibilitySettings.fromJson(const {});
    expect(ajustes.readingClubVisible, isTrue);
    expect(ajustes.readingClubMeetings, isEmpty);
    expect(ajustes.toJson().containsKey('readingClubMeetings'), isFalse);
  });

  test('los libros del club guardan su ficha aparte de Biblioteca', () {
    final ficha = LibraryItem(
      id: 'club-libro-1',
      type: LibraryItemType.book,
      title: 'Aprendiz de asesino',
      status: LibraryItemStatus.pending,
      author: 'Robin Hobb',
      createdAt: DateTime(2026, 11, 9),
      updatedAt: DateTime(2026, 11, 9),
    ).toJson();
    final sesion = ReadingClubMeeting(
      id: 'club-1',
      bookId: 'club-libro-1',
      club: 'Fantasía',
      date: DateTime(2027, 1, 28),
      book: ficha,
    );
    final leida = AppVisibilitySettings.fromJson(
            AppVisibilitySettings(readingClubMeetings: [sesion]).toJson())
        .readingClubMeetings
        .single;
    final libro = LibraryItem.fromJson(leida.book!);
    expect(libro.title, 'Aprendiz de asesino');
    expect(libro.author, 'Robin Hobb');
    expect(leida.copyWith(bookId: 'library-2').book, isNotNull);
  });

  test('copyWith conserva el club al cambiar otras preferencias', () {
    final ajustes = AppVisibilitySettings(readingClubMeetings: [
      ReadingClubMeeting(
        id: 'club-1',
        bookId: 'library-1',
        club: 'Fantasía',
        date: DateTime(2027, 1, 28),
      ),
    ]);
    final cambiados = ajustes.copyWith(hiddenSections: const ['journal']);
    expect(cambiados.readingClubMeetings, hasLength(1));
  });
}
