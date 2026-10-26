/// Contadores horarios acumulados del historial de KOReader.
class ReadingPeriod {
  const ReadingPeriod(
      {required this.start, required this.seconds, required this.pages});
  final int start;
  final int seconds;
  final int pages;
  DateTime get localDate => DateTime.fromMillisecondsSinceEpoch(start * 1000);
  Map<String, dynamic> toJson() =>
      {'start': start, 'seconds': seconds, 'pages': pages};
  factory ReadingPeriod.fromJson(Map<String, dynamic> data) {
    final start = data['start'],
        seconds = data['seconds'],
        pages = data['pages'];
    if (start is! int ||
        start < 0 ||
        start % 3600 != 0 ||
        seconds is! int ||
        seconds < 0 ||
        seconds > 360000 ||
        pages is! int ||
        pages < 0 ||
        pages > 100000) {
      throw const FormatException(
          'El registro horario de lectura no es válido.');
    }
    return ReadingPeriod(start: start, seconds: seconds, pages: pages);
  }
}

class BookReadingStatistics {
  BookReadingStatistics(
      {required this.observedAt, required List<ReadingPeriod> periods})
      : periods = List.unmodifiable(periods);
  final int observedAt;
  final List<ReadingPeriod> periods;
  Map<String, dynamic> toJson() => {
        'observedAt': observedAt,
        'periods': periods.map((p) => p.toJson()).toList()
      };
  factory BookReadingStatistics.fromJson(Map<String, dynamic> data) {
    final raw = data['periods'];
    if (raw is! List || raw.length > 12000 || data['observedAt'] is! int) {
      throw const FormatException(
          'Las estadísticas de lectura no son válidas.');
    }
    final periods = <ReadingPeriod>[];
    final seen = <int>{};
    for (final item in raw) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('El registro de lectura no es válido.');
      }
      final period = ReadingPeriod.fromJson(item);
      if (!seen.add(period.start)) {
        throw const FormatException('Hay horas de lectura repetidas.');
      }
      periods.add(period);
    }
    periods.sort((a, b) => a.start.compareTo(b.start));
    return BookReadingStatistics(
        observedAt: data['observedAt'] as int, periods: periods);
  }
}

/// Resumen calculado, sin generar minutos para fichas sin historial de lectura.
class ReadingStatisticsSummary {
  ReadingStatisticsSummary(Iterable<BookReadingStatistics> sources,
      {int? year}) {
    for (final source in sources) {
      for (final period in source.periods) {
        if (period.seconds == 0) continue;
        final date = period.localDate;
        if (year != null && date.year != year) continue;
        seconds += period.seconds;
        pages += period.pages;
        final day = DateTime(date.year, date.month, date.day);
        dailySeconds.update(day, (v) => v + period.seconds,
            ifAbsent: () => period.seconds);
        monthlySeconds[date.month - 1] += period.seconds;
      }
    }
  }
  int seconds = 0;
  int pages = 0;
  final Map<DateTime, int> dailySeconds = {};
  final List<int> monthlySeconds = List.filled(12, 0);
  int get days => dailySeconds.length;
  int get longestStreak {
    final dates = dailySeconds.keys.toList()..sort();
    var longest = 0, current = 0;
    DateTime? previous;
    for (final date in dates) {
      current = previous != null &&
              DateTime(previous.year, previous.month, previous.day + 1) == date
          ? current + 1
          : 1;
      if (current > longest) longest = current;
      previous = date;
    }
    return longest;
  }
}
