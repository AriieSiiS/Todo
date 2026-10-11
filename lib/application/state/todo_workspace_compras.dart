part of 'todo_workspace.dart';

extension TodoWorkspaceCompras on TodoWorkspace {
  ShoppingItem? shoppingItemById(String id) {
    for (final item in _shoppingItems) {
      if (item.id == id) return item;
    }
    return null;
  }

  ShoppingItem createShoppingItem({
    required String name,
    required String category,
    String subcategory = '',
    String sourceUrl = '',
    String retailer = '',
    String notes = '',
    String researchNotes = '',
    double? referencePrice,
    double? targetPrice,
    bool priority = false,
    ShoppingStatus status = ShoppingStatus.saved,
    List<ShoppingOffer> offers = const [],
  }) {
    final instant = DateTime.now();
    final peers = _shoppingItems.where((item) =>
        item.category == category.trim() &&
        item.subcategory == subcategory.trim());
    final item = ShoppingItem(
      id: _id('shopping-item'),
      name: name.trim().isEmpty ? 'Compra sin nombre' : name.trim(),
      category: category.trim().isEmpty ? 'Sin categoría' : category.trim(),
      subcategory: subcategory.trim(),
      sourceUrl: sourceUrl.trim(),
      retailer: retailer.trim(),
      notes: notes.trim(),
      researchNotes: researchNotes.trim(),
      referencePrice: referencePrice,
      targetPrice: targetPrice,
      priority: priority,
      status: status,
      grouped: peers.isEmpty || peers.any((item) => item.grouped),
      offers: List.unmodifiable(offers),
      createdAt: instant,
      updatedAt: instant,
    );
    _shoppingItems.add(item);
    _commit();
    return item;
  }

  void setShoppingGroupGrouped(
      String category, String subcategory, bool grouped) {
    var changed = false;
    final instant = DateTime.now();
    for (var i = 0; i < _shoppingItems.length; i++) {
      final item = _shoppingItems[i];
      if (item.category != category ||
          item.subcategory.trim() != subcategory.trim() ||
          item.grouped == grouped) {
        continue;
      }
      _shoppingItems[i] = item.copyWith(grouped: grouped, updatedAt: instant);
      changed = true;
    }
    if (changed) _commit();
  }

  void updateShoppingItem(
    String id, {
    String? name,
    String? category,
    String? subcategory,
    String? sourceUrl,
    String? retailer,
    String? notes,
    String? researchNotes,
    double? referencePrice,
    bool clearReferencePrice = false,
    double? targetPrice,
    bool clearTargetPrice = false,
    bool? priority,
    ShoppingStatus? status,
    bool? archived,
    List<ShoppingOffer>? offers,
  }) {
    final index = _shoppingItems.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _shoppingItems[index] = _shoppingItems[index].copyWith(
      name: name?.trim(),
      category: category?.trim(),
      subcategory: subcategory?.trim(),
      sourceUrl: sourceUrl?.trim(),
      retailer: retailer?.trim(),
      notes: notes?.trim(),
      researchNotes: researchNotes?.trim(),
      referencePrice: referencePrice,
      clearReferencePrice: clearReferencePrice,
      targetPrice: targetPrice,
      clearTargetPrice: clearTargetPrice,
      priority: priority,
      status: status,
      archived: archived,
      offers: offers == null ? null : List.unmodifiable(offers),
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  Future<String> shoppingImageAbsolutePath(ShoppingItem item,
          {bool thumbnail = true}) =>
      _shoppingAssets.absolutePath(thumbnail && item.thumbnailPath.isNotEmpty
          ? item.thumbnailPath
          : item.imagePath);

  Future<void> importShoppingImage(String id, String sourcePath) async {
    if (shoppingItemById(id) == null) {
      throw StateError('No se encuentra la compra.');
    }
    final imported = await _shoppingAssets.importImage(id, sourcePath);
    final index = _shoppingItems.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final previous = _shoppingItems[index];
    _shoppingItems[index] = previous.copyWith(
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
        await _shoppingAssets.deleteAsset(path);
      }
    }
  }

  void deleteShoppingItem(String id) {
    final item = shoppingItemById(id);
    if (item == null) return;
    _shoppingItems.removeWhere((entry) => entry.id == id);
    _commit();
    for (final path in {item.imagePath, item.thumbnailPath}) {
      if (path.isNotEmpty) unawaited(_shoppingAssets.deleteAsset(path));
    }
  }
}
