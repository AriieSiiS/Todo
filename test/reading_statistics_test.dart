import 'package:flutter_test/flutter_test.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shared/book_statistics_panel.dart';

void main() {
  int hour(DateTime date) => (date.millisecondsSinceEpoch ~/ 3600000) * 3600;
  BookReadingStatistics stats(int observed, List<ReadingPeriod> periods) =>
      BookReadingStatistics(observedAt: observed, periods: periods);
  test(
      'el resumen anual separa años, reúne días y respeta rachas sin horas ficticias',
      () {
    final summary = ReadingStatisticsSummary([
      stats(100, [
        ReadingPeriod(
            start: hour(DateTime(2025, 12, 31, 12)), seconds: 600, pages: 4),
        ReadingPeriod(
            start: hour(DateTime(2026, 1, 1, 12)), seconds: 120, pages: 2),
        ReadingPeriod(
            start: hour(DateTime(2026, 1, 1, 15)), seconds: 180, pages: 3),
        ReadingPeriod(
            start: hour(DateTime(2026, 1, 2, 12)), seconds: 60, pages: 1),
        ReadingPeriod(
            start: hour(DateTime(2026, 1, 4, 12)), seconds: 90, pages: 1),
      ])
    ], year: 2026);
    expect(summary.seconds, 450);
    expect(summary.pages, 7);
    expect(summary.days, 3);
    expect(summary.longestStreak, 2);
    expect(summary.monthlySeconds.first, 450);
    expect(ReadingStatisticsSummary([]).seconds, 0);
  });
  test(
      'el resumen global no duplica el mismo historial al unir fichas o dispositivos',
      () {
    final now = DateTime(2026);
    LibraryItem book(String id, int observed, int seconds) => LibraryItem(
          id: id,
          title: id,
          type: LibraryItemType.book,
          createdAt: now,
          updatedAt: now,
          reading: LibraryReading(
              progress: .1,
              observedAt: observed,
              page: '1',
              position: '',
              documents: [],
              cursors: {},
              quotes: [],
              statistics: {
                'historial:1': stats(observed,
                    [ReadingPeriod(start: 3600, seconds: seconds, pages: 1)])
              }),
        );
    final sources = combinedReadingStatistics(
        [book('primero', 100, 60), book('segundo', 200, 120)]);
    expect(sources.length, 1);
    expect(ReadingStatisticsSummary(sources.values).seconds, 120);
    final restored =
        LibraryReading.fromJson(book('primero', 100, 60).reading!.toJson());
    expect(restored.statistics.values.single.periods.single.seconds, 60);
  });
}
