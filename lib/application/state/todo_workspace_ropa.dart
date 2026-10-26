part of 'todo_workspace.dart';

extension TodoWorkspaceRopa on TodoWorkspace {
  WardrobeItem? wardrobeItemById(String id) {
    for (final item in _wardrobeItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<String> wardrobeImageAbsolutePath(WardrobeItem item,
      {bool thumbnail = true}) {
    final path = thumbnail && item.thumbnailPath.isNotEmpty
        ? item.thumbnailPath
        : item.imagePath;
    return _wardrobeAssets.absolutePath(path);
  }

  Future<String> wardrobeOutfitRenderAbsolutePath(WardrobeOutfit outfit) =>
      _wardrobeAssets.absolutePath(outfit.renderImagePath);

  WardrobeItem createWardrobeItem({
    required String name,
    required String category,
    String imagePath = '',
    String thumbnailPath = '',
    String imageSha256 = '',
    List<String> colors = const <String>[],
    String material = '',
    List<String> seasons = const <String>[],
    List<String> occasions = const <String>[],
    List<String> tags = const <String>[],
    double? price,
    bool favorite = false,
    WardrobeLaundryStatus laundryStatus = WardrobeLaundryStatus.available,
  }) {
    final instant = DateTime.now();
    final item = WardrobeItem(
      id: _id('wardrobe-item'),
      name: name.trim().isEmpty ? 'Prenda sin nombre' : name.trim(),
      category: WardrobeTaxonomy.normalizeCategory(category),
      imagePath: imagePath,
      thumbnailPath: thumbnailPath,
      imageSha256: imageSha256,
      colors: WardrobeTaxonomy.normalizeColors(colors),
      material: material.trim(),
      seasons: WardrobeTaxonomy.normalizeSeasons(seasons),
      occasions: WardrobeTaxonomy.normalizeOccasions(occasions),
      tags: tags,
      favorite: favorite,
      laundryStatus: laundryStatus,
      price: price,
      createdAt: instant,
      updatedAt: instant,
    );
    _wardrobeItems.add(item);
    _commit();
    return item;
  }

  void updateWardrobeItem(
    String id, {
    String? name,
    String? category,
    List<String>? colors,
    String? material,
    List<String>? seasons,
    List<String>? occasions,
    List<String>? tags,
    bool? favorite,
    WardrobeLaundryStatus? laundryStatus,
    double? price,
    bool clearPrice = false,
  }) {
    final index = _wardrobeItems.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _wardrobeItems[index] = _wardrobeItems[index].copyWith(
      name: name?.trim(),
      category: category == null
          ? null
          : WardrobeTaxonomy.normalizeCategory(category),
      colors: colors == null ? null : WardrobeTaxonomy.normalizeColors(colors),
      material: material?.trim(),
      seasons:
          seasons == null ? null : WardrobeTaxonomy.normalizeSeasons(seasons),
      occasions: occasions == null
          ? null
          : WardrobeTaxonomy.normalizeOccasions(occasions),
      tags: tags,
      favorite: favorite,
      laundryStatus: laundryStatus,
      price: price,
      clearPrice: clearPrice,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  Future<WardrobeItem> saveWardrobeItem({
    WardrobeItem? existing,
    required String name,
    required String category,
    required String material,
    required List<String> colors,
    required List<String> seasons,
    required List<String> occasions,
    required List<String> tags,
    required WardrobeLaundryStatus laundryStatus,
    required bool favorite,
    double? price,
    String? sourceImagePath,
    Uint8List? sourceImageBytes,
    bool removeImage = false,
  }) async {
    final instant = DateTime.now();
    final itemId = existing?.id ?? _id('wardrobe-item');
    WardrobeStoredAsset? imported;
    if (sourceImageBytes != null && sourceImageBytes.isNotEmpty) {
      imported = await _wardrobeAssets.importItemImageBytes(
        itemId: itemId,
        bytes: sourceImageBytes,
        category: category,
      );
    } else if (sourceImagePath != null && sourceImagePath.trim().isNotEmpty) {
      imported = await _wardrobeAssets.importItemImage(
        itemId: itemId,
        sourcePath: sourceImagePath,
        category: category,
      );
    }

    final previousIndex = existing == null
        ? -1
        : _wardrobeItems.indexWhere((item) => item.id == existing.id);
    if (existing != null && previousIndex == -1) {
      if (imported != null) {
        await _deleteWardrobeStoredAsset(imported);
      }
      throw StateError('No se encuentra la prenda.');
    }

    final normalizedTags = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    final imagePath =
        imported?.imagePath ?? (removeImage ? '' : existing?.imagePath ?? '');
    final thumbnailPath = imported?.thumbnailPath ??
        (removeImage ? '' : existing?.thumbnailPath ?? '');
    final imageSha256 =
        imported?.sha256 ?? (removeImage ? '' : existing?.imageSha256 ?? '');
    final saved = WardrobeItem(
      id: itemId,
      name: name.trim(),
      category: WardrobeTaxonomy.normalizeCategory(category),
      imagePath: imagePath,
      thumbnailPath: thumbnailPath,
      imageSha256: imageSha256,
      colors: WardrobeTaxonomy.normalizeColors(colors),
      material: material.trim(),
      seasons: WardrobeTaxonomy.normalizeSeasons(seasons),
      occasions: WardrobeTaxonomy.normalizeOccasions(occasions),
      tags: normalizedTags,
      favorite: favorite,
      archived: existing?.archived ?? false,
      laundryStatus: laundryStatus,
      useCount: existing?.useCount ?? 0,
      lastUsedAt: existing?.lastUsedAt,
      price: price,
      createdAt: existing?.createdAt ?? instant,
      updatedAt: instant,
    );

    if (existing == null) {
      _wardrobeItems.add(saved);
    } else {
      _wardrobeItems[previousIndex] = saved;
    }
    _notifyChanged();
    try {
      await _persistWardrobeLocally();
    } catch (_) {
      if (existing == null) {
        _wardrobeItems.removeWhere((item) => item.id == itemId);
      } else {
        _wardrobeItems[previousIndex] = existing;
      }
      if (imported != null) await _deleteWardrobeStoredAsset(imported);
      _notifyChanged();
      rethrow;
    }

    if (existing != null && (imported != null || removeImage)) {
      for (final path in <String>[
        existing.imagePath,
        existing.thumbnailPath,
      ]) {
        if (path.isNotEmpty &&
            path != saved.imagePath &&
            path != saved.thumbnailPath) {
          await _wardrobeAssets.deleteAsset(path);
        }
      }
    }
    return saved;
  }

  Future<void> _deleteWardrobeStoredAsset(WardrobeStoredAsset asset) async {
    await _wardrobeAssets.deleteAsset(asset.imagePath);
    await _wardrobeAssets.deleteAsset(asset.thumbnailPath);
  }

  Future<void> _persistWardrobeLocally() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    await _saveSnapshotTracked(_buildSnapshot());
    _syncMetadata = _syncMetadata.copyWith(
      deviceId: _syncMetadata.deviceId.isNotEmpty
          ? _syncMetadata.deviceId
          : _cloudService.currentDeviceId,
      pendingLocalChanges: true,
    );
    await _store.saveSyncMetadata(_syncMetadata);
    _lastSavedAt = DateTime.now();
    _notifyChanged();
    if (_cloudService.isAuthenticated && _syncConflict == null) {
      unawaited(syncWithCloud());
    }
  }

  void toggleWardrobeFavorite(String id) {
    final index = _wardrobeItems.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final item = _wardrobeItems[index];
    _wardrobeItems[index] = item.copyWith(
      favorite: !item.favorite,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void setWardrobeLaundryStatus(
    Iterable<String> ids,
    WardrobeLaundryStatus status,
  ) {
    final selected = ids.toSet();
    for (var index = 0; index < _wardrobeItems.length; index++) {
      if (selected.contains(_wardrobeItems[index].id)) {
        _wardrobeItems[index] = _wardrobeItems[index].copyWith(
          laundryStatus: status,
          updatedAt: DateTime.now(),
        );
      }
    }
    _commit();
  }

  void archiveWardrobeItem(String id) {
    final index = _wardrobeItems.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _wardrobeItems[index] = _wardrobeItems[index].copyWith(
      archived: true,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void deleteWardrobeItem(String id) {
    _wardrobeItems.removeWhere((item) => item.id == id);
    for (var index = 0; index < _wardrobeOutfits.length; index++) {
      final outfit = _wardrobeOutfits[index];
      _wardrobeOutfits[index] = WardrobeOutfit(
        id: outfit.id,
        name: outfit.name,
        itemIds: outfit.itemIds.where((itemId) => itemId != id).toList(),
        occasion: outfit.occasion,
        tags: outfit.tags,
        renderImagePath: outfit.renderImagePath,
        createdAt: outfit.createdAt,
      );
    }
    _wardrobePlanEntries.removeWhere(
        (entry) => entry.itemIds.length == 1 && entry.itemIds.single == id);
    for (var index = 0; index < _wardrobePackingLists.length; index++) {
      final list = _wardrobePackingLists[index];
      _wardrobePackingLists[index] = list.copyWith(
        entries: list.entries.where((entry) => entry.itemId != id).toList(),
        discardedItemIds:
            list.discardedItemIds.where((itemId) => itemId != id).toList(),
      );
    }
    _commit();
  }

  WardrobeOutfit createWardrobeOutfit({
    required String name,
    required List<String> itemIds,
    String occasion = '',
    List<String> tags = const <String>[],
  }) {
    final outfit = WardrobeOutfit(
      id: _id('wardrobe-outfit'),
      name: name.trim().isEmpty ? 'Conjunto sin nombre' : name.trim(),
      itemIds:
          itemIds.where((id) => wardrobeItemById(id) != null).toSet().toList(),
      occasion: occasion.trim(),
      tags: tags,
      createdAt: DateTime.now(),
    );
    _wardrobeOutfits.add(outfit);
    _commit();
    return outfit;
  }

  WardrobeOutfit updateWardrobeOutfit({
    required String id,
    required String name,
    required List<String> itemIds,
    String occasion = '',
    List<String> tags = const <String>[],
  }) {
    final index = _wardrobeOutfits.indexWhere((outfit) => outfit.id == id);
    if (index == -1) throw StateError('No se encuentra el conjunto.');
    final updated = _wardrobeOutfits[index].copyWith(
      name: name.trim().isEmpty ? 'Conjunto sin nombre' : name.trim(),
      itemIds: itemIds
          .where((itemId) => wardrobeItemById(itemId) != null)
          .toSet()
          .toList(),
      occasion: occasion.trim(),
      tags: tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(),
    );
    _wardrobeOutfits[index] = updated;
    _commit();
    return updated;
  }

  void deleteWardrobeOutfit(String id) {
    final outfit =
        _wardrobeOutfits.where((value) => value.id == id).firstOrNull;
    _wardrobeOutfits.removeWhere((outfit) => outfit.id == id);
    _wardrobePlanEntries.removeWhere((entry) => entry.outfitId == id);
    _commit();
    if (outfit != null && outfit.renderImagePath.isNotEmpty) {
      unawaited(_wardrobeAssets.deleteAsset(outfit.renderImagePath));
    }
  }

  Future<void> importWardrobeOutfitRender(
      String outfitId, String sourcePath) async {
    if (!_wardrobeOutfits.any((outfit) => outfit.id == outfitId)) {
      throw StateError('No se encuentra el conjunto.');
    }
    await _setWardrobeOutfitRender(
      outfitId,
      await _wardrobeAssets.importOutfitRender(outfitId, sourcePath),
    );
  }

  Future<void> importWardrobeOutfitRenderBytes(
    String outfitId,
    Uint8List bytes,
  ) async {
    if (!_wardrobeOutfits.any((outfit) => outfit.id == outfitId)) {
      throw StateError('No se encuentra el conjunto.');
    }
    await _setWardrobeOutfitRender(
      outfitId,
      await _wardrobeAssets.importOutfitRenderBytes(outfitId, bytes),
    );
  }

  Future<void> _setWardrobeOutfitRender(
    String outfitId,
    String relativePath,
  ) async {
    final index =
        _wardrobeOutfits.indexWhere((outfit) => outfit.id == outfitId);
    if (index == -1) throw StateError('No se encuentra el conjunto.');
    final previous = _wardrobeOutfits[index].renderImagePath;
    _wardrobeOutfits[index] =
        _wardrobeOutfits[index].copyWith(renderImagePath: relativePath);
    _commit();
    if (previous.isNotEmpty && previous != relativePath) {
      await _wardrobeAssets.deleteAsset(previous);
    }
  }

  Future<void> clearWardrobeOutfitRender(String outfitId) async {
    final index =
        _wardrobeOutfits.indexWhere((outfit) => outfit.id == outfitId);
    if (index == -1) return;
    final previous = _wardrobeOutfits[index].renderImagePath;
    _wardrobeOutfits[index] =
        _wardrobeOutfits[index].copyWith(renderImagePath: '');
    _commit();
    if (previous.isNotEmpty) await _wardrobeAssets.deleteAsset(previous);
  }

  WardrobeWearLog recordWardrobeWear({
    required DateTime date,
    required List<String> itemIds,
    String? outfitId,
    String label = '',
  }) {
    final ids =
        itemIds.where((id) => wardrobeItemById(id) != null).toSet().toList();
    final log = WardrobeWearLog(
      id: _id('wardrobe-wear'),
      date: date,
      itemIds: ids,
      outfitId: outfitId,
      label: label.trim(),
    );
    _wardrobeWearLogs.add(log);
    for (var index = 0; index < _wardrobeItems.length; index++) {
      final item = _wardrobeItems[index];
      if (ids.contains(item.id)) {
        _wardrobeItems[index] = item.copyWith(
          useCount: item.useCount + 1,
          lastUsedAt: date,
          updatedAt: DateTime.now(),
        );
      }
    }
    _commit();
    return log;
  }

  WardrobePlanEntry setWardrobePlan({
    required DateTime date,
    required List<String> itemIds,
    String? outfitId,
    WardrobeWeather weather = WardrobeWeather.mild,
    String occasion = '',
  }) {
    _wardrobePlanEntries.removeWhere((entry) => _sameDay(entry.date, date));
    final entry = WardrobePlanEntry(
      id: _id('wardrobe-plan'),
      date: date,
      itemIds: itemIds,
      outfitId: outfitId,
      weather: weather,
      occasion: occasion.trim(),
    );
    _wardrobePlanEntries.add(entry);
    _commit();
    return entry;
  }

  WardrobePackingList createWardrobePackingList({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final list = WardrobePackingList(
      id: _id('wardrobe-packing'),
      name: name.trim().isEmpty ? 'Nuevo viaje' : name.trim(),
      startDate: startDate,
      endDate: endDate,
    );
    _wardrobePackingLists.add(list);
    _commit();
    return list;
  }

  WardrobePackingList? duplicateWardrobePackingList(
    String listId, {
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    bool keepDiscarded = false,
  }) {
    final original =
        _wardrobePackingLists.where((list) => list.id == listId).firstOrNull;
    if (original == null) return null;
    if (endDate.isBefore(startDate)) {
      throw ArgumentError('La fecha de fin debe ser posterior al inicio.');
    }
    final copy = WardrobePackingList(
      id: _id('wardrobe-packing'),
      name: name.trim().isEmpty ? '${original.name} · otro viaje' : name.trim(),
      startDate: startDate,
      endDate: endDate,
      entries: original.entries
          .map((entry) => entry.copyWith(packed: false))
          .toList(),
      discardedItemIds: keepDiscarded
          ? List<String>.from(original.discardedItemIds)
          : const [],
    );
    _wardrobePackingLists.add(copy);
    _commit();
    return copy;
  }

  void addWardrobePackingItem(String listId, String itemId,
      {int quantity = 1}) {
    final index = _wardrobePackingLists.indexWhere((list) => list.id == listId);
    if (index == -1 ||
        wardrobeItemById(itemId) == null ||
        _wardrobePackingLists[index]
            .entries
            .any((entry) => entry.itemId == itemId)) {
      return;
    }
    final list = _wardrobePackingLists[index];
    final entries = List<WardrobePackingEntry>.from(list.entries)
      ..add(WardrobePackingEntry(itemId: itemId, quantity: max(1, quantity)));
    _wardrobePackingLists[index] = list.copyWith(
      entries: entries,
      discardedItemIds:
          list.discardedItemIds.where((id) => id != itemId).toList(),
    );
    _commit();
  }

  void removeWardrobePackingItem(String listId, String itemId) {
    final index = _wardrobePackingLists.indexWhere((list) => list.id == listId);
    if (index == -1) return;
    final list = _wardrobePackingLists[index];
    if (!list.entries.any((entry) => entry.itemId == itemId)) return;
    _wardrobePackingLists[index] = list.copyWith(
      entries: list.entries.where((entry) => entry.itemId != itemId).toList(),
    );
    _commit();
  }

  int addWardrobeOutfitToPackingList(String listId, String outfitId) {
    final index = _wardrobePackingLists.indexWhere((list) => list.id == listId);
    final outfit =
        _wardrobeOutfits.where((outfit) => outfit.id == outfitId).firstOrNull;
    if (index == -1 || outfit == null) return 0;
    final list = _wardrobePackingLists[index];
    final included = list.entries.map((entry) => entry.itemId).toSet();
    final additions = outfit.itemIds
        .toSet()
        .where((id) =>
            !included.contains(id) && wardrobeItemById(id)?.archived == false)
        .toSet();
    if (additions.isEmpty) return 0;
    _wardrobePackingLists[index] = list.copyWith(
      entries: [
        ...list.entries,
        ...additions.map((id) => WardrobePackingEntry(itemId: id))
      ],
      discardedItemIds:
          list.discardedItemIds.where((id) => !additions.contains(id)).toList(),
    );
    _commit();
    return additions.length;
  }

  void discardWardrobePackingItem(String listId, String itemId) {
    final index = _wardrobePackingLists.indexWhere((list) => list.id == listId);
    if (index == -1 || wardrobeItemById(itemId) == null) return;
    final list = _wardrobePackingLists[index];
    if (list.discardedItemIds.contains(itemId)) return;
    _wardrobePackingLists[index] = list.copyWith(
      entries: list.entries.where((entry) => entry.itemId != itemId).toList(),
      discardedItemIds: [...list.discardedItemIds, itemId],
    );
    _commit();
  }

  void restoreWardrobePackingItem(String listId, String itemId) {
    final index = _wardrobePackingLists.indexWhere((list) => list.id == listId);
    if (index == -1) return;
    final list = _wardrobePackingLists[index];
    if (!list.discardedItemIds.contains(itemId)) return;
    _wardrobePackingLists[index] = list.copyWith(
      discardedItemIds:
          list.discardedItemIds.where((id) => id != itemId).toList(),
    );
    _commit();
  }

  void toggleWardrobePackingItem(String listId, String itemId) {
    final index = _wardrobePackingLists.indexWhere((list) => list.id == listId);
    if (index == -1) return;
    final list = _wardrobePackingLists[index];
    _wardrobePackingLists[index] = list.copyWith(
      entries: list.entries
          .map((entry) => entry.itemId == itemId
              ? entry.copyWith(packed: !entry.packed)
              : entry)
          .toList(),
    );
    _commit();
  }

  List<WardrobeItem> wardrobeSuggestions({
    WardrobeWeather weather = WardrobeWeather.mild,
    String occasion = '',
    int limit = 8,
  }) {
    final candidates = _wardrobeItems
        .where((item) => !item.archived)
        .where((item) => item.laundryStatus == WardrobeLaundryStatus.available)
        .where((item) =>
            occasion.isEmpty ||
            item.occasions.isEmpty ||
            item.occasions
                .any((value) => value.toLowerCase() == occasion.toLowerCase()))
        .toList();
    int score(WardrobeItem item) {
      var value = item.favorite ? 12 : 0;
      value += max(0, 10 - item.useCount);
      final weatherTag = switch (weather) {
        WardrobeWeather.hot => 'calor',
        WardrobeWeather.mild => 'templado',
        WardrobeWeather.cold => 'frío',
        WardrobeWeather.rain => 'lluvia',
      };
      if (item.tags.map((tag) => tag.toLowerCase()).contains(weatherTag)) {
        value += 15;
      }
      if (item.lastUsedAt == null ||
          DateTime.now().difference(item.lastUsedAt!).inDays > 14) {
        value += 8;
      }
      return value;
    }

    candidates.sort((left, right) => score(right).compareTo(score(left)));
    return candidates.take(limit).toList();
  }

  Future<WardrobeImportBatch> stageWardrobeImportDirectory(String path) async {
    final batch =
        await _wardrobeAssets.stageManifestDirectory(path, wardrobeItems);
    _wardrobeImportBatches.add(batch);
    await _persist();
    return batch;
  }

  void updateWardrobeImportItem(
    String batchId,
    String itemId, {
    String? name,
    String? category,
    List<String>? colors,
    String? material,
    List<String>? seasons,
    List<String>? occasions,
    List<String>? tags,
  }) {
    final batchIndex =
        _wardrobeImportBatches.indexWhere((batch) => batch.id == batchId);
    if (batchIndex == -1) return;
    final batch = _wardrobeImportBatches[batchIndex];
    _wardrobeImportBatches[batchIndex] = batch.copyWith(
      items: batch.items
          .map((item) => item.id == itemId
              ? item.copyWith(
                  name: name,
                  category: category,
                  colors: colors,
                  material: material,
                  seasons: seasons,
                  occasions: occasions,
                  tags: tags)
              : item)
          .toList(),
    );
    _commit();
  }

  Future<int> approveWardrobeImport(String batchId) async {
    final batchIndex =
        _wardrobeImportBatches.indexWhere((batch) => batch.id == batchId);
    if (batchIndex == -1) return 0;
    final batch = _wardrobeImportBatches[batchIndex];
    final assets = await _wardrobeAssets.approveBatch(batch);
    final instant = DateTime.now();
    final createdIds = <String>[];
    try {
      for (final asset in assets) {
        final item = asset.importItem;
        final id = _id('wardrobe-item');
        createdIds.add(id);
        _wardrobeItems.add(WardrobeItem(
          id: id,
          name: item.name,
          category: item.category,
          imagePath: asset.imagePath,
          thumbnailPath: asset.thumbnailPath,
          imageSha256: asset.sha256,
          colors: item.colors,
          material: item.material,
          seasons: item.seasons,
          occasions: item.occasions,
          tags: item.tags,
          createdAt: instant,
          updatedAt: instant,
        ));
      }
      _wardrobeImportBatches[batchIndex] = batch.copyWith(
        status: WardrobeImportStatus.approved,
      );
      await _persist();
      await _wardrobeAssets.deleteImportBatch(batch.id);
      return assets.length;
    } catch (_) {
      _wardrobeItems.removeWhere((item) => createdIds.contains(item.id));
      _wardrobeImportBatches[batchIndex] = batch;
      await _wardrobeAssets.rollbackApprovedAssets(assets);
      rethrow;
    }
  }

  Future<void> discardWardrobeImport(String batchId) async {
    final index =
        _wardrobeImportBatches.indexWhere((batch) => batch.id == batchId);
    if (index == -1) return;
    final batch = _wardrobeImportBatches[index];
    _wardrobeImportBatches[index] =
        batch.copyWith(status: WardrobeImportStatus.discarded);
    await _persist();
    await _wardrobeAssets.deleteImportBatch(batch.id);
  }

  Future<void> reloadWardrobeImports() async {
    final persisted = await _store.load();
    if (persisted == null) return;
    _applySnapshot(persisted);
    _notifyChanged();
  }

  void updateWardrobeDisplaySettings(WardrobeDisplaySettings value) {
    _wardrobeDisplaySettings = value;
    _commit();
  }
}
