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
    if (summary.seconds == 0) {
      return const _ReadingEmpty();
    }
    final dates = summary.dailySeconds.keys.toList()..sort();
    final year = dates.last.year;
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
            '${summary.longestStreak} días',
            Icons.local_fire_department_outlined
          ),
        ]),
        SizedBox(height: compact ? 12 : 24),
        Expanded(
            child: _ReadingMonthlyChart(
          values: ReadingStatisticsSummary(reading?.statistics.values ?? [],
                  year: year)
              .monthlySeconds,
          title: 'Actividad de $year',
        )),
        SizedBox(height: compact ? 10 : 20),
        Wrap(spacing: 28, runSpacing: 8, children: [
          _ReadingNote(
              'Ritmo medio',
              summary.pages == 0
                  ? '—'
                  : '${(summary.seconds / summary.pages).round()} s / página'),
          _ReadingNote('Media por día de lectura',
              readingDuration((summary.seconds / summary.days).round())),
          _ReadingNote('Primera lectura', _readingDate(dates.first)),
          _ReadingNote('Última lectura', _readingDate(dates.last)),
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

class _ReadingEmpty extends StatelessWidget {
  const _ReadingEmpty();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: .07)),
          child: Icon(Icons.insights_rounded,
              size: 36, color: theme.colorScheme.primary)),
      const SizedBox(height: 20),
      Text('Tu próxima lectura empieza aquí',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('El tiempo y la actividad se sincronizarán desde el Kindle.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    ]));
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
