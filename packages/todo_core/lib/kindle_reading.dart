part of 'kindle_workspace.dart';

extension KindleReading on KindleWorkspace {
  Map<String, dynamic> _kindleBooks() => {
        'books': [
          for (final b
              in _libraryItems.where((b) => b.type == LibraryItemType.book))
            {'id': b.id, 'title': b.title, 'author': b.author ?? ''}
        ]
      };

  Future<Map<String, dynamic>> _syncKindleBook(
      Map<String, dynamic> args, String requestId, String fingerprint) async {
    String text(String key, int limit,
        {Map<String, dynamic>? from, bool optional = false}) {
      final value = (from ?? args)[key];
      if (optional && value == null) return '';
      if (value is! String || value.length > limit) {
        throw FormatException('El campo $key no es válido.');
      }
      return value;
    }

    final document = text('document_id', 64);
    final source = text('source_id', 128);
    final title = text('title', 512);
    final author = text('author', 512);
    final page = text('page', 256);
    final chapter = text('chapter', 1024, optional: true);
    final totalPages = args['total_pages'] ?? 0;
    final position = text('position', 8192);
    final target = text('library_item_id', 128, optional: true);
    final sequence = args['sequence'];
    final observed = args['observed_at'];
    final progress = args['progress'];
    final incomingQuotes = args['quotes'];
    if (!RegExp(r'^[a-fA-F0-9]{32,64}$').hasMatch(document) ||
        !RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(source) ||
        title.trim().isEmpty ||
        sequence is! int ||
        sequence < 1 ||
        observed is! int ||
        observed < 0 ||
        observed > DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300 ||
        progress is! num ||
        !progress.isFinite ||
        progress < 0 ||
        progress > 1 ||
        incomingQuotes is! List ||
        incomingQuotes.length > 20 ||
        totalPages is! int ||
        totalPages < 0 ||
        totalPages > 10000000) {
      throw const FormatException('Los datos de lectura no son válidos.');
    }
    String? statisticsKey;
    BookReadingStatistics? statistics;
    final rawStatistics = args['statistics'];
    if (rawStatistics != null) {
      if (rawStatistics is! Map<String, dynamic> ||
          rawStatistics['origin'] is! String ||
          !RegExp(r'^[A-Za-z0-9_-]{8,128}$')
              .hasMatch(rawStatistics['origin'] as String) ||
          rawStatistics['book_id'] is! int ||
          (rawStatistics['book_id'] as int) < 1) {
        throw const FormatException('La fuente de estadísticas no es válida.');
      }
      statisticsKey = '${rawStatistics['origin']}:${rawStatistics['book_id']}';
      statistics = BookReadingStatistics.fromJson(
          {'observedAt': observed, 'periods': rawStatistics['periods']});
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (statistics.periods.any((p) => p.start > now + 3600)) {
        throw const FormatException(
            'Hay estadísticas de lectura con fecha futura.');
      }
    }
    final quotes = <Map<String, dynamic>>[];
    for (final raw in incomingQuotes) {
      if (raw is! Map<String, dynamic> ||
          raw.keys.any((k) => !{
                'anchor',
                'text',
                'note',
                'page',
                'chapter',
                'created_at'
              }.contains(k))) {
        throw const FormatException('La cita no es válida.');
      }
      final anchor = text('anchor', 16384, from: raw);
      final content = text('text', 65536, from: raw);
      if (anchor.isEmpty || content.trim().isEmpty) {
        throw const FormatException('La cita necesita texto y posición.');
      }
      quotes.add({
        'id': _agentDigest([document, anchor]),
        'document_id': document,
        'anchor': anchor,
        'text': content,
        'note': text('note', 65536, from: raw),
        'page': text('page', 256, from: raw),
        'chapter': text('chapter', 1024, from: raw),
        'created_at': text('created_at', 64, from: raw),
        'observed_at': observed
      });
    }
    final books =
        _libraryItems.where((b) => b.type == LibraryItemType.book).toList();
    var matches = books
        .where((b) => b.reading?.documents.contains(document) ?? false)
        .toList();
    if (matches.isEmpty && target.isNotEmpty) {
      matches = books.where((b) => b.id == target).toList();
    }
    if (matches.isEmpty && target.isEmpty && author.trim().isNotEmpty) {
      matches = books
          .where((b) =>
              _libraryTitleKey(b.title) == _libraryTitleKey(title) &&
              _libraryTitleKey(b.author ?? '') == _libraryTitleKey(author))
          .toList();
    }
    if (matches.length != 1) return {'status': 'needs_link', ..._kindleBooks()};
    final book = matches.single;
    final old = book.reading;
    final cursor = '$source:$document';
    if (sequence > (old?.cursors[cursor] ?? 0)) {
      final combined = {
        for (final q in old?.quotes ?? <Map<String, dynamic>>[])
          q['id'] as String: q
      };
      for (final q in quotes) {
        final previous = combined[q['id']];
        if (previous == null ||
            (previous['manual_edit'] != true &&
                observed >= (previous['observed_at'] as int? ?? 0))) {
          combined[q['id'] as String] = q;
        }
      }
      final newer = old == null || observed >= old.observedAt;
      final reading = LibraryReading(
          progress: newer ? progress.toDouble() : old.progress,
          observedAt: newer ? observed : old.observedAt,
          page: newer ? page : old.page,
          totalPages:
              newer && totalPages > 0 ? totalPages : old?.totalPages ?? 0,
          position: newer ? position : old.position,
          chapter: newer ? chapter : old.chapter,
          statistics: {
            ...?old?.statistics,
            if (statisticsKey != null &&
                statistics != null &&
                statistics.observedAt >=
                    (old?.statistics[statisticsKey]?.observedAt ?? -1))
              statisticsKey: statistics,
          },
          documents: {...?old?.documents, document}.toList(),
          cursors: {...?old?.cursors, cursor: sequence},
          quotes: combined.values.toList());
      _libraryItems[_libraryItems.indexWhere((b) => b.id == book.id)] =
          book.copyWith(reading: reading, updatedAt: DateTime.now());
    }
    // Los cursores conservan la idempotencia de los lotes antiguos. Limitar sus
    // recibos evita agotar el registro de marcas con los cambios de página.
    final receipts = _agentOperationReceipts.entries
        .where((e) =>
            (e.value as Map)['result'] is Map &&
            (e.value as Map)['result']['reading'] == true)
        .toList();
    for (final entry in receipts.take(max(0, receipts.length - 255))) {
      _agentOperationReceipts.remove(entry.key);
    }
    return _finishAgentOperation(requestId, fingerprint,
        {'status': 'saved', 'reading': true, 'library_item_id': book.id});
  }
}
