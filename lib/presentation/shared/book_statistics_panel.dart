import 'package:flutter/material.dart';
import '../../domain/models.dart';

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
    final dates = summary.dailySeconds.keys.toList()..sort();
    final empty = dates.isEmpty;
    final dailyPages = <DateTime, int>{};
    for (final source
        in reading?.statistics.values ?? <BookReadingStatistics>[]) {
      for (final period in source.periods) {
        if (period.seconds == 0) continue;
        final date = period.localDate;
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
          ('Páginas leídas', '${summary.pages}', Icons.auto_stories_outlined),
          ('Días de lectura', '${summary.days}', Icons.calendar_today_outlined),
          (
            'Mejor racha',
            '${summary.longestStreak} ${summary.longestStreak == 1 ? 'día' : 'días'}',
            Icons.local_fire_department_outlined
          ),
        ]),
        SizedBox(height: compact ? 12 : 24),
        Expanded(
            child: _ReadingHeatmap(
          dailySeconds: summary.dailySeconds,
          dailyPages: dailyPages,
        )),
        SizedBox(height: compact ? 10 : 20),
        Wrap(spacing: 28, runSpacing: 8, children: [
          _ReadingNote(
              'Ritmo medio',
              summary.pages == 0
                  ? '—'
                  : '${(summary.seconds / summary.pages).round()} s / página'),
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
  const AnnualReadingStatisticsDialog({required this.books, super.key});
  final List<LibraryItem> books;
  @override
  State<AnnualReadingStatisticsDialog> createState() =>
      _AnnualReadingStatisticsDialogState();
}

class _AnnualReadingStatisticsDialogState
    extends State<AnnualReadingStatisticsDialog> {
  int _year = DateTime.now().year;
  @override
  Widget build(BuildContext context) {
    final books =
        widget.books.where((b) => b.type == LibraryItemType.book).toList();
    final sources = combinedReadingStatistics(books);
    final summary = ReadingStatisticsSummary(sources.values, year: _year);
    final years = <int>{
      DateTime.now().year,
      for (final source in sources.values)
        for (final p in source.periods) p.localDate.year,
      for (final book in books)
        if (book.completedDate != null) book.completedDate!.year,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    final completed = books
        .where((b) =>
            b.status == LibraryItemStatus.completed &&
            b.completedDate?.year == _year)
        .length;
    final ranking = [
      for (final book in books)
        (
          book: book,
          stats: ReadingStatisticsSummary(book.reading?.statistics.values ?? [],
              year: _year)
        )
    ]..sort((a, b) => b.stats.seconds.compareTo(a.stats.seconds));
    final active = ranking.where((entry) => entry.stats.seconds > 0).toList();
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
            const SizedBox(height: 22),
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
                'Páginas leídas',
                '${summary.pages}',
                Icons.auto_stories_outlined
              ),
              ('Libros terminados', '$completed', Icons.task_alt_rounded),
            ]),
            const SizedBox(height: 24),
            Expanded(
                flex: 3,
                child: _ReadingMonthlyChart(
                    values: summary.monthlySeconds, title: 'Mes a mes')),
            const SizedBox(height: 22),
            Row(children: [
              Text('Tus lecturas',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                  '${active.length} libros · Racha máxima: ${summary.longestStreak} días',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 10),
            Expanded(
                flex: 2,
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
                                width: 30,
                                child: Text('${index + 1}',
                                    style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w800))),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(entry.book.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  if ((entry.book.author ?? '').isNotEmpty)
                                    Text(entry.book.author!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant)),
                                ])),
                            const SizedBox(width: 12),
                            Text(readingDuration(entry.stats.seconds),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ]);
                        },
                      )),
          ]),
        ),
      ),
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
  const _ReadingMetrics({required this.values});
  final List<(String, String, IconData)> values;
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
          ]),
        )),
      ]
    ]);
  }
}

class _ReadingHeatmap extends StatelessWidget {
  const _ReadingHeatmap({required this.dailySeconds, required this.dailyPages});
  final Map<DateTime, int> dailySeconds;
  final Map<DateTime, int> dailyPages;

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
    final first = _mondayOf(days.isEmpty ? today : days.first);
    final lastDay = days.isEmpty ? today : days.last;
    var weeks = (_mondayOf(lastDay).difference(first).inDays ~/ 7) + 1;
    if (weeks < _minWeeks) weeks = _minWeeks;
    final maximum = dailySeconds.values.fold<int>(1, (a, b) => a > b ? a : b);
    return LayoutBuilder(builder: (context, constraints) {
      const header = 38.0, footer = 30.0;
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

      final range = days.isEmpty
          ? ''
          : '${_readingDate(days.first)} – ${_readingDate(days.last)}';
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Calendario de lectura',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (range.isNotEmpty)
            Text(range,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant)),
        ]),
        const SizedBox(height: 14),
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
                      child: Text(row.isEven ? _weekdays[row] : '',
                          style: TextStyle(
                              fontSize: 11, color: colors.onSurfaceVariant))),
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
                                      ' · $pages ${pages == 1 ? 'página' : 'páginas'}');
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
