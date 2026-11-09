part of 'todo_workspace.dart';

extension TodoWorkspaceMiniaturas on TodoWorkspace {
  MiniatureKit? miniatureKitById(String id) {
    for (final kit in _miniatureKits) {
      if (kit.id == id) return kit;
    }
    return null;
  }

  /// Crea una caja con [modelCount] figuras sin montar.
  MiniatureKit createMiniatureKit({
    required String name,
    String game = '',
    String faction = '',
    int modelCount = 1,
    String note = '',
    String externalUrl = '',
  }) {
    final now = DateTime.now();
    final id = _id('miniature');
    final total = modelCount.clamp(1, 200);
    final kit = MiniatureKit(
      id: id,
      name: name.trim(),
      game: game.trim(),
      faction: faction.trim(),
      note: note.trim(),
      externalUrl: externalUrl.trim(),
      models: [
        for (var index = 0; index < total; index++)
          MiniatureModel(
            id: '$id-${index + 1}',
            name: 'Miniatura ${index + 1}',
          ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    _miniatureKits.add(kit);
    _commit();
    return kit;
  }

  void _replaceMiniatureKit(
    String id,
    MiniatureKit Function(MiniatureKit kit) change,
  ) {
    final index = _miniatureKits.indexWhere((kit) => kit.id == id);
    if (index == -1) return;
    _miniatureKits[index] =
        change(_miniatureKits[index]).copyWith(updatedAt: DateTime.now());
    _commit();
  }

  void updateMiniatureKitDetails(
    String id, {
    required String name,
    required String game,
    required String faction,
    required String note,
    required String externalUrl,
  }) {
    _replaceMiniatureKit(
      id,
      (kit) => kit.copyWith(
        name: name.trim(),
        game: game.trim(),
        faction: faction.trim(),
        note: note.trim(),
        externalUrl: externalUrl.trim(),
      ),
    );
  }

  void setMiniatureModelStatus(
    String kitId,
    String modelId,
    MiniatureStatus status,
  ) {
    _replaceMiniatureKit(
      kitId,
      (kit) => kit.copyWith(models: [
        for (final model in kit.models)
          model.id == modelId ? model.copyWith(status: status) : model,
      ]),
    );
  }

  void setAllMiniatureModelsStatus(String kitId, MiniatureStatus status) {
    _replaceMiniatureKit(
      kitId,
      (kit) => kit.copyWith(models: [
        for (final model in kit.models) model.copyWith(status: status),
      ]),
    );
  }

  void renameMiniatureModel(String kitId, String modelId, String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    _replaceMiniatureKit(
      kitId,
      (kit) => kit.copyWith(models: [
        for (final model in kit.models)
          model.id == modelId ? model.copyWith(name: clean) : model,
      ]),
    );
  }

  void addMiniatureModel(String kitId) {
    _replaceMiniatureKit(kitId, (kit) {
      final number = kit.models.length + 1;
      return kit.copyWith(models: [
        ...kit.models,
        MiniatureModel(
          id: '${kit.id}-${DateTime.now().microsecondsSinceEpoch}',
          name: 'Miniatura $number',
        ),
      ]);
    });
  }

  void removeMiniatureModel(String kitId, String modelId) {
    _replaceMiniatureKit(
      kitId,
      (kit) => kit.copyWith(
        models: kit.models.where((model) => model.id != modelId).toList(),
      ),
    );
  }

  void toggleMiniaturePaintOwned(String kitId, int index) {
    _replaceMiniatureKit(kitId, (kit) {
      if (index < 0 || index >= kit.paints.length) return kit;
      final paints = kit.paints.toList();
      paints[index] = paints[index].copyWith(owned: !paints[index].owned);
      return kit.copyWith(paints: paints);
    });
  }

  void addMiniaturePaint(String kitId, String name, String kind) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    _replaceMiniatureKit(
      kitId,
      (kit) => kit.copyWith(paints: [
        ...kit.paints,
        MiniaturePaint(name: clean, kind: kind.trim()),
      ]),
    );
  }

  void removeMiniaturePaint(String kitId, int index) {
    _replaceMiniatureKit(kitId, (kit) {
      if (index < 0 || index >= kit.paints.length) return kit;
      return kit.copyWith(paints: kit.paints.toList()..removeAt(index));
    });
  }

  /// Guarda un paso de la guía: lo sustituye si [index] existe o lo añade al
  /// final si es nulo.
  void saveMiniatureGuideStep(
    String kitId,
    MiniaturePaintStep step, {
    int? index,
  }) {
    _replaceMiniatureKit(kitId, (kit) {
      final guide = kit.guide.toList();
      if (index != null && index >= 0 && index < guide.length) {
        guide[index] = step;
      } else {
        guide.add(step);
      }
      return kit.copyWith(guide: guide);
    });
  }

  void toggleMiniatureGuideStepDone(String kitId, int index) {
    _replaceMiniatureKit(kitId, (kit) {
      if (index < 0 || index >= kit.guide.length) return kit;
      final guide = kit.guide.toList();
      guide[index] = guide[index].copyWith(done: !guide[index].done);
      return kit.copyWith(guide: guide);
    });
  }

  void toggleMiniatureAssemblyStepDone(String kitId, int index) {
    _replaceMiniatureKit(kitId, (kit) {
      if (index < 0 || index >= kit.assembly.length) return kit;
      final assembly = kit.assembly.toList();
      assembly[index] = assembly[index].copyWith(done: !assembly[index].done);
      return kit.copyWith(assembly: assembly);
    });
  }

  void removeMiniatureGuideStep(String kitId, int index) {
    _replaceMiniatureKit(kitId, (kit) {
      if (index < 0 || index >= kit.guide.length) return kit;
      return kit.copyWith(guide: kit.guide.toList()..removeAt(index));
    });
  }

  void moveMiniatureGuideStep(String kitId, int index, int offset) {
    _replaceMiniatureKit(kitId, (kit) {
      final target = index + offset;
      if (index < 0 ||
          index >= kit.guide.length ||
          target < 0 ||
          target >= kit.guide.length) {
        return kit;
      }
      final guide = kit.guide.toList();
      final step = guide.removeAt(index);
      guide.insert(target, step);
      return kit.copyWith(guide: guide);
    });
  }

  Future<String> miniatureAssetAbsolutePath(String relativePath) =>
      _miniatureAssets.absolutePath(relativePath);

  Future<void> importMiniatureKitImage(String kitId, String sourcePath) async {
    if (miniatureKitById(kitId) == null) {
      throw StateError('No se encuentra la caja de miniaturas.');
    }
    final imported = await _miniatureAssets.importImage(kitId, sourcePath);
    final previous = miniatureKitById(kitId);
    if (previous == null) return;
    _replaceMiniatureKit(
      kitId,
      (kit) => kit.copyWith(
        imagePath: imported.imagePath,
        thumbnailPath: imported.thumbnailPath,
      ),
    );
    for (final path in {previous.imagePath, previous.thumbnailPath}) {
      if (path.isNotEmpty &&
          path != imported.imagePath &&
          path != imported.thumbnailPath) {
        await _miniatureAssets.deleteAsset(path);
      }
    }
  }

  /// Añade una foto propia de las miniaturas pintadas.
  Future<void> addMiniaturePhoto(
    String kitId,
    String sourcePath, {
    String caption = '',
  }) async {
    if (miniatureKitById(kitId) == null) {
      throw StateError('No se encuentra la caja de miniaturas.');
    }
    final photoId = _id('miniature-photo');
    final imported = await _miniatureAssets.importImage(photoId, sourcePath);
    _replaceMiniatureKit(
      kitId,
      (kit) => kit.copyWith(photos: [
        ...kit.photos,
        MiniaturePhoto(
          id: photoId,
          imagePath: imported.imagePath,
          thumbnailPath: imported.thumbnailPath,
          caption: caption.trim(),
          createdAt: DateTime.now(),
        ),
      ]),
    );
  }

  void updateMiniaturePhotoCaption(
    String kitId,
    String photoId,
    String caption,
  ) {
    _replaceMiniatureKit(
      kitId,
      (kit) => kit.copyWith(photos: [
        for (final photo in kit.photos)
          photo.id == photoId ? photo.copyWith(caption: caption.trim()) : photo,
      ]),
    );
  }

  Future<void> removeMiniaturePhoto(String kitId, String photoId) async {
    final kit = miniatureKitById(kitId);
    if (kit == null) return;
    MiniaturePhoto? removed;
    for (final photo in kit.photos) {
      if (photo.id == photoId) removed = photo;
    }
    if (removed == null) return;
    _replaceMiniatureKit(
      kitId,
      (kit) => kit.copyWith(
        photos: kit.photos.where((photo) => photo.id != photoId).toList(),
      ),
    );
    for (final path in {removed.imagePath, removed.thumbnailPath}) {
      if (path.isNotEmpty) await _miniatureAssets.deleteAsset(path);
    }
  }

  void deleteMiniatureKit(String id) {
    final kit = miniatureKitById(id);
    if (kit == null) return;
    _miniatureKits.removeWhere((item) => item.id == id);
    _commit();
    final paths = <String>{
      kit.imagePath,
      kit.thumbnailPath,
      kit.coverPath,
      kit.heroPath,
      ...kit.gallery,
      for (final spin in kit.spins)
        for (var fila = 0; fila < spin.rows; fila++)
          for (var columna = 0; columna < spin.cols; columna++)
            spin.frame(fila, columna),
      for (final step in kit.assembly) step.imagePath,
      for (final photo in kit.photos) ...[photo.imagePath, photo.thumbnailPath],
    };
    for (final path in paths) {
      if (path.isNotEmpty) unawaited(_miniatureAssets.deleteAsset(path));
    }
  }
}
