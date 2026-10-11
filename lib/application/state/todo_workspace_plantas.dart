part of 'todo_workspace.dart';

extension TodoWorkspacePlantas on TodoWorkspace {
  Plant? plantById(String id) {
    for (final plant in _plants) {
      if (plant.id == id) return plant;
    }
    return null;
  }

  Future<String> plantImageAbsolutePath(
    Plant plant, {
    bool thumbnail = true,
  }) {
    final path = thumbnail && plant.thumbnailPath.isNotEmpty
        ? plant.thumbnailPath
        : plant.imagePath;
    return _plantAssets.absolutePath(path);
  }

  Future<String> plantPhotoAbsolutePath(PlantPhoto photo,
          {bool thumbnail = false}) =>
      _plantAssets
          .absolutePath(thumbnail ? photo.thumbnailPath : photo.imagePath);

  Future<PlantPhoto> addPlantPhoto(
    String id,
    Uint8List bytes, {
    required DateTime takenAt,
    String notes = '',
  }) async {
    if (plantById(id) == null) throw StateError('No se encuentra la planta.');
    final photoId = _id('plant-photo');
    final imported = await _plantAssets.importImageBytes('$id-$photoId', bytes);
    final index = _plants.indexWhere((plant) => plant.id == id);
    if (index == -1) {
      await _plantAssets.deleteAsset(imported.imagePath);
      await _plantAssets.deleteAsset(imported.thumbnailPath);
      throw StateError('La planta ya no está disponible.');
    }
    final photo = PlantPhoto(
        id: photoId,
        takenAt: takenAt,
        imagePath: imported.imagePath,
        thumbnailPath: imported.thumbnailPath,
        imageSha256: imported.sha256,
        notes: notes.trim());
    final photos = [..._plants[index].photos, photo]
      ..sort((left, right) => right.takenAt.compareTo(left.takenAt));
    _plants[index] =
        _plants[index].copyWith(photos: photos, updatedAt: DateTime.now());
    _commit();
    return photo;
  }

  Future<void> removePlantPhoto(String plantId, String photoId) async {
    final index = _plants.indexWhere((plant) => plant.id == plantId);
    if (index == -1) return;
    final plant = _plants[index];
    final photo =
        plant.photos.where((photo) => photo.id == photoId).firstOrNull;
    if (photo == null) return;
    _plants[index] = plant.copyWith(
        photos: plant.photos.where((photo) => photo.id != photoId).toList(),
        updatedAt: DateTime.now());
    _commit();
    await _plantAssets.deleteAsset(photo.imagePath);
    await _plantAssets.deleteAsset(photo.thumbnailPath);
  }

  Plant createPlant({
    required String name,
    required String commonName,
    required String scientificName,
    String cultivar = '',
    String location = '',
    DateTime? acquiredAt,
    String description = '',
    String light = '',
    String watering = '',
    String humidity = '',
    String temperature = '',
    String substrate = '',
    String fertilizing = '',
    String pruning = '',
    String propagation = '',
    String repotting = '',
    String commonProblems = '',
    PlantCatSafety catSafety = PlantCatSafety.unknown,
    String catSafetyNotes = '',
    List<PlantSource> sources = const <PlantSource>[],
    List<PlantCareRoutine> routines = const <PlantCareRoutine>[],
    List<String> tags = const <String>[],
    String notes = '',
  }) {
    final instant = DateTime.now();
    final plant = Plant(
      id: _id('plant'),
      name: name.trim().isEmpty ? 'Planta sin nombre' : name.trim(),
      commonName: commonName.trim(),
      scientificName: scientificName.trim(),
      cultivar: cultivar.trim(),
      location: location.trim(),
      acquiredAt: acquiredAt,
      description: description.trim(),
      light: light.trim(),
      watering: watering.trim(),
      humidity: humidity.trim(),
      temperature: temperature.trim(),
      substrate: substrate.trim(),
      fertilizing: fertilizing.trim(),
      pruning: pruning.trim(),
      propagation: propagation.trim(),
      repotting: repotting.trim(),
      commonProblems: commonProblems.trim(),
      catSafety: catSafety,
      catSafetyNotes: catSafetyNotes.trim(),
      sources: List<PlantSource>.from(sources),
      routines: List<PlantCareRoutine>.from(routines),
      tags: tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(),
      notes: notes.trim(),
      createdAt: instant,
      updatedAt: instant,
    );
    _plants.add(plant);
    _syncPlantCareTasks(plant);
    _commit();
    return plant;
  }

  void updatePlant(Plant updated) {
    final index = _plants.indexWhere((plant) => plant.id == updated.id);
    if (index == -1) return;
    final previous = _plants[index];
    final next = updated.copyWith(
      imagePath: previous.imagePath,
      thumbnailPath: previous.thumbnailPath,
      imageSha256: previous.imageSha256,
      photos: previous.photos,
      updatedAt: DateTime.now(),
    );
    _plants[index] = next;
    _syncPlantCareTasks(next);
    _commit();
  }

  Future<void> importPlantImage(String id, String sourcePath) async {
    if (plantById(id) == null) throw StateError('No se encuentra la planta.');
    await _importPlantStoredImage(
      id,
      await _plantAssets.importImage(id, sourcePath),
    );
  }

  Future<void> importPlantImageBytes(String id, Uint8List bytes) async {
    if (plantById(id) == null) throw StateError('No se encuentra la planta.');
    await _importPlantStoredImage(
      id,
      await _plantAssets.importImageBytes(id, bytes),
    );
  }

  Future<void> _importPlantStoredImage(
    String id,
    PlantImportedImage imported,
  ) async {
    final index = _plants.indexWhere((plant) => plant.id == id);
    if (index == -1) throw StateError('No se encuentra la planta.');
    final previousImage = _plants[index].imagePath;
    final previousThumbnail = _plants[index].thumbnailPath;
    _plants[index] = _plants[index].copyWith(
      imagePath: imported.imagePath,
      thumbnailPath: imported.thumbnailPath,
      imageSha256: imported.sha256,
      updatedAt: DateTime.now(),
    );
    _commit();
    for (final path in <String>[previousImage, previousThumbnail]) {
      if (path.isNotEmpty &&
          path != imported.imagePath &&
          path != imported.thumbnailPath) {
        await _plantAssets.deleteAsset(path);
      }
    }
  }

  void archivePlant(String id, {bool archived = true}) {
    final index = _plants.indexWhere((plant) => plant.id == id);
    if (index == -1) return;
    final next = _plants[index].copyWith(
      archived: archived,
      updatedAt: DateTime.now(),
    );
    _plants[index] = next;
    _syncPlantCareTasks(next);
    _commit();
  }

  void deletePlant(String id) {
    final plant = plantById(id);
    if (plant == null) return;
    _plants.removeWhere((value) => value.id == id);
    _tasks.removeWhere((task) => task.sourcePlantId == id);
    _commit();
    for (final path in <String>[
      plant.imagePath,
      plant.thumbnailPath,
      ...plant.photos.expand((photo) => [photo.imagePath, photo.thumbnailPath])
    ]) {
      if (path.isNotEmpty) unawaited(_plantAssets.deleteAsset(path));
    }
  }

  CategoryModel _ensurePlantsCategory() {
    for (final category in _categories) {
      if (category.name.trim().toLowerCase() == 'plantas') return category;
    }
    const category = CategoryModel(
      id: 'category-plants',
      name: 'Plantas',
      description: 'Cuidados y mantenimiento de las plantas.',
      colorValue: 0xFF4F7A4A,
      icon: Icons.local_florist_rounded,
    );
    _categories.add(category);
    return category;
  }

  void _syncPlantCareTasks(Plant plant) {
    final category = _ensurePlantsCategory();
    final routineIds = plant.routines.map((routine) => routine.id).toSet();
    for (final routine in plant.routines) {
      final index = _tasks.indexWhere(
        (task) =>
            task.sourcePlantId == plant.id &&
            task.sourcePlantCareRoutineId == routine.id,
      );
      final date = DateTime(
        routine.firstDueDate.year,
        routine.firstDueDate.month,
        routine.firstDueDate.day,
      );
      final title =
          routine.title.toLowerCase().contains(plant.name.toLowerCase())
              ? routine.title.trim()
              : '${routine.title.trim()} · ${plant.name}';
      final active = routine.enabled && !plant.archived;
      if (index == -1) {
        _tasks.add(TaskModel(
          id: _id('task'),
          title: title,
          description: routine.instructions.trim().isEmpty
              ? null
              : routine.instructions.trim(),
          categoryIds: <String>[category.id],
          scheduledAt: date,
          status: active ? TaskStatus.active : TaskStatus.archived,
          recurrence: routine.recurrence,
          origin: TaskOrigin.plant,
          manualOrder: _nextManualOrder(),
          sourcePlantId: plant.id,
          sourcePlantCareRoutineId: routine.id,
        ));
        continue;
      }
      final current = _tasks[index];
      final currentDate = current.scheduledAt;
      final scheduledAt = currentDate == null
          ? date
          : DateTime(
              date.year,
              date.month,
              date.day,
              currentDate.hour,
              currentDate.minute,
            );
      _tasks[index] = current.copyWith(
        title: title,
        description:
            routine.instructions.trim().isEmpty ? null : routine.instructions,
        clearDescription: routine.instructions.trim().isEmpty,
        categoryIds: <String>[category.id],
        scheduledAt: scheduledAt,
        status: active ? TaskStatus.active : TaskStatus.archived,
        recurrence: routine.recurrence,
        origin: TaskOrigin.plant,
        sourcePlantId: plant.id,
        sourcePlantCareRoutineId: routine.id,
      );
    }
    for (var index = 0; index < _tasks.length; index++) {
      final task = _tasks[index];
      if (task.sourcePlantId == plant.id &&
          !routineIds.contains(task.sourcePlantCareRoutineId)) {
        _tasks[index] = task.copyWith(status: TaskStatus.archived);
      }
    }
  }

  Future<bool> _prepareEmptyPlantsFeature() async {
    final hadCategory = _categories.any(
      (category) => category.name.trim().toLowerCase() == 'plantas',
    );
    _ensurePlantsCategory();
    final sampleIndex =
        _plants.indexWhere((plant) => plant.id == 'plant-example-spider');
    final sample = sampleIndex == -1 ? null : _plants.removeAt(sampleIndex);
    final taskCount = _tasks.length;
    _tasks.removeWhere((task) => task.sourcePlantId == 'plant-example-spider');
    if (sample != null) {
      for (final path in <String>[sample.imagePath, sample.thumbnailPath]) {
        if (path.isNotEmpty) await _plantAssets.deleteAsset(path);
      }
    }
    return !hadCategory || sample != null || taskCount != _tasks.length;
  }
}
