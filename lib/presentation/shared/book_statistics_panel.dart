import 'package:flutter/material.dart';
import '../../domain/models.dart';

String _statisticsPageUnit(Iterable<BookReadingStatistics> sources) {
  final units = {
    for (final source in sources)
      if (source.periods.any((p) => p.pages > 0)) source.pageUnit
  };
  return units.length == 1 ? units.single : 'unknown';
}

String _statisticsPageTitle(String unit) => switch (unit) {
      'screen' => 'Pantallas leídas',
      'page' => 'Páginas leídas',
      _ => 'Posiciones registradas'
    };

String readingDuration(int seconds) {
  if (seconds == 0) return '0 min';
  if (seconds < 60) return '<1 min';
  final minutes = seconds ~/ 60;
  return minutes < 60
      ? '$minutes min'
      : '${minutes ~/ 60} h${minutes % 60 == 0 ? '' : ' ${minutes % 60} min'}';
}

Map<String, BookReadingStatistics> combinedReadingStatistics(
    Iterable<LibraryItem> books) {
  final result = <String, BookReadingStatistics>{};
  for (final book in books) {
    for (final entry in book.reading?.statistics.entries ??
        <MapEntry<String, BookReadingStatistics>>[]) {
      if (entry.value.observedAt >= (result[entry.key]?.observedAt ?? -1)) {
        result[entry.key] = entry.value;
      }
    }
  }
  return result;
}

class BookStatisticsPanel extends StatelessWidget {
  const BookStatisticsPanel({required this.reading, super.key});
  final LibraryReading? reading;
  @override
  Widget build(BuildContext context) {
    final summary = ReadingStatisticsSummary(reading?.statistics.values ?? []);
    final pageUnit = _statisticsPageUnit(reading?.statistics.values ?? []);
    final dates = summary.dailySeconds.keys.toList()..sort();
    final empty = dates.isEmpty;
    final dailyPages = <DateTime, int>{};
    final hourlySeconds = List.filled(24, 0);
    for (final source
        in reading?.statistics.values ?? <BookReadingStatistics>[]) {
      for (final period in source.periods) {
        if (period.seconds == 0) continue;
        final date = period.localDate;
        hourlySeconds[date.hour] += period.seconds;
        dailyPages.update(DateTime(date.year, date.month, date.day),
            (value) => value + period.pages,
            ifAbsent: () => period.pages);
      }
    }
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 380;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ReadingMetrics(values: [
          (
            'Tiempo leído',
            readingDuration(summary.seconds),
            Icons.schedule_rounded
          ),
          (
            _statisticsPageTitle(pageUnit),
            '${summary.pages}',
            Icons.auto_stories_outlined
          ),
          ('Días de lectura', '${summary.days}', Icons.calendar_today_outlined),
          (
            'Mejor racha',
            '${summary.longestStreak} ${summary.longestStreak == 1 ? 'día' : 'días'}',
            Icons.local_fire_department_outlined
          ),
        ]),
        SizedBox(height: compact ? 12 : 24),
        Expanded(
            child: _TemporaryReadingViews(
          pageUnit: pageUnit,
          dailySeconds: summary.dailySeconds,
          dailyPages: dailyPages,
          hourlySeconds: hourlySeconds,
          monthlySeconds: ReadingStatisticsSummary(
                  reading?.statistics.values ?? [],
                  year: empty ? DateTime.now().year : dates.last.year)
              .monthlySeconds,
          year: empty ? DateTime.now().year : dates.last.year,
        )),
        SizedBox(height: compact ? 10 : 20),
        Wrap(spacing: 28, runSpacing: 8, children: [
          _ReadingNote(
              'Ritmo medio',
              summary.pages == 0
                  ? '—'
                  : '${(summary.seconds / summary.pages).round()} s / ${readingPageUnitLabel(pageUnit)}'),
          _ReadingNote(
              'Media por día de lectura',
              empty
                  ? '—'
                  : readingDuration((summary.seconds / summary.days).round())),
          _ReadingNote(
              'Primera lectura', empty ? '—' : _readingDate(dates.first)),
          _ReadingNote(
              'Última lectura', empty ? '—' : _readingDate(dates.last)),
        ]),
      ]);
    });
  }
}

String _readingDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

class AnnualReadingStatisticsDialog extends StatefulWidget {
  const AnnualReadingStatisticsDialog(
      {required this.books,
      this.goals = const [],
      this.coverBuilder,
      super.key});
  final List<LibraryItem> books;
  final List<LibraryGoal> goals;
  final Widget Function(LibraryItem book)? coverBuilder;
  @override
  State<AnnualReadingStatisticsDialog> createState() =>
      _AnnualReadingStatisticsDialogState();
}

const _readingWeekdays = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo'
];

class _AnnualReadingStatisticsDialogState
    extends State<AnnualReadingStatisticsDialog> {
  int _year = DateTime.now().year;
  int _tab = 0;
  bool _calendar = false;

  ({String label, bool up})? _compare(num current, num previous) {
    if (previous <= 0) return null;
    final change = ((current - previous) / previous * 100).round();
    return (
      label: '${change >= 0 ? '+' : ''}$change % que en ${_year - 1}',
      up: change >= 0
    );
  }

  @override
  Widget build(BuildContext context) {
    final books =
        widget.books.where((b) => b.type == LibraryItemType.book).toList();
    final sources = combinedReadingStatistics(books);
    final pageUnit = _statisticsPageUnit(sources.values);
    final summary = ReadingStatisticsSummary(sources.values, year: _year);
    final previous = ReadingStatisticsSummary(sources.values, year: _year - 1);
    final years = <int>{
      DateTime.now().year,
      for (final source in sources.values)
        for (final p in source.periods) p.localDate.year,
      for (final book in books)
        if (book.completedDate != null) book.completedDate!.year,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    List<LibraryItem> finishedIn(int year) => books
        .where((b) =>
            b.status == LibraryItemStatus.completed &&
            b.completedDate?.year == year)
        .toList()
      ..sort((a, b) => a.completedDate!.compareTo(b.completedDate!));
    final finished = finishedIn(_year);
    final ranking = [
      for (final book in books)
        (
          book: book,
          stats: ReadingStatisticsSummary(book.reading?.statistics.values ?? [],
              year: _year)
        )
    ]..sort((a, b) => b.stats.seconds.compareTo(a.stats.seconds));
    final active = ranking.where((entry) => entry.stats.seconds > 0).toList();
    final dailyPages = <DateTime, int>{};
    final hourly = List.filled(24, 0), weekdays = List.filled(7, 0);
    for (final source in sources.values) {
      for (final period in source.periods) {
        final date = period.localDate;
        if (period.seconds == 0 || date.year != _year) continue;
        hourly[date.hour] += period.seconds;
        weekdays[date.weekday - 1] += period.seconds;
        dailyPages.update(DateTime(date.year, date.month, date.day),
            (value) => value + period.pages,
            ifAbsent: () => period.pages);
      }
    }
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 24, 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.insights_rounded,
                  color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                  child: Text('Tu año de lectura',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800))),
              SizedBox(
                  width: 92,
                  child: PopupMenuButton<int>(
                    tooltip: 'Elegir año',
                    onSelected: (value) => setState(() => _year = value),
                    initialValue: _year,
                    itemBuilder: (_) => [
                      for (final year in years)
                        PopupMenuItem(value: year, child: Text('$year'))
                    ],
                    child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(children: [
                          Expanded(
                              child: Text('$_year',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700))),
                          const Icon(Icons.expand_more_rounded, size: 20)
                        ])),
                  )),
              IconButton(
                  tooltip: 'Cerrar estadísticas',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 18),
            _ReadingMetrics(values: [
              (
                'Tiempo leído',
                readingDuration(summary.seconds),
                Icons.schedule_rounded
              ),
              (
                'Días de lectura',
                '${summary.days}',
                Icons.calendar_today_outlined
              ),
              (
                _statisticsPageTitle(pageUnit),
                '${summary.pages}',
                Icons.auto_stories_outlined
              ),
              (
                'Libros terminados',
                '${finished.length}',
                Icons.task_alt_rounded
              ),
            ], comparisons: [
              _compare(summary.seconds, previous.seconds),
              _compare(summary.days, previous.days),
              _compare(summary.pages, previous.pages),
              _compare(finished.length, finishedIn(_year - 1).length),
            ]),
            const SizedBox(height: 14),
            _ReadingGoalProgress(
                year: _year,
                goals: widget.goals
                    .where((g) =>
                        g.type == LibraryItemType.book && g.targetYear == _year)
                    .toList()),
            const SizedBox(height: 16),
            Row(children: [
              _MiniTabs(
                  names: const ['Actividad', 'Estantería', 'Récords y hábitos'],
                  selected: _tab,
                  onSelected: (index) => setState(() => _tab = index)),
              const Spacer(),
              if (_tab == 0)
                _MiniTabs(
                    names: const ['Mes a mes', 'Calendario'],
                    selected: _calendar ? 1 : 0,
                    onSelected: (index) =>
                        setState(() => _calendar = index == 1)),
            ]),
            const SizedBox(height: 14),
            Expanded(
                child: switch (_tab) {
              1 => _ReadingShelf(
                  finished: finished,
                  active: active,
                  coverBuilder: widget.coverBuilder),
              2 => _ReadingRecords(
                  pageUnit: pageUnit,
                  summary: summary,
                  finished: finished,
                  hourly: hourly,
                  weekdays: weekdays),
              _ => _calendar
                  ? _ReadingHeatmap(
                      pageUnit: pageUnit,
                      dailySeconds: summary.dailySeconds,
                      dailyPages: dailyPages,
                      from: DateTime(_year),
                      to: DateTime(_year, 12, 31),
                      title: null)
                  : _ReadingMonthlyChart(
                      values: summary.monthlySeconds, title: 'Mes a mes'),
            }),
          ]),
        ),
      ),
    );
  }
}

class _MiniTabs extends StatelessWidget {
  const _MiniTabs(
      {required this.names, required this.selected, required this.onSelected});
  final List<String> names;
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: colors.onSurface.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(9)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < names.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: () => onSelected(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: i == selected ? colors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(7)),
              child: Text(names[i],
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          i == selected ? FontWeight.w700 : FontWeight.w500,
                      color: i == selected
                          ? colors.primary
                          : colors.onSurfaceVariant)),
            ),
          ),
      ]),
    );
  }
}

class _ReadingGoalProgress extends StatelessWidget {
  const _ReadingGoalProgress({required this.year, required this.goals});
  final int year;
  final List<LibraryGoal> goals;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final total = goals.length, done = goals.where((g) => g.isCompleted).length;
    final now = DateTime.now();
    String status;
    if (total == 0) {
      status = 'Sin propósito de libros para $year';
    } else if (done >= total) {
      status = '¡Propósito cumplido!';
    } else if (year < now.year) {
      status = 'Faltaron ${total - done}';
    } else if (year > now.year) {
      status = 'Aún no ha empezado';
    } else {
      final elapsed = now.difference(DateTime(year)).inDays + 1;
      final days = DateTime(year + 1).difference(DateTime(year)).inDays;
      final expected = total * elapsed / days;
      final gap = (expected - done).ceil();
      status = done >= expected.floor()
          ? 'Vas a buen ritmo'
          : 'Vas $gap ${gap == 1 ? 'libro' : 'libros'} por detrás';
    }
    return Row(children: [
      Icon(Icons.flag_outlined, size: 18, color: colors.primary),
      const SizedBox(width: 8),
      Text(
          total == 0
              ? 'Propósito'
              : 'Propósito: $done de $total ${total == 1 ? 'libro' : 'libros'}',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(width: 14),
      Expanded(
          child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  minHeight: 8,
                  value: total == 0 ? 0 : (done / total).clamp(0, 1),
                  backgroundColor: colors.onSurface.withValues(alpha: .07)))),
      const SizedBox(width: 14),
      Text(status,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: colors.onSurfaceVariant)),
    ]);
  }
}

class _ReadingShelf extends StatelessWidget {
  const _ReadingShelf(
      {required this.finished, required this.active, this.coverBuilder});
  final List<LibraryItem> finished;
  final List<({LibraryItem book, ReadingStatisticsSummary stats})> active;
  final Widget Function(LibraryItem book)? coverBuilder;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final title =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
          flex: 3,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Terminados', style: title),
            const SizedBox(height: 10),
            Expanded(
                child: finished.isEmpty
                    ? const Center(
                        child: Text('Los libros que termines aparecerán aquí.'))
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 92,
                                childAspectRatio: 2 / 3,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10),
                        itemCount: finished.length,
                        itemBuilder: (context, index) {
                          final book = finished[index];
                          return Tooltip(
                            message:
                                '${book.title} · ${_readingDate(book.completedDate!)}',
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: coverBuilder?.call(book) ??
                                    ColoredBox(
                                        color: colors.primary
                                            .withValues(alpha: .10),
                                        child: Icon(Icons.menu_book_rounded,
                                            color: colors.primary))),
                          );
                        })),
          ])),
      const SizedBox(width: 24),
      Expanded(
          flex: 2,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Más tiempo dedicado', style: title),
            const SizedBox(height: 10),
            Expanded(
                child: active.isEmpty
                    ? const Center(
                        child: Text(
                            'Los tiempos de tus próximas lecturas aparecerán aquí.'))
                    : ListView.separated(
                        itemCount: active.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = active[index];
                          return Row(children: [
                            SizedBox(
                                width: 26,
                                child: Text('${index + 1}',
                                    style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w800))),
                            Expanded(
                                child: Text(entry.book.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                            const SizedBox(width: 12),
                            Text(readingDuration(entry.stats.seconds),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ]);
                        })),
          ])),
    ]);
  }
}

class _ReadingRecords extends StatelessWidget {
  const _ReadingRecords(
      {required this.summary,
      required this.pageUnit,
      required this.finished,
      required this.hourly,
      required this.weekdays});
  final ReadingStatisticsSummary summary;
  final String pageUnit;
  final List<LibraryItem> finished;
  final List<int> hourly, weekdays;

  int? _pages(LibraryItem book) {
    return bookPageTotal(book.pages, null, manual: true);
  }

  int? _daysToFinish(LibraryItem book) {
    final starts = [
      for (final source
          in book.reading?.statistics.values ?? <BookReadingStatistics>[])
        for (final period in source.periods)
          if (period.seconds > 0) period.localDate
    ];
    if (starts.isEmpty) return null;
    starts.sort();
    final first =
        DateTime(starts.first.year, starts.first.month, starts.first.day);
    final end = book.completedDate!;
    return DateTime(end.year, end.month, end.day).difference(first).inDays + 1;
  }

  int _maxIndex(List<int> values) {
    var best = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[best]) best = i;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    MapEntry<DateTime, int>? bestDay;
    for (final entry in summary.dailySeconds.entries) {
      if (bestDay == null || entry.value > bestDay.value) bestDay = entry;
    }
    ({LibraryItem book, int value})? best(int? Function(LibraryItem) score,
        {bool lowest = false}) {
      ({LibraryItem book, int value})? result;
      for (final book in finished) {
        final value = score(book);
        if (value == null) continue;
        if (result == null ||
            (lowest ? value < result.value : value > result.value)) {
          result = (book: book, value: value);
        }
      }
      return result;
    }

    final fastest = best(_daysToFinish, lowest: true);
    final longest = best(_pages);
    LibraryItem? favourite;
    for (final book in finished) {
      if (book.rating != null &&
          (favourite == null || book.rating! > favourite.rating!)) {
        favourite = book;
      }
    }
    final hasTime = summary.seconds > 0;
    final hour = _maxIndex(hourly), weekday = _maxIndex(weekdays);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Récords', style: title),
        const SizedBox(height: 12),
        _ReadingRecord(
            Icons.wb_sunny_outlined,
            'Día que más leíste',
            bestDay == null
                ? '—'
                : '${_readingDate(bestDay.key)} · ${readingDuration(bestDay.value)}'),
        _ReadingRecord(
            Icons.bolt_rounded,
            'Libro más rápido',
            fastest == null
                ? '—'
                : '${fastest.book.title} · ${fastest.value} ${fastest.value == 1 ? 'día' : 'días'}'),
        _ReadingRecord(
            Icons.menu_book_outlined,
            'Libro más largo',
            longest == null
                ? '—'
                : '${longest.book.title} · ${longest.value} páginas'),
        _ReadingRecord(
            Icons.star_outline_rounded,
            'Mejor valorado',
            favourite == null
                ? '—'
                : '${favourite.title} · ${favourite.rating!.toStringAsFixed(favourite.rating! % 1 == 0 ? 0 : 1).replaceAll('.', ',')} ★'),
        _ReadingRecord(Icons.local_fire_department_outlined, 'Mejor racha',
            '${summary.longestStreak} ${summary.longestStreak == 1 ? 'día' : 'días'}'),
      ])),
      const SizedBox(width: 28),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tus hábitos', style: title),
        const SizedBox(height: 12),
        _ReadingRecord(Icons.schedule_rounded, 'Hora favorita',
            hasTime ? '$hour:00 – ${hour + 1}:00' : '—'),
        _ReadingRecord(Icons.event_outlined, 'Día favorito',
            hasTime ? _readingWeekdays[weekday] : '—'),
        _ReadingRecord(
            Icons.timelapse_rounded,
            'Media por día de lectura',
            hasTime
                ? readingDuration((summary.seconds / summary.days).round())
                : '—'),
        _ReadingRecord(
            Icons.speed_rounded,
            'Ritmo medio',
            summary.pages == 0
                ? '—'
                : '${(summary.seconds / summary.pages).round()} s / ${readingPageUnitLabel(pageUnit)}'),
        const SizedBox(height: 4),
        Expanded(
            child: _ReadingBars(
          title: 'Tiempo por hora del día',
          values: hourly,
          labels: [for (var h = 0; h < 24; h++) '$h'],
          tooltips: [
            for (var h = 0; h < 24; h++)
              '$h:00 – ${h + 1}:00 · ${readingDuration(hourly[h])}'
          ],
          labelEvery: 3,
        )),
      ])),
    ]);
  }
}

class _ReadingRecord extends StatelessWidget {
  const _ReadingRecord(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 10),
        SizedBox(
            width: 170,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant))),
        Expanded(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _ReadingNote extends StatelessWidget {
  const _ReadingNote(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]);
}

class _ReadingMetrics extends StatelessWidget {
  const _ReadingMetrics({required this.values, this.comparisons});
  final List<(String, String, IconData)> values;
  // Variación respecto al año anterior; positiva en verde, negativa en rojo.
  final List<({String label, bool up})?>? comparisons;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = Theme.of(context).colorScheme;
    return Row(children: [
      for (var index = 0; index < values.length; index++) ...[
        if (index > 0) const SizedBox(width: 12),
        Expanded(
            child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .055),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.primary.withValues(alpha: .10))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(values[index].$3, size: 17, color: colors.primary),
              const SizedBox(width: 7),
              Expanded(
                  child: Text(values[index].$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant)))
            ]),
            const SizedBox(height: 10),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(values[index].$2,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800))),
            if (comparisons != null) ...[
              const SizedBox(height: 4),
              Text(comparisons![index]?.label ?? 'Sin datos del año anterior',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: comparisons![index] == null
                          ? colors.onSurfaceVariant
                          : comparisons![index]!.up
                              ? const Color(0xFF2E7D32)
                              : colors.error)),
            ],
          ]),
        )),
      ]
    ]);
  }
}

/// Selector temporal para comparar visualizaciones; se retirará al elegir.
class _TemporaryReadingViews extends StatefulWidget {
  const _TemporaryReadingViews({
    required this.pageUnit,
    required this.dailySeconds,
    required this.dailyPages,
    required this.hourlySeconds,
    required this.monthlySeconds,
    required this.year,
  });
  final Map<DateTime, int> dailySeconds, dailyPages;
  final String pageUnit;
  final List<int> hourlySeconds, monthlySeconds;
  final int year;
  @override
  State<_TemporaryReadingViews> createState() => _TemporaryReadingViewsState();
}

class _TemporaryReadingViewsState extends State<_TemporaryReadingViews> {
  static const _names = [
    'Calendario de calor',
    'Por días',
    'Por hora',
    'Por meses'
  ];
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final days = widget.dailySeconds.keys.toList()..sort();
    final Widget view;
    switch (_index) {
      case 1:
        final today = DateTime.now();
        final last = days.isEmpty ? today : days.last;
        final first = days.isEmpty ? last : days.first;
        var span = last.difference(first).inDays + 1;
        if (span < 14) span = 14;
        if (span > 60) span = 60;
        final dates = [
          for (var i = span - 1; i >= 0; i--)
            DateTime(last.year, last.month, last.day - i)
        ];
        view = _ReadingBars(
          title: 'Cada día de lectura',
          values: [for (final d in dates) widget.dailySeconds[d] ?? 0],
          labels: [for (final d in dates) '${d.day}'],
          tooltips: [
            for (final d in dates)
              '${_readingDate(d)} · ${readingDuration(widget.dailySeconds[d] ?? 0)}'
                  ' · ${widget.dailyPages[d] ?? 0} ${readingPageUnitLabel(widget.pageUnit, plural: true)}'
          ],
          labelEvery: span > 31
              ? 5
              : span > 20
                  ? 2
                  : 1,
        );
      case 2:
        view = _ReadingBars(
          title: 'A qué hora lees',
          values: widget.hourlySeconds,
          labels: [for (var h = 0; h < 24; h++) '$h'],
          tooltips: [
            for (var h = 0; h < 24; h++)
              '$h:00 – ${h + 1}:00 · ${readingDuration(widget.hourlySeconds[h])}'
          ],
          labelEvery: 3,
        );
      case 3:
        view = _ReadingMonthlyChart(
            values: widget.monthlySeconds,
            title: 'Actividad de ${widget.year}');
      default:
        view = _ReadingHeatmap(
            pageUnit: widget.pageUnit,
            dailySeconds: widget.dailySeconds,
            dailyPages: widget.dailyPages);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: colors.onSurface.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < _names.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(7),
              onTap: () => setState(() => _index = i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: i == _index ? colors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(7)),
                child: Text(_names[i],
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            i == _index ? FontWeight.w700 : FontWeight.w500,
                        color: i == _index
                            ? colors.primary
                            : colors.onSurfaceVariant)),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      Expanded(child: view),
    ]);
  }
}

class _ReadingBars extends StatelessWidget {
  const _ReadingBars({
    required this.title,
    required this.values,
    required this.labels,
    required this.tooltips,
    required this.labelEvery,
  });
  final String title;
  final List<int> values;
  final List<String> labels, tooltips;
  final int labelEvery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final maximum = values.fold<int>(1, (a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
              child: Tooltip(
                  message: tooltips[i],
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Column(children: [
                        Expanded(
                            child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                    widthFactor: 1,
                                    heightFactor: values[i] == 0
                                        ? .02
                                        : .06 + .94 * values[i] / maximum,
                                    child: DecoratedBox(
                                        decoration: BoxDecoration(
                                            color: values[i] == 0
                                                ? colors.onSurface
                                                    .withValues(alpha: .07)
                                                : colors.primary.withValues(
                                                    alpha: values[i] == maximum
                                                        ? 1
                                                        : .65),
                                            borderRadius:
                                                BorderRadius.circular(3)))))),
                        const SizedBox(height: 6),
                        SizedBox(
                            height: 14,
                            child: i % labelEvery == 0
                                ? OverflowBox(
                                    maxWidth: 40,
                                    child: Text(labels[i],
                                        softWrap: false,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: colors.onSurfaceVariant)))
                                : null),
                      ])))),
      ])),
    ]);
  }
}

class _ReadingHeatmap extends StatelessWidget {
  const _ReadingHeatmap(
      {required this.dailySeconds,
      required this.pageUnit,
      required this.dailyPages,
      this.from,
      this.to,
      this.title = 'Calendario de lectura'});
  final Map<DateTime, int> dailySeconds;
  final String pageUnit;
  final Map<DateTime, int> dailyPages;
  // Con un intervalo fijo (un año completo) no se ajusta a las lecturas.
  final DateTime? from, to;
  final String? title;

  static const _months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic'
  ];
  static const _weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _minWeeks = 6;
  static const _labelWidth = 22.0;
  static const _gap = 4.0;

  DateTime _mondayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final days = dailySeconds.keys.toList()..sort();
    final today = DateTime.now();
    final first = _mondayOf(from ?? (days.isEmpty ? today : days.first));
    final lastDay = to ?? (days.isEmpty ? today : days.last);
    var weeks = (_mondayOf(lastDay).difference(first).inDays ~/ 7) + 1;
    if (weeks < _minWeeks) weeks = _minWeeks;
    final maximum = dailySeconds.values.fold<int>(1, (a, b) => a > b ? a : b);
    return LayoutBuilder(builder: (context, constraints) {
      const header = 46.0, footer = 34.0;
      final availableWidth = constraints.maxWidth - _labelWidth;
      final availableHeight = constraints.maxHeight - header - footer;
      final fit = (availableWidth / (_gap + 14)).floor();
      final shown = weeks > fit ? fit.clamp(1, weeks) : weeks;
      final start =
          DateTime(first.year, first.month, first.day + 7 * (weeks - shown));
      final cell = ((availableWidth - _gap * (shown - 1)) / shown)
          .clamp(0.0, ((availableHeight - _gap * 6) / 7).clamp(0.0, 46.0))
          .toDouble();
      Color tone(int seconds) {
        if (seconds <= 0) return colors.onSurface.withValues(alpha: .07);
        final level = seconds / maximum;
        final step = level > .75
            ? 4
            : level > .5
                ? 3
                : level > .25
                    ? 2
                    : 1;
        return colors.primary
            .withValues(alpha: .18 + .20 * (step - 1) + (step == 4 ? .04 : 0));
      }

      Widget square(Color color, [String? message]) {
        final box = Container(
            width: cell,
            height: cell,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(cell * .22)));
        return message == null ? box : Tooltip(message: message, child: box);
      }

      final range = days.isEmpty || from != null
          ? ''
          : '${_readingDate(days.first)} – ${_readingDate(days.last)}';
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Row(children: [
            Text(title!,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (range.isNotEmpty)
              Text(range,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant)),
          ]),
          const SizedBox(height: 14),
        ],
        Expanded(
            child: Center(
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Column(children: [
                const SizedBox(height: 20),
                for (var row = 0; row < 7; row++)
                  Container(
                      width: _labelWidth,
                      height: cell,
                      alignment: Alignment.centerLeft,
                      margin: EdgeInsets.only(bottom: row < 6 ? _gap : 0),
                      child: Text(_weekdays[row],
                          softWrap: false,
                          style: TextStyle(
                              fontSize: cell < 14 ? 9 : 11,
                              height: 1,
                              color: colors.onSurfaceVariant))),
              ]),
              for (var week = 0; week < shown; week++) ...[
                if (week > 0) const SizedBox(width: _gap),
                Column(children: [
                  SizedBox(
                      height: 20,
                      width: cell,
                      child: () {
                        final monday = DateTime(
                            start.year, start.month, start.day + 7 * week);
                        final newMonth = week == 0 ||
                            monday.month !=
                                DateTime(monday.year, monday.month,
                                        monday.day - 7)
                                    .month;
                        return newMonth
                            ? OverflowBox(
                                alignment: Alignment.centerLeft,
                                maxWidth: 60,
                                child: Text(_months[monday.month - 1],
                                    softWrap: false,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colors.onSurfaceVariant)))
                            : null;
                      }()),
                  for (var row = 0; row < 7; row++)
                    Padding(
                        padding: EdgeInsets.only(bottom: row < 6 ? _gap : 0),
                        child: () {
                          final date = DateTime(start.year, start.month,
                              start.day + 7 * week + row);
                          final seconds = dailySeconds[date] ?? 0;
                          final pages = dailyPages[date] ?? 0;
                          final label = _readingDate(date);
                          return square(
                              tone(seconds),
                              seconds == 0
                                  ? label
                                  : '$label · ${readingDuration(seconds)}'
                                      ' · $pages ${readingPageUnitLabel(pageUnit, plural: pages != 1)}');
                        }()),
                ]),
              ],
            ]))),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('Menos',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
          const SizedBox(width: 6),
          for (final seconds in [0, 1, 2, 3, 4]) ...[
            Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(
                    color: tone(seconds * maximum ~/ 4),
                    borderRadius: BorderRadius.circular(3))),
          ],
          const SizedBox(width: 3),
          Text('Más',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
        ]),
      ]);
    });
  }
}

class _ReadingMonthlyChart extends StatelessWidget {
  const _ReadingMonthlyChart({required this.values, required this.title});
  final List<int> values;
  final String title;
  @override
  Widget build(BuildContext context) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];
    final colors = Theme.of(context).colorScheme;
    final maximum = values.fold<int>(1, (a, b) => a > b ? a : b);
    String corto(int seconds) {
      final minutes = (seconds / 60).round();
      return minutes < 60
          ? '$minutes m'
          : '${(minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1)} h';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < 12; i++)
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Tooltip(
                    message: '${months[i]} · ${readingDuration(values[i])}',
                    child: Column(children: [
                      Expanded(
                          child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (values[i] > 0)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Text(corto(values[i]),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      values[i] == maximum
                                                          ? FontWeight.w800
                                                          : FontWeight.w600,
                                                  color: values[i] == maximum
                                                      ? colors.primary
                                                      : colors
                                                          .onSurfaceVariant))),
                                    Flexible(
                                        child: FractionallySizedBox(
                                      widthFactor: .70,
                                      heightFactor: values[i] == 0
                                          ? .025
                                          : (.08 + .92 * values[i] / maximum),
                                      child: DecoratedBox(
                                          decoration: BoxDecoration(
                                              color: values[i] == 0
                                                  ? colors.onSurface
                                                      .withValues(alpha: .07)
                                                  : colors.primary.withValues(
                                                      alpha:
                                                          values[i] == maximum
                                                              ? 1
                                                              : .65),
                                              borderRadius:
                                                  BorderRadius.circular(5))),
                                    ))
                                  ]))),
                      const SizedBox(height: 8),
                      Text(months[i],
                          style: TextStyle(
                              fontSize: 11, color: colors.onSurfaceVariant)),
                    ]),
                  ))),
      ])),
    ]);
  }
}
