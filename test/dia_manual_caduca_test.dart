import 'package:flutter_test/flutter_test.dart';
import 'package:todo_core/domain/settings.dart';
import 'package:todo_core/task_agenda.dart';

TaskAgenda _agenda(DateTime ahora) => TaskAgenda(
      tasks: const [],
      daySettings:
          const DaySettings(dayEndsAtHour: 3, nextDayVisibleAtHour: 10),
      now: ahora,
      manualDate: DateTime(2026, 10, 30),
      manualStartedAt: DateTime(2026, 10, 30, 2, 5),
    );

void main() {
  test('el día manual fijado de madrugada caduca al cambiar el día real', () {
    // A las 02:05 del 30 el día lógico aún es el 29 y se adelantó al 30.
    expect(_agenda(DateTime(2026, 10, 30, 2, 30)).logicalDate(),
        DateTime(2026, 10, 30));
    // Pasadas las 03:00 el día real ya es el 30: el día manual deja de valer.
    expect(_agenda(DateTime(2026, 10, 30, 12)).logicalDate(),
        DateTime(2026, 10, 30));
    // Días después no debe reactivarse y dejar el calendario atascado.
    expect(_agenda(DateTime(2026, 10, 31, 12)).logicalDate(),
        DateTime(2026, 10, 31));
    expect(_agenda(DateTime(2026, 11, 9, 23, 30)).logicalDate(),
        DateTime(2026, 11, 9));
    expect(_agenda(DateTime(2026, 11, 10, 1)).logicalDate(),
        DateTime(2026, 11, 9));
  });
}
