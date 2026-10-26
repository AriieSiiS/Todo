part of 'todo_workspace.dart';

extension TodoWorkspaceBiblioteca on TodoWorkspace {
  LibraryItem createLibraryItem({
    required LibraryItemType type,
    required String title,
    LibraryItemStatus status = LibraryItemStatus.completed,
    DateTime? completedDate,
    String? coverUrl,
    String? externalUrl,
    double? rating,
    String? note,
    String? platform,
    String? developer,
    String? author,
    LibraryMediaType? mediaType,
    int? releaseYear,
    String? creatorOrDirector,
    String? genre,
    String? format,
    String? duration,
    String? pages,
    String? country,
    String? universeName,
    String? collectionName,
    int? collectionNumber,
    bool showCollectionNumber = false,
    int rewatchCount = 1,
    int? seasonCount,
    bool nextSeasonConfirmed = false,
    LibraryPublicationStatus? publicationStatus,
  }) {
    final now = DateTime.now();
    final normalizedCompletedDate = status == LibraryItemStatus.completed
        ? completedDate ?? logicalDate()
        : null;
    final item = LibraryItem(
      id: _id('library'),
      type: type,
      title: title.trim(),
      status: status,
      completedDate: normalizedCompletedDate,
      coverUrl: coverUrl?.trim().isEmpty == true ? null : coverUrl?.trim(),
      externalUrl:
          externalUrl?.trim().isEmpty == true ? null : externalUrl?.trim(),
      rating: rating,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      platform: platform?.trim().isEmpty == true ? null : platform?.trim(),
      developer: developer?.trim().isEmpty == true ? null : developer?.trim(),
      author: author?.trim().isEmpty == true ? null : author?.trim(),
      mediaType: mediaType,
      releaseYear: releaseYear,
      creatorOrDirector: creatorOrDirector?.trim().isEmpty == true
          ? null
          : creatorOrDirector?.trim(),
      genre: genre?.trim().isEmpty == true ? null : genre?.trim(),
      format: format?.trim().isEmpty == true ? null : format?.trim(),
      duration: duration?.trim().isEmpty == true ? null : duration?.trim(),
      pages: pages?.trim().isEmpty == true ? null : pages?.trim(),
      country: country?.trim().isEmpty == true ? null : country?.trim(),
      universeName: universeName?.trim().isEmpty == true
          ? null
          : universeName?.trim(),
      collectionName: collectionName?.trim().isEmpty == true
          ? null
          : collectionName?.trim(),
      collectionNumber: collectionNumber != null && collectionNumber > 0
          ? collectionNumber
          : null,
      showCollectionNumber: showCollectionNumber,
      rewatchCount: rewatchCount.clamp(1, 99).toInt(),
      seasonCount: seasonCount != null && seasonCount > 0 ? seasonCount : null,
      nextSeasonConfirmed: nextSeasonConfirmed,
      publicationStatus: publicationStatus,
      createdAt: now,
      updatedAt: now,
    );
    var existingIndex = _libraryItems.indexWhere(
      (existing) => _isSameLibraryEntry(existing, item),
    );
    if (existingIndex == -1 && status == LibraryItemStatus.completed) {
      existingIndex = _libraryItems.indexWhere((existing) {
        if (existing.status == LibraryItemStatus.completed ||
            existing.type != item.type ||
            _libraryTitleKey(existing.title) != _libraryTitleKey(item.title)) {
          return false;
        }
        final goal = _libraryGoals.cast<LibraryGoal?>().firstWhere(
              (candidate) => candidate?.id == existing.linkedGoalId,
              orElse: () => null,
            );
        return goal != null && goal.targetYear == normalizedCompletedDate?.year;
      });
    }
    if (existingIndex != -1) {
      final existing = _libraryItems[existingIndex];
      final merged = _mergeLibraryItems(existing, item).copyWith(
        id: existing.id,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
      _libraryItems[existingIndex] = merged;
      _syncLibraryGoalFromItem(merged, now);
      unawaited(_knowledgeService.syncLibraryItem(merged));
      _commit();
      return _libraryItems[existingIndex];
    }
    _libraryItems.add(item);
    _syncLibraryGoalFromItem(item, now);
    unawaited(_knowledgeService.syncLibraryItem(item));
    _commit();
    return _libraryItems.firstWhere(
      (value) => value.id == item.id,
      orElse: () => item,
    );
  }

  void updateLibraryItem(LibraryItem updated, {bool replaceReading = false}) {
    final index = _libraryItems.indexWhere((item) => item.id == updated.id);
    if (index == -1) {
      return;
    }
    final now = DateTime.now();
    final next = updated.copyWith(
      reading: replaceReading
          ? updated.reading
          : _libraryItems[index].reading?.merge(updated.reading) ??
              updated.reading,
      completedDate: updated.status == LibraryItemStatus.completed
          ? updated.completedDate ?? logicalDate()
          : null,
      clearCompletedDate: updated.status != LibraryItemStatus.completed,
      updatedAt: now,
    );
    _libraryItems[index] = next;
    _syncLibraryGoalFromItem(next, now);
    unawaited(_knowledgeService.syncLibraryItem(next));
    _commit();
  }

  bool updateBookReadingPage(String itemId, int page) {
    final index = _libraryItems.indexWhere((item) => item.id == itemId);
    if (index == -1 || _libraryItems[index].type != LibraryItemType.book) {
      return false;
    }
    final item = _libraryItems[index];
    final total = bookPageTotal(item.pages, item.reading);
    if (total == null || page < 0 || page > total) return false;
    final old = item.reading;
    final reading = LibraryReading(
      progress: page / total,
      observedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      page: page.toString(),
      totalPages: total,
      position: '',
      documents: old?.documents ?? const [],
      cursors: old?.cursors ?? const {},
      quotes: old?.quotes ?? const [],
      statistics: old?.statistics ?? const {},
    );
    updateLibraryItem(item.copyWith(reading: reading), replaceReading: true);
    return true;
  }

  bool updateBookQuote(
    String itemId,
    String quoteId, {
    required String text,
    required String page,
    required String chapter,
    required String note,
  }) {
    final index = _libraryItems.indexWhere((item) => item.id == itemId);
    if (index == -1 || text.trim().isEmpty) return false;
    final item = _libraryItems[index];
    final old = item.reading;
    if (item.type != LibraryItemType.book || old == null) return false;
    final quoteIndex = old.quotes.indexWhere((quote) => quote['id'] == quoteId);
    if (quoteIndex == -1) return false;
    final quotes =
        old.quotes.map((quote) => Map<String, dynamic>.from(quote)).toList();
    quotes[quoteIndex] = {
      ...quotes[quoteIndex],
      'text': text.trim(),
      'page': page.trim(),
      'chapter': chapter.trim(),
      'note': note.trim(),
      'manual_edit': true,
      'observed_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
    final reading = LibraryReading(
      progress: old.progress,
      observedAt: old.observedAt,
      page: old.page,
      totalPages: old.totalPages,
      position: old.position,
      chapter: old.chapter,
      documents: old.documents,
      cursors: old.cursors,
      quotes: quotes,
      statistics: old.statistics,
    );
    updateLibraryItem(item.copyWith(reading: reading), replaceReading: true);
    return true;
  }

  void updateLibraryItemStatus(
    String itemId,
    LibraryItemStatus status, {
    DateTime? completedDate,
  }) {
    final index = _libraryItems.indexWhere((item) => item.id == itemId);
    if (index == -1 || _libraryItems[index].status == status) {
      return;
    }
    final now = DateTime.now();
    final item = _libraryItems[index];
    final next = item.copyWith(
      status: status,
      completedDate: status == LibraryItemStatus.completed
          ? completedDate ?? logicalDate()
          : null,
      clearCompletedDate: status != LibraryItemStatus.completed,
      updatedAt: now,
    );
    _libraryItems[index] = next;
    _syncLibraryGoalFromItem(next, now);
    _commit();
  }

  void deleteLibraryItem(String itemId) {
    final itemIndex = _libraryItems.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) {
      return;
    }
    _knowledgeService.trashForOwner('libraryItem', itemId);
    if (_openKnowledgeLibraryItem?.id == itemId) {
      _openKnowledgeLibraryItem = null;
    }
    final deleted = _libraryItems.removeAt(itemIndex);
    final goalIndex = _libraryGoals.indexWhere(
      (goal) =>
          goal.id == deleted.linkedGoalId ||
          goal.linkedLibraryItemId == deleted.id,
    );
    if (goalIndex != -1) {
      final now = DateTime.now();
      final goal = _libraryGoals[goalIndex].copyWith(
        status: LibraryGoalStatus.pending,
        clearLinkedLibraryItemId: true,
        updatedAt: now,
      );
      final replacement = _libraryItemFromGoal(
        goal,
        _id('library'),
        LibraryItemStatus.pending,
        null,
        deleted.rating,
        now,
        now,
      );
      _libraryItems.add(replacement);
      unawaited(_knowledgeService.syncLibraryItem(replacement));
      _libraryGoals[goalIndex] = goal.copyWith(
        linkedLibraryItemId: replacement.id,
        updatedAt: now,
      );
    }
    _commit();
  }

  LibraryGoal createLibraryGoal({
    required LibraryItemType type,
    required String title,
    required int targetYear,
    bool isFavorite = false,
    String? coverUrl,
    String? note,
    String? platform,
    String? developer,
    String? author,
    LibraryMediaType? mediaType,
    int? releaseYear,
    String? creatorOrDirector,
    String? genre,
    String? format,
    String? duration,
    String? pages,
    String? country,
  }) {
    final now = DateTime.now();
    final goal = LibraryGoal(
      id: _id('library_goal'),
      type: type,
      title: title.trim(),
      targetYear: targetYear,
      isFavorite: isFavorite,
      coverUrl: coverUrl?.trim().isEmpty == true ? null : coverUrl?.trim(),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      platform: platform?.trim().isEmpty == true ? null : platform?.trim(),
      developer: developer?.trim().isEmpty == true ? null : developer?.trim(),
      author: author?.trim().isEmpty == true ? null : author?.trim(),
      mediaType: mediaType,
      releaseYear: releaseYear,
      creatorOrDirector: creatorOrDirector?.trim().isEmpty == true
          ? null
          : creatorOrDirector?.trim(),
      genre: genre?.trim().isEmpty == true ? null : genre?.trim(),
      format: format?.trim().isEmpty == true ? null : format?.trim(),
      duration: duration?.trim().isEmpty == true ? null : duration?.trim(),
      pages: pages?.trim().isEmpty == true ? null : pages?.trim(),
      country: country?.trim().isEmpty == true ? null : country?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _libraryGoals.add(goal);
    _syncLibraryItemFromGoal(goal, now);
    _commit();
    return _libraryGoals.firstWhere((item) => item.id == goal.id);
  }

  void updateLibraryGoal(LibraryGoal updated) {
    final index = _libraryGoals.indexWhere((goal) => goal.id == updated.id);
    if (index == -1) {
      return;
    }
    final now = DateTime.now();
    final next = updated.copyWith(updatedAt: now);
    _libraryGoals[index] = next;
    _syncLibraryItemFromGoal(next, now);
    _commit();
  }

  void deleteLibraryGoal(String goalId) {
    final index = _libraryGoals.indexWhere((goal) => goal.id == goalId);
    if (index == -1) {
      return;
    }
    final deleted = _libraryGoals.removeAt(index);
    final itemIndex = _libraryItems.indexWhere(
      (item) =>
          item.id == deleted.linkedLibraryItemId ||
          item.linkedGoalId == deleted.id,
    );
    if (itemIndex != -1) {
      _libraryItems[itemIndex] = _libraryItems[itemIndex].copyWith(
        clearLinkedGoalId: true,
        updatedAt: DateTime.now(),
      );
    }
    _commit();
  }

  void toggleLibraryGoalCompleted(String goalId) {
    final index = _libraryGoals.indexWhere((goal) => goal.id == goalId);
    if (index == -1) {
      return;
    }
    final goal = _libraryGoals[index];
    final willComplete = !goal.isCompleted;
    final now = DateTime.now();
    _libraryGoals[index] = goal.copyWith(
      status: willComplete
          ? LibraryGoalStatus.completed
          : LibraryGoalStatus.pending,
      updatedAt: now,
    );
    _syncLibraryItemFromGoal(
      _libraryGoals[index],
      now,
      reopenAsPending: !willComplete,
    );
    _commit();
  }

  bool _syncLibraryItemFromGoal(
    LibraryGoal goal,
    DateTime now, {
    bool reopenAsPending = false,
  }) {
    final goalIndex = _libraryGoals.indexWhere((item) => item.id == goal.id);
    if (goalIndex == -1) {
      return false;
    }
    final normalizedTitle = _libraryTitleKey(goal.title);
    var linkedIndex = goal.linkedLibraryItemId == null
        ? -1
        : _libraryItems
            .indexWhere((item) => item.id == goal.linkedLibraryItemId);

    if (!goal.isCompleted &&
        linkedIndex != -1 &&
        _libraryItems[linkedIndex].status == LibraryItemStatus.completed &&
        !reopenAsPending) {
      final historical = _libraryItems[linkedIndex];
      _libraryItems[linkedIndex] = historical.copyWith(
        clearLinkedGoalId: true,
        updatedAt: now,
      );
      linkedIndex = -1;
    }

    final matchIndex = linkedIndex != -1
        ? linkedIndex
        : _libraryItems.indexWhere((item) {
            if (item.type != goal.type ||
                _libraryTitleKey(item.title) != normalizedTitle ||
                item.linkedGoalId != null) {
              return false;
            }
            if (goal.isCompleted) {
              return item.status == LibraryItemStatus.completed &&
                  item.completedDate?.year == goal.targetYear;
            }
            return item.status != LibraryItemStatus.completed;
          });

    if (matchIndex != -1) {
      final item = _libraryItems[matchIndex];
      final status = goal.isCompleted
          ? LibraryItemStatus.completed
          : reopenAsPending
              ? LibraryItemStatus.pending
              : item.status == LibraryItemStatus.inProgress
                  ? LibraryItemStatus.inProgress
                  : LibraryItemStatus.pending;
      final completedDate = status == LibraryItemStatus.completed
          ? item.completedDate ?? logicalDate()
          : null;
      final synced = _libraryItemFromGoal(
        goal,
        item.id,
        status,
        completedDate,
        item.rating,
        item.createdAt,
        now,
      );
      _libraryItems[matchIndex] = synced;
      _libraryGoals[goalIndex] = goal.copyWith(
        status: status == LibraryItemStatus.completed
            ? LibraryGoalStatus.completed
            : LibraryGoalStatus.pending,
        linkedLibraryItemId: synced.id,
        updatedAt: now,
      );
      return true;
    }

    final status = goal.isCompleted
        ? LibraryItemStatus.completed
        : LibraryItemStatus.pending;
    final item = _libraryItemFromGoal(
      goal,
      _id('library'),
      status,
      status == LibraryItemStatus.completed ? logicalDate() : null,
      null,
      now,
      now,
    );
    _libraryItems.add(item);
    _libraryGoals[goalIndex] = goal.copyWith(
      linkedLibraryItemId: item.id,
      updatedAt: now,
    );
    return true;
  }

  bool _syncCompletedLibraryGoalsIntoItems() {
    var changed = false;
    for (final goal in List<LibraryGoal>.of(_libraryGoals)) {
      final linked = goal.linkedLibraryItemId == null
          ? null
          : _libraryItems.cast<LibraryItem?>().firstWhere(
                (item) => item?.id == goal.linkedLibraryItemId,
                orElse: () => null,
              );
      if (linked == null || linked.linkedGoalId != goal.id) {
        changed = _syncLibraryItemFromGoal(goal, DateTime.now()) || changed;
      }
    }
    changed = _deduplicateLibraryItems() || changed;
    return changed;
  }

  LibraryItem _libraryItemFromGoal(
    LibraryGoal goal,
    String itemId,
    LibraryItemStatus status,
    DateTime? completedDate,
    double? rating,
    DateTime createdAt,
    DateTime updatedAt,
  ) {
    return LibraryItem(
      id: itemId,
      type: goal.type,
      title: goal.title.trim(),
      status: status,
      completedDate: completedDate,
      coverUrl: goal.coverUrl,
      rating: rating,
      note: goal.note?.trim().isEmpty == true ? null : goal.note?.trim(),
      platform: goal.platform,
      developer: goal.developer,
      author: goal.author,
      mediaType: goal.mediaType,
      releaseYear: goal.releaseYear,
      creatorOrDirector: goal.creatorOrDirector,
      genre: goal.genre,
      format: goal.format,
      duration: goal.duration,
      pages: goal.pages,
      country: goal.country,
      linkedGoalId: goal.id,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  void _syncLibraryGoalFromItem(LibraryItem item, DateTime now) {
    final itemYear = item.completedDate?.year;
    final goalIndex = _libraryGoals.indexWhere(
      (goal) =>
          goal.id == item.linkedGoalId ||
          (goal.linkedLibraryItemId == null &&
              goal.type == item.type &&
              _libraryTitleKey(goal.title) == _libraryTitleKey(item.title) &&
              (item.status != LibraryItemStatus.completed ||
                  goal.targetYear == itemYear)),
    );
    if (goalIndex == -1) {
      return;
    }
    final goal = _libraryGoals[goalIndex];
    _libraryGoals[goalIndex] = goal.copyWith(
      type: item.type,
      title: item.title,
      status: item.status == LibraryItemStatus.completed
          ? LibraryGoalStatus.completed
          : LibraryGoalStatus.pending,
      linkedLibraryItemId: item.id,
      coverUrl: item.coverUrl,
      clearCoverUrl: item.coverUrl == null,
      note: item.note,
      clearNote: item.note == null,
      platform: item.platform,
      clearPlatform: item.platform == null,
      developer: item.developer,
      clearDeveloper: item.developer == null,
      author: item.author,
      clearAuthor: item.author == null,
      mediaType: item.mediaType,
      clearMediaType: item.mediaType == null,
      releaseYear: item.releaseYear,
      clearReleaseYear: item.releaseYear == null,
      creatorOrDirector: item.creatorOrDirector,
      clearCreatorOrDirector: item.creatorOrDirector == null,
      genre: item.genre,
      clearGenre: item.genre == null,
      format: item.format,
      clearFormat: item.format == null,
      duration: item.duration,
      clearDuration: item.duration == null,
      pages: item.pages,
      clearPages: item.pages == null,
      country: item.country,
      clearCountry: item.country == null,
      updatedAt: now,
    );
    final itemIndex = _libraryItems.indexWhere((value) => value.id == item.id);
    if (itemIndex != -1 && _libraryItems[itemIndex].linkedGoalId != goal.id) {
      _libraryItems[itemIndex] = _libraryItems[itemIndex].copyWith(
        linkedGoalId: goal.id,
        updatedAt: now,
      );
    }
  }

  bool _deduplicateLibraryItems() {
    var changed = false;
    for (var i = 0; i < _libraryItems.length; i++) {
      var base = _libraryItems[i];
      for (var j = _libraryItems.length - 1; j > i; j--) {
        final candidate = _libraryItems[j];
        if (!_isSameLibraryEntry(base, candidate)) {
          continue;
        }
        final merged = _mergeLibraryItems(base, candidate);
        _libraryItems[i] = merged;
        base = merged;
        for (var goalIndex = 0; goalIndex < _libraryGoals.length; goalIndex++) {
          final goal = _libraryGoals[goalIndex];
          if (goal.linkedLibraryItemId == candidate.id ||
              goal.linkedLibraryItemId == merged.id) {
            _libraryGoals[goalIndex] =
                goal.copyWith(linkedLibraryItemId: merged.id);
          }
        }
        _libraryItems.removeAt(j);
        changed = true;
      }
    }
    return changed;
  }

  bool _isSameLibraryEntry(LibraryItem left, LibraryItem right) {
    if (left.type != right.type ||
        _libraryTitleKey(left.title) != _libraryTitleKey(right.title)) {
      return false;
    }
    if (left.linkedGoalId != null &&
        right.linkedGoalId != null &&
        left.linkedGoalId != right.linkedGoalId) {
      return false;
    }
    if (left.status == LibraryItemStatus.completed ||
        right.status == LibraryItemStatus.completed) {
      return left.status == LibraryItemStatus.completed &&
          right.status == LibraryItemStatus.completed &&
          left.completedDate?.year == right.completedDate?.year;
    }
    return true;
  }

  LibraryItem _mergeLibraryItems(LibraryItem keeper, LibraryItem incoming) {
    final preferIncoming = incoming.linkedGoalId != null;
    final primary = preferIncoming ? incoming : keeper;
    final secondary = preferIncoming ? keeper : incoming;
    final status = incoming.status == LibraryItemStatus.completed
        ? LibraryItemStatus.completed
        : primary.status == LibraryItemStatus.inProgress ||
                secondary.status == LibraryItemStatus.inProgress
            ? LibraryItemStatus.inProgress
            : primary.status;
    final primaryDate = primary.completedDate;
    final secondaryDate = secondary.completedDate;
    return primary.copyWith(
      id: keeper.id,
      title: primary.title.trim().isEmpty ? secondary.title : primary.title,
      status: status,
      completedDate: status == LibraryItemStatus.completed
          ? primaryDate == null
              ? secondaryDate
              : secondaryDate == null || primaryDate.isBefore(secondaryDate)
                  ? primaryDate
                  : secondaryDate
          : null,
      clearCompletedDate: status != LibraryItemStatus.completed,
      coverUrl: primary.coverUrl ?? secondary.coverUrl,
      externalUrl: primary.externalUrl ?? secondary.externalUrl,
      rating: primary.rating ?? secondary.rating,
      note: primary.note ?? secondary.note,
      platform: primary.platform ?? secondary.platform,
      developer: primary.developer ?? secondary.developer,
      author: primary.author ?? secondary.author,
      mediaType: primary.mediaType ?? secondary.mediaType,
      releaseYear: primary.releaseYear ?? secondary.releaseYear,
      creatorOrDirector:
          primary.creatorOrDirector ?? secondary.creatorOrDirector,
      genre: primary.genre ?? secondary.genre,
      format: primary.format ?? secondary.format,
      duration: primary.duration ?? secondary.duration,
      pages: primary.pages ?? secondary.pages,
      country: primary.country ?? secondary.country,
      universeName: primary.universeName ?? secondary.universeName,
      collectionName: primary.collectionName ?? secondary.collectionName,
      collectionNumber: primary.collectionNumber ?? secondary.collectionNumber,
      showCollectionNumber:
          primary.showCollectionNumber || secondary.showCollectionNumber,
      rewatchCount: primary.rewatchCount > secondary.rewatchCount
          ? primary.rewatchCount
          : secondary.rewatchCount,
      seasonCount: primary.seasonCount ?? secondary.seasonCount,
      nextSeasonConfirmed:
          primary.nextSeasonConfirmed || secondary.nextSeasonConfirmed,
      publicationStatus:
          primary.publicationStatus ?? secondary.publicationStatus,
      linkedGoalId: primary.linkedGoalId ?? secondary.linkedGoalId,
      reading: primary.reading?.merge(secondary.reading) ?? secondary.reading,
      createdAt: keeper.createdAt.isBefore(incoming.createdAt)
          ? keeper.createdAt
          : incoming.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  String _libraryTitleKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+', unicode: true), '');
  }

  void toggleLibraryGoalFavorite(String goalId) {
    final index = _libraryGoals.indexWhere((goal) => goal.id == goalId);
    if (index == -1) {
      return;
    }
    final goal = _libraryGoals[index];
    _libraryGoals[index] = goal.copyWith(
      isFavorite: !goal.isFavorite,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  bool _isDemoLibraryItem(LibraryItem item) {
    return const <String>{
      'library-game-prey',
      'library-game-ffx',
      'library-game-silksong',
      'library-game-dragon-age',
      'library-game-control',
      'library-book-priorato',
      'library-book-frankenstein',
      'library-book-orgullo',
      'library-book-mala-costumbre',
      'library-book-entre-fuegos',
      'library-film-godfather',
      'library-film-28-days',
      'library-film-sinners',
      'library-film-shawshank',
      'library-film-martian',
    }.contains(item.id);
  }
}
