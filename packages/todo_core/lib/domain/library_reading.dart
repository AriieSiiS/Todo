import 'library_reading_statistics.dart';
export 'library_reading_statistics.dart';

/// Lectura y citas recibidas de KOReader; independientes del estado de Biblioteca.
int? bookPageTotal(String? pages, LibraryReading? reading,
    {bool manual = false}) {
  if (!manual && reading?.hasReaderPagination == true) {
    return reading!.totalPages > 0 ? reading.totalPages : null;
  }
  final match = RegExp(r'^\s*(\d{1,7})(?:\s*(?:páginas?|págs?\.?))?\s*(?:\(|$)',
          caseSensitive: false)
      .firstMatch(pages ?? '');
  final editorial = int.tryParse(match?.group(1) ?? '');
  if (editorial != null && editorial > 0) return editorial;
  if (manual && reading?.hasReaderPagination == true) return null;
  final kindle = reading?.totalPages ?? 0;
  return kindle > 0 ? kindle : null;
}

int bookReadingPercent(LibraryReading? reading) => reading?.percent ?? 0;

class LibraryReading {
  LibraryReading(
      {required this.progress,
      required this.observedAt,
      required this.page,
      required this.position,
      this.chapter = '',
      this.totalPages = 0,
      this.pageUnit = 'unknown',
      Set<String> deletedQuoteIds = const {},
      Map<String, BookReadingStatistics> statistics = const {},
      required List<String> documents,
      required Map<String, int> cursors,
      required List<Map<String, dynamic>> quotes})
      : deletedQuoteIds = Set.unmodifiable(deletedQuoteIds),
        statistics = Map.unmodifiable(statistics),
        documents = List.unmodifiable(documents),
        cursors = Map.unmodifiable(cursors),
        quotes = List.unmodifiable(quotes
            .where((q) => !deletedQuoteIds.contains(q['id']))
            .map((q) => Map<String, dynamic>.unmodifiable(q)));

  final double progress;
  final int observedAt;
  final String page;
  final String position;
  final String chapter;
  final int totalPages;
  final String pageUnit;
  bool get hasReaderPagination =>
      position.isNotEmpty ||
      pageUnit == 'screen' ||
      pageUnit == 'estimated_page';
  String get effectivePageUnit =>
      position.isEmpty && pageUnit == 'unknown' ? 'page' : pageUnit;
  String get pageLabel => switch (effectivePageUnit) {
        'screen' => 'Pantalla',
        'page' => 'Página',
        'estimated_page' => 'Página',
        _ => 'Posición en KOReader'
      };
  final List<String> documents;
  final Map<String, int> cursors;
  final List<Map<String, dynamic>> quotes;
  final Set<String> deletedQuoteIds;
  final Map<String, BookReadingStatistics> statistics;
  int get percent => (progress * 100).round().clamp(0, 100);

  Map<String, dynamic> toJson() => {
        'progress': progress,
        'observedAt': observedAt,
        'page': page,
        'totalPages': totalPages,
        'pageUnit': pageUnit,
        'position': position,
        'chapter': chapter,
        'statistics':
            statistics.map((key, value) => MapEntry(key, value.toJson())),
        'documents': documents,
        'cursors': cursors,
        'quotes': quotes,
        'deletedQuoteIds': deletedQuoteIds.toList(),
      };
  factory LibraryReading.fromJson(Map<String, dynamic> json) => LibraryReading(
      progress: (json['progress'] as num).toDouble(),
      observedAt: json['observedAt'] as int,
      page: json['page'] as String? ?? '',
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      pageUnit: readingPageUnit(json['pageUnit']),
      position: json['position'] as String? ?? '',
      chapter: json['chapter'] as String? ?? '',
      deletedQuoteIds:
          (json['deletedQuoteIds'] as List? ?? const []).cast<String>().toSet(),
      statistics: (json['statistics'] as Map? ?? {}).map((key, value) =>
          MapEntry(
              key as String,
              BookReadingStatistics.fromJson(
                  Map<String, dynamic>.from(value as Map)))),
      documents: (json['documents'] as List).cast<String>(),
      cursors: (json['cursors'] as Map)
          .map((k, v) => MapEntry(k as String, v as int)),
      quotes: (json['quotes'] as List)
          .map((q) => Map<String, dynamic>.from(q as Map))
          .toList());

  LibraryReading withoutQuote(String id) => LibraryReading(
      progress: progress,
      observedAt: observedAt,
      page: page,
      position: position,
      chapter: chapter,
      totalPages: totalPages,
      pageUnit: pageUnit,
      statistics: statistics,
      documents: documents,
      cursors: cursors,
      quotes: quotes,
      deletedQuoteIds: {...deletedQuoteIds, id});

  /// Conserva vínculos, citas, eliminaciones y cursores al unir dos fichas.
  LibraryReading merge(LibraryReading? other) {
    if (other == null) return this;
    final latest = observedAt >= other.observedAt ? this : other;
    final all = <String, Map<String, dynamic>>{};
    for (final q in [...other.quotes, ...quotes]) {
      final previous = all[q['id']];
      if (previous == null ||
          (q['manual_edit'] == true && previous['manual_edit'] != true) ||
          (previous['manual_edit'] != true &&
              (q['observed_at'] as int? ?? 0) >=
                  (previous['observed_at'] as int? ?? 0))) {
        all[q['id'] as String] = q;
      }
    }
    return LibraryReading(
        progress: latest.progress,
        observedAt: latest.observedAt,
        page: latest.page,
        totalPages: latest.totalPages,
        pageUnit: latest.pageUnit,
        position: latest.position,
        chapter: latest.chapter,
        deletedQuoteIds: {...deletedQuoteIds, ...other.deletedQuoteIds},
        statistics: {
          ...other.statistics,
          for (final entry in statistics.entries)
            entry.key: entry.value.observedAt >=
                    (other.statistics[entry.key]?.observedAt ?? -1)
                ? entry.value
                : other.statistics[entry.key]!,
        },
        documents: {...documents, ...other.documents}.toList(),
        cursors: {
          ...other.cursors,
          for (final e in cursors.entries)
            e.key: e.value > (other.cursors[e.key] ?? 0)
                ? e.value
                : other.cursors[e.key]!
        },
        quotes: all.values.toList());
  }
}
