part of 'todo_workspace.dart';

extension TodoWorkspaceDiario on TodoWorkspace {
  JournalEntry? journalEntryById(String id) {
    for (final entry in _journalEntries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  JournalEntry? journalEntryForDate(DateTime date) {
    for (final entry in _journalEntries) {
      if (_sameDay(entry.date, date)) return entry;
    }
    return null;
  }

  /// Entradas de la misma fecha en años anteriores, de la más reciente a la
  /// más antigua.
  List<JournalEntry> journalOnThisDay(DateTime date) {
    final matches = _journalEntries
        .where((entry) =>
            entry.date.year < date.year &&
            entry.date.month == date.month &&
            entry.date.day == date.day)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return matches;
  }

  /// Crea la entrada del día o actualiza la existente: solo hay una por día.
  JournalEntry saveJournalEntry({
    required DateTime date,
    required String text,
    int mood = 0,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final existing = journalEntryForDate(day);
    if (existing != null) {
      final updated = existing.copyWith(
        text: text.trim(),
        mood: mood.clamp(0, 5),
        updatedAt: now,
      );
      _journalEntries[_journalEntries.indexWhere((e) => e.id == existing.id)] =
          updated;
      _commit();
      return updated;
    }
    final entry = JournalEntry(
      id: _id('journal'),
      date: day,
      text: text.trim(),
      mood: mood.clamp(0, 5),
      createdAt: now,
      updatedAt: now,
    );
    _journalEntries.add(entry);
    _commit();
    return entry;
  }

  Future<String> journalImageAbsolutePath(JournalEntry entry,
          {bool thumbnail = true}) =>
      _journalAssets.absolutePath(thumbnail && entry.thumbnailPath.isNotEmpty
          ? entry.thumbnailPath
          : entry.imagePath);

  Future<void> importJournalImage(String id, String sourcePath) async {
    if (journalEntryById(id) == null) {
      throw StateError('No se encuentra la entrada del diario.');
    }
    final imported = await _journalAssets.importImage(id, sourcePath);
    final index = _journalEntries.indexWhere((entry) => entry.id == id);
    if (index == -1) return;
    final previous = _journalEntries[index];
    _journalEntries[index] = previous.copyWith(
      imagePath: imported.imagePath,
      thumbnailPath: imported.thumbnailPath,
      imageSha256: imported.sha256,
      updatedAt: DateTime.now(),
    );
    _commit();
    for (final path in {previous.imagePath, previous.thumbnailPath}) {
      if (path.isNotEmpty &&
          path != imported.imagePath &&
          path != imported.thumbnailPath) {
        await _journalAssets.deleteAsset(path);
      }
    }
  }

  Future<void> removeJournalImage(String id) async {
    final index = _journalEntries.indexWhere((entry) => entry.id == id);
    if (index == -1) return;
    final previous = _journalEntries[index];
    _journalEntries[index] = previous.copyWith(
      imagePath: '',
      thumbnailPath: '',
      imageSha256: '',
      updatedAt: DateTime.now(),
    );
    _commit();
    for (final path in {previous.imagePath, previous.thumbnailPath}) {
      if (path.isNotEmpty) await _journalAssets.deleteAsset(path);
    }
  }

  void deleteJournalEntry(String id) {
    final entry = journalEntryById(id);
    if (entry == null) return;
    _journalEntries.removeWhere((item) => item.id == id);
    _commit();
    for (final path in {entry.imagePath, entry.thumbnailPath}) {
      if (path.isNotEmpty) unawaited(_journalAssets.deleteAsset(path));
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
