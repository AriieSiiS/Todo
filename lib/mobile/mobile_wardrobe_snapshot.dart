class MobileWardrobeItem {
  const MobileWardrobeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.imageSha256,
    required this.thumbnailSha256,
    required this.imageAvailable,
    required this.archived,
    required this.favorite,
    required this.colors,
    required this.material,
    required this.seasons,
    required this.occasions,
    required this.tags,
  });

  final String id;
  final String name;
  final String category;
  final String imageSha256;
  final String thumbnailSha256;
  final bool imageAvailable;
  final bool archived;
  final bool favorite;
  final List<String> colors;
  final String material;
  final List<String> seasons;
  final List<String> occasions;
  final List<String> tags;

  MobileWardrobeItem withoutAsset(String variant) => MobileWardrobeItem(
        id: id,
        name: name,
        category: category,
        imageSha256: imageSha256,
        thumbnailSha256: variant == 'thumbnail' ? '' : thumbnailSha256,
        imageAvailable: variant == 'original' ? false : imageAvailable,
        archived: archived,
        favorite: favorite,
        colors: colors,
        material: material,
        seasons: seasons,
        occasions: occasions,
        tags: tags,
      );

  factory MobileWardrobeItem.fromJson(Map<String, dynamic> value) {
    List<String> strings(String key) =>
        (value[key] as List? ?? const []).whereType<String>().toList();
    return MobileWardrobeItem(
      id: value['id'] as String? ?? '',
      name: value['name'] as String? ?? 'Prenda sin nombre',
      category: value['category'] as String? ?? 'Sin categoría',
      imageSha256: value['imageSha256'] as String? ?? '',
      thumbnailSha256: value['thumbnailSha256'] as String? ?? '',
      imageAvailable: value['imageAvailable'] as bool? ?? false,
      archived: value['archived'] as bool? ?? false,
      favorite: value['favorite'] as bool? ?? false,
      colors: strings('colors'),
      material: value['material'] as String? ?? '',
      seasons: strings('seasons'),
      occasions: strings('occasions'),
      tags: strings('tags'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'imageSha256': imageSha256,
        'thumbnailSha256': thumbnailSha256,
        'imageAvailable': imageAvailable,
        'archived': archived,
        'favorite': favorite,
        'colors': colors,
        'material': material,
        'seasons': seasons,
        'occasions': occasions,
        'tags': tags,
      };
}

class MobilePackingEntry {
  const MobilePackingEntry({
    required this.itemId,
    required this.quantity,
    required this.packed,
  });

  final String itemId;
  final int quantity;
  final bool packed;

  factory MobilePackingEntry.fromJson(Map<String, dynamic> value) =>
      MobilePackingEntry(
        itemId: value['itemId'] as String? ?? '',
        quantity: ((value['quantity'] as num?)?.toInt() ?? 1).clamp(1, 999),
        packed: value['packed'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'quantity': quantity,
        'packed': packed,
      };
}

class MobilePackingList {
  const MobilePackingList({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.entries,
    this.localOnly = false,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final List<MobilePackingEntry> entries;
  final bool localOnly;

  factory MobilePackingList.fromJson(Map<String, dynamic> value) =>
      MobilePackingList(
        id: value['id'] as String? ?? '',
        name: value['name'] as String? ?? 'Viaje',
        startDate: DateTime.tryParse(value['startDate'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        endDate: DateTime.tryParse(value['endDate'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        entries: (value['entries'] as List? ?? const [])
            .whereType<Map>()
            .map((entry) =>
                MobilePackingEntry.fromJson(entry.cast<String, dynamic>()))
            .toList(),
        localOnly: value['localOnly'] as bool? ?? false,
      );

  MobilePackingList asLocalOnly() => MobilePackingList(
        id: id,
        name: name,
        startDate: startDate,
        endDate: endDate,
        entries: entries,
        localOnly: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'entries': entries.map((entry) => entry.toJson()).toList(),
        'localOnly': localOnly,
      };
}

class MobileWardrobeSnapshot {
  const MobileWardrobeSnapshot({
    required this.serverId,
    required this.revision,
    required this.generatedAt,
    required this.items,
    required this.packingLists,
  });

  final String serverId;
  final String revision;
  final DateTime generatedAt;
  final List<MobileWardrobeItem> items;
  final List<MobilePackingList> packingLists;

  MobileWardrobeSnapshot withUnavailableAssets(
      Map<String, Set<String>> unavailable) {
    if (unavailable.isEmpty) return this;
    return MobileWardrobeSnapshot(
      serverId: serverId,
      revision: revision,
      generatedAt: generatedAt,
      items: items.map((item) {
        var next = item;
        for (final variant in unavailable[item.id] ?? <String>{}) {
          next = next.withoutAsset(variant);
        }
        return next;
      }).toList(),
      packingLists: packingLists,
    );
  }

  factory MobileWardrobeSnapshot.fromJson(Map<String, dynamic> value) {
    if ((value['protocolVersion'] as num?)?.toInt() != 1 ||
        (value['wardrobeVersion'] as num?)?.toInt() != 1) {
      throw const FormatException('La versión de Ropa no es compatible.');
    }
    return MobileWardrobeSnapshot(
      serverId: value['serverId'] as String? ?? '',
      revision: value['revision'] as String? ?? '',
      generatedAt: DateTime.tryParse(value['generatedAt'] as String? ?? '') ??
          DateTime.now(),
      items: (value['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) =>
              MobileWardrobeItem.fromJson(item.cast<String, dynamic>()))
          .toList(),
      packingLists: (value['packingLists'] as List? ?? const [])
          .whereType<Map>()
          .map((list) =>
              MobilePackingList.fromJson(list.cast<String, dynamic>()))
          .toList(),
    );
  }

  MobileWardrobeSnapshot mergePrevious(MobileWardrobeSnapshot? previous) {
    if (previous == null) return this;
    final newListIds = packingLists.map((list) => list.id).toSet();
    final retained = previous.packingLists
        .where((list) => !newListIds.contains(list.id))
        .map((list) => list.asLocalOnly())
        .toList();
    final newItemIds = items.map((item) => item.id).toSet();
    final retainedIds = retained
        .expand((list) => list.entries)
        .map((entry) => entry.itemId)
        .toSet();
    return MobileWardrobeSnapshot(
      serverId: serverId,
      revision: revision,
      generatedAt: generatedAt,
      items: [
        ...items,
        ...previous.items.where((item) =>
            retainedIds.contains(item.id) && !newItemIds.contains(item.id)),
      ],
      packingLists: [...packingLists, ...retained],
    );
  }

  MobileWardrobeItem? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'protocolVersion': 1,
        'wardrobeVersion': 1,
        'serverId': serverId,
        'revision': revision,
        'generatedAt': generatedAt.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
        'packingLists': packingLists.map((list) => list.toJson()).toList(),
      };
}
