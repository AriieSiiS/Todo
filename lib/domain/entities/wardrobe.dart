import 'enums.dart';
import 'json_helpers.dart';

class WardrobeItem {
  const WardrobeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.imagePath,
    required this.imageSha256,
    required this.createdAt,
    required this.updatedAt,
    this.thumbnailPath = '',
    this.colors = const <String>[],
    this.material = '',
    this.seasons = const <String>[],
    this.occasions = const <String>[],
    this.tags = const <String>[],
    this.favorite = false,
    this.archived = false,
    this.laundryStatus = WardrobeLaundryStatus.available,
    this.useCount = 0,
    this.lastUsedAt,
    this.price,
  });

  final String id;
  final String name;
  final String category;
  final String imagePath;
  final String thumbnailPath;
  final String imageSha256;
  final List<String> colors;
  final String material;
  final List<String> seasons;
  final List<String> occasions;
  final List<String> tags;
  final bool favorite;
  final bool archived;
  final WardrobeLaundryStatus laundryStatus;
  final int useCount;
  final DateTime? lastUsedAt;
  final double? price;
  final DateTime createdAt;
  final DateTime updatedAt;

  WardrobeItem copyWith({
    String? name,
    String? category,
    String? imagePath,
    String? thumbnailPath,
    String? imageSha256,
    List<String>? colors,
    String? material,
    List<String>? seasons,
    List<String>? occasions,
    List<String>? tags,
    bool? favorite,
    bool? archived,
    WardrobeLaundryStatus? laundryStatus,
    int? useCount,
    DateTime? lastUsedAt,
    bool clearLastUsedAt = false,
    double? price,
    bool clearPrice = false,
    DateTime? updatedAt,
  }) {
    return WardrobeItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      imageSha256: imageSha256 ?? this.imageSha256,
      colors: colors ?? this.colors,
      material: material ?? this.material,
      seasons: seasons ?? this.seasons,
      occasions: occasions ?? this.occasions,
      tags: tags ?? this.tags,
      favorite: favorite ?? this.favorite,
      archived: archived ?? this.archived,
      laundryStatus: laundryStatus ?? this.laundryStatus,
      useCount: useCount ?? this.useCount,
      lastUsedAt: clearLastUsedAt ? null : lastUsedAt ?? this.lastUsedAt,
      price: clearPrice ? null : price ?? this.price,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'category': category,
        'imagePath': imagePath,
        'thumbnailPath': thumbnailPath,
        'imageSha256': imageSha256,
        'colors': colors,
        'material': material,
        'seasons': seasons,
        'occasions': occasions,
        'tags': tags,
        'favorite': favorite,
        'archived': archived,
        'laundryStatus': laundryStatus.name,
        'useCount': useCount,
        'lastUsedAt': lastUsedAt?.toIso8601String(),
        'price': price,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WardrobeItem.fromJson(Map<String, dynamic> json) => WardrobeItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Prenda sin nombre',
        category: json['category'] as String? ?? 'Sin categoría',
        imagePath: json['imagePath'] as String? ?? '',
        thumbnailPath: json['thumbnailPath'] as String? ?? '',
        imageSha256: json['imageSha256'] as String? ?? '',
        colors: stringList(json['colors']),
        material: json['material'] as String? ?? '',
        seasons: stringList(json['seasons']),
        occasions: stringList(json['occasions']),
        tags: stringList(json['tags']),
        favorite: json['favorite'] as bool? ?? false,
        archived: json['archived'] as bool? ?? false,
        laundryStatus: enumByName(WardrobeLaundryStatus.values,
            json['laundryStatus'] as String?, WardrobeLaundryStatus.available),
        useCount: (json['useCount'] as num?)?.toInt() ?? 0,
        lastUsedAt: DateTime.tryParse(json['lastUsedAt'] as String? ?? ''),
        price: (json['price'] as num?)?.toDouble(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class WardrobeOutfit {
  const WardrobeOutfit(
      {required this.id,
      required this.name,
      required this.itemIds,
      required this.createdAt,
      this.occasion = '',
      this.tags = const <String>[],
      this.renderImagePath = ''});
  final String id;
  final String name;
  final List<String> itemIds;
  final String occasion;
  final List<String> tags;
  final String renderImagePath;
  final DateTime createdAt;

  WardrobeOutfit copyWith({
    String? name,
    List<String>? itemIds,
    String? occasion,
    List<String>? tags,
    String? renderImagePath,
  }) =>
      WardrobeOutfit(
        id: id,
        name: name ?? this.name,
        itemIds: itemIds ?? this.itemIds,
        occasion: occasion ?? this.occasion,
        tags: tags ?? this.tags,
        renderImagePath: renderImagePath ?? this.renderImagePath,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'itemIds': itemIds,
        'occasion': occasion,
        'tags': tags,
        'renderImagePath': renderImagePath,
        'createdAt': createdAt.toIso8601String()
      };
  factory WardrobeOutfit.fromJson(Map<String, dynamic> json) => WardrobeOutfit(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Conjunto',
      itemIds: stringList(json['itemIds']),
      occasion: json['occasion'] as String? ?? '',
      tags: stringList(json['tags']),
      renderImagePath: json['renderImagePath'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0));
}

class WardrobeWearLog {
  const WardrobeWearLog(
      {required this.id,
      required this.date,
      required this.itemIds,
      this.outfitId,
      this.label = ''});
  final String id;
  final DateTime date;
  final List<String> itemIds;
  final String? outfitId;
  final String label;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date.toIso8601String(),
        'itemIds': itemIds,
        'outfitId': outfitId,
        'label': label
      };
  factory WardrobeWearLog.fromJson(Map<String, dynamic> json) =>
      WardrobeWearLog(
          id: json['id'] as String? ?? '',
          date: DateTime.tryParse(json['date'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          itemIds: stringList(json['itemIds']),
          outfitId: json['outfitId'] as String?,
          label: json['label'] as String? ?? '');
}

class WardrobePlanEntry {
  const WardrobePlanEntry(
      {required this.id,
      required this.date,
      required this.itemIds,
      this.outfitId,
      this.weather = WardrobeWeather.mild,
      this.occasion = ''});
  final String id;
  final DateTime date;
  final List<String> itemIds;
  final String? outfitId;
  final WardrobeWeather weather;
  final String occasion;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date.toIso8601String(),
        'itemIds': itemIds,
        'outfitId': outfitId,
        'weather': weather.name,
        'occasion': occasion
      };
  factory WardrobePlanEntry.fromJson(Map<String, dynamic> json) =>
      WardrobePlanEntry(
          id: json['id'] as String? ?? '',
          date: DateTime.tryParse(json['date'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          itemIds: stringList(json['itemIds']),
          outfitId: json['outfitId'] as String?,
          weather: enumByName(WardrobeWeather.values,
              json['weather'] as String?, WardrobeWeather.mild),
          occasion: json['occasion'] as String? ?? '');
}

class WardrobePackingEntry {
  const WardrobePackingEntry(
      {required this.itemId, this.quantity = 1, this.packed = false});
  final String itemId;
  final int quantity;
  final bool packed;
  WardrobePackingEntry copyWith({int? quantity, bool? packed}) =>
      WardrobePackingEntry(
          itemId: itemId,
          quantity: quantity ?? this.quantity,
          packed: packed ?? this.packed);
  Map<String, dynamic> toJson() => <String, dynamic>{
        'itemId': itemId,
        'quantity': quantity,
        'packed': packed
      };
  factory WardrobePackingEntry.fromJson(Map<String, dynamic> json) =>
      WardrobePackingEntry(
          itemId: json['itemId'] as String? ?? '',
          quantity: (json['quantity'] as num?)?.toInt() ?? 1,
          packed: json['packed'] as bool? ?? false);
}

class WardrobePackingList {
  const WardrobePackingList(
      {required this.id,
      required this.name,
      required this.startDate,
      required this.endDate,
      this.entries = const <WardrobePackingEntry>[],
      this.discardedItemIds = const <String>[]});
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final List<WardrobePackingEntry> entries;
  final List<String> discardedItemIds;
  WardrobePackingList copyWith(
          {String? name,
          DateTime? startDate,
          DateTime? endDate,
          List<WardrobePackingEntry>? entries,
          List<String>? discardedItemIds}) =>
      WardrobePackingList(
          id: id,
          name: name ?? this.name,
          startDate: startDate ?? this.startDate,
          endDate: endDate ?? this.endDate,
          entries: entries ?? this.entries,
          discardedItemIds: discardedItemIds ?? this.discardedItemIds);
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'entries': entries.map((entry) => entry.toJson()).toList(),
        'discardedItemIds': discardedItemIds
      };
  factory WardrobePackingList.fromJson(Map<String, dynamic> json) =>
      WardrobePackingList(
          id: json['id'] as String? ?? '',
          name: json['name'] as String? ?? 'Viaje',
          startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          endDate: DateTime.tryParse(json['endDate'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          entries: (json['entries'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => WardrobePackingEntry.fromJson(
                  (value as Map).cast<String, dynamic>()))
              .toList(),
          discardedItemIds: stringList(json['discardedItemIds']));
}

class WardrobeImportItem {
  const WardrobeImportItem(
      {required this.id,
      required this.fileName,
      required this.name,
      required this.category,
      required this.imageSha256,
      this.colors = const <String>[],
      this.material = '',
      this.seasons = const <String>[],
      this.occasions = const <String>[],
      this.tags = const <String>[],
      this.confidence = 'media',
      this.sourceReferences = const <String>[],
      this.errors = const <String>[],
      this.duplicateItemId});
  final String id;
  final String fileName;
  final String name;
  final String category;
  final String imageSha256;
  final List<String> colors;
  final String material;
  final List<String> seasons;
  final List<String> occasions;
  final List<String> tags;
  final String confidence;
  final List<String> sourceReferences;
  final List<String> errors;
  final String? duplicateItemId;
  WardrobeImportItem copyWith(
          {String? name,
          String? category,
          List<String>? colors,
          String? material,
          List<String>? seasons,
          List<String>? occasions,
          List<String>? tags}) =>
      WardrobeImportItem(
          id: id,
          fileName: fileName,
          name: name ?? this.name,
          category: category ?? this.category,
          imageSha256: imageSha256,
          colors: colors ?? this.colors,
          material: material ?? this.material,
          seasons: seasons ?? this.seasons,
          occasions: occasions ?? this.occasions,
          tags: tags ?? this.tags,
          confidence: confidence,
          sourceReferences: sourceReferences,
          errors: errors,
          duplicateItemId: duplicateItemId);
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fileName': fileName,
        'name': name,
        'category': category,
        'imageSha256': imageSha256,
        'colors': colors,
        'material': material,
        'seasons': seasons,
        'occasions': occasions,
        'tags': tags,
        'confidence': confidence,
        'sourceReferences': sourceReferences,
        'errors': errors,
        'duplicateItemId': duplicateItemId
      };
  factory WardrobeImportItem.fromJson(Map<String, dynamic> json) =>
      WardrobeImportItem(
          id: json['id'] as String? ?? '',
          fileName: json['fileName'] as String? ?? '',
          name: json['name'] as String? ?? 'Prenda',
          category: json['category'] as String? ?? 'Sin categoría',
          imageSha256: json['imageSha256'] as String? ?? '',
          colors: stringList(json['colors']),
          material: json['material'] as String? ?? '',
          seasons: stringList(json['seasons']),
          occasions: stringList(json['occasions']),
          tags: stringList(json['tags']),
          confidence: json['confidence'] as String? ?? 'media',
          sourceReferences: stringList(json['sourceReferences']),
          errors: stringList(json['errors']),
          duplicateItemId: json['duplicateItemId'] as String?);
}

class WardrobeImportBatch {
  const WardrobeImportBatch(
      {required this.id,
      required this.name,
      required this.createdAt,
      required this.status,
      required this.items,
      this.errorMessage = ''});
  final String id;
  final String name;
  final DateTime createdAt;
  final WardrobeImportStatus status;
  final List<WardrobeImportItem> items;
  final String errorMessage;
  WardrobeImportBatch copyWith(
          {WardrobeImportStatus? status,
          List<WardrobeImportItem>? items,
          String? errorMessage}) =>
      WardrobeImportBatch(
          id: id,
          name: name,
          createdAt: createdAt,
          status: status ?? this.status,
          items: items ?? this.items,
          errorMessage: errorMessage ?? this.errorMessage);
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'items': items.map((item) => item.toJson()).toList(),
        'errorMessage': errorMessage
      };
  factory WardrobeImportBatch.fromJson(Map<String, dynamic> json) =>
      WardrobeImportBatch(
          id: json['id'] as String? ?? '',
          name: json['name'] as String? ?? 'Importación',
          createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          status: enumByName(WardrobeImportStatus.values,
              json['status'] as String?, WardrobeImportStatus.pending),
          items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => WardrobeImportItem.fromJson(
                  (value as Map).cast<String, dynamic>()))
              .toList(),
          errorMessage: json['errorMessage'] as String? ?? '');
}
