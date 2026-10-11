part of 'todo_workspace.dart';

extension TodoWorkspaceHogar on TodoWorkspace {
  HouseholdItem? householdItemById(String id) {
    for (final item in _householdItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<String> householdImageAbsolutePath(
    HouseholdItem item, {
    bool thumbnail = true,
  }) {
    final path = thumbnail && item.thumbnailPath.isNotEmpty
        ? item.thumbnailPath
        : item.imagePath;
    return _householdAssets.absolutePath(path);
  }

  Future<String> householdDocumentAbsolutePath(String relativePath) =>
      _householdAssets.absolutePath(relativePath);

  HouseholdItem createHouseholdItem({
    required String name,
    required String category,
    String brand = '',
    String model = '',
    String serialNumber = '',
    String location = '',
    String notes = '',
    String manualSourceUrl = '',
    String retailer = '',
    DateTime? purchaseDate,
    DateTime? warrantyUntil,
    double? price,
    List<String> tags = const <String>[],
  }) {
    final instant = DateTime.now();
    final item = HouseholdItem(
      id: _id('household-item'),
      name: name.trim().isEmpty ? 'Artículo sin nombre' : name.trim(),
      category: category.trim().isEmpty ? 'Sin categoría' : category.trim(),
      brand: brand.trim(),
      model: model.trim(),
      serialNumber: serialNumber.trim(),
      location: location.trim(),
      notes: notes.trim(),
      manualSourceUrl: manualSourceUrl.trim(),
      retailer: retailer.trim(),
      purchaseDate: purchaseDate,
      warrantyUntil: warrantyUntil,
      price: price,
      tags: tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(),
      createdAt: instant,
      updatedAt: instant,
    );
    _householdItems.add(item);
    _commit();
    return item;
  }

  void updateHouseholdItem(
    String id, {
    String? name,
    String? category,
    String? brand,
    String? model,
    String? serialNumber,
    String? location,
    String? notes,
    String? manualSourceUrl,
    String? retailer,
    DateTime? purchaseDate,
    bool clearPurchaseDate = false,
    DateTime? warrantyUntil,
    bool clearWarrantyUntil = false,
    double? price,
    bool clearPrice = false,
    List<String>? tags,
  }) {
    final index = _householdItems.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _householdItems[index] = _householdItems[index].copyWith(
      name: name?.trim(),
      category: category?.trim(),
      brand: brand?.trim(),
      model: model?.trim(),
      serialNumber: serialNumber?.trim(),
      location: location?.trim(),
      notes: notes?.trim(),
      manualSourceUrl: manualSourceUrl?.trim(),
      retailer: retailer?.trim(),
      purchaseDate: purchaseDate,
      clearPurchaseDate: clearPurchaseDate,
      warrantyUntil: warrantyUntil,
      clearWarrantyUntil: clearWarrantyUntil,
      price: price,
      clearPrice: clearPrice,
      tags: tags
          ?.map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(),
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  Future<void> importHouseholdImage(String id, String sourcePath) async {
    if (householdItemById(id) == null) {
      throw StateError('No se encuentra el artículo.');
    }
    await _importHouseholdStoredImage(
      id,
      await _householdAssets.importImage(id, sourcePath),
    );
  }

  Future<void> importHouseholdImageBytes(String id, Uint8List bytes) async {
    if (householdItemById(id) == null) {
      throw StateError('No se encuentra el artículo.');
    }
    await _importHouseholdStoredImage(
      id,
      await _householdAssets.importImageBytes(id, bytes),
    );
  }

  Future<void> _importHouseholdStoredImage(
    String id,
    HouseholdImportedImage imported,
  ) async {
    final index = _householdItems.indexWhere((item) => item.id == id);
    if (index == -1) throw StateError('No se encuentra el artículo.');
    final previousImage = _householdItems[index].imagePath;
    final previousThumbnail = _householdItems[index].thumbnailPath;
    _householdItems[index] = _householdItems[index].copyWith(
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
        await _householdAssets.deleteAsset(path);
      }
    }
  }

  Future<void> importHouseholdManual(String id, String sourcePath) async {
    await _importHouseholdPdf(id, sourcePath, manual: true);
  }

  Future<void> importHouseholdInvoice(String id, String sourcePath) async {
    await _importHouseholdPdf(id, sourcePath, manual: false);
  }

  Future<void> _importHouseholdPdf(
    String id,
    String sourcePath, {
    required bool manual,
  }) async {
    final index = _householdItems.indexWhere((item) => item.id == id);
    if (index == -1) throw StateError('No se encuentra el artículo.');
    final previous = manual
        ? _householdItems[index].manualPath
        : _householdItems[index].invoicePath;
    final imported = await _householdAssets.importPdf(
      id,
      sourcePath,
      kind: manual ? 'manuals' : 'invoices',
    );
    _householdItems[index] = _householdItems[index].copyWith(
      manualPath: manual ? imported : null,
      invoicePath: manual ? null : imported,
      updatedAt: DateTime.now(),
    );
    _commit();
    if (previous.isNotEmpty && previous != imported) {
      await _householdAssets.deleteAsset(previous);
    }
  }

  void archiveHouseholdItem(String id) {
    final index = _householdItems.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _householdItems[index] = _householdItems[index].copyWith(
      archived: true,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void deleteHouseholdItem(String id) {
    final item = householdItemById(id);
    if (item == null) return;
    _householdItems.removeWhere((value) => value.id == id);
    _commit();
    for (final path in <String>[
      item.imagePath,
      item.thumbnailPath,
      item.manualPath,
      item.invoicePath,
    ]) {
      if (path.isNotEmpty) unawaited(_householdAssets.deleteAsset(path));
    }
  }
}
