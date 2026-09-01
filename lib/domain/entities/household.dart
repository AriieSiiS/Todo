import 'json_helpers.dart';

class HouseholdItem {
  const HouseholdItem({
    required this.id,
    required this.name,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.brand = '',
    this.model = '',
    this.serialNumber = '',
    this.location = '',
    this.notes = '',
    this.imagePath = '',
    this.thumbnailPath = '',
    this.imageSha256 = '',
    this.manualPath = '',
    this.manualSourceUrl = '',
    this.invoicePath = '',
    this.retailer = '',
    this.purchaseDate,
    this.warrantyUntil,
    this.price,
    this.tags = const <String>[],
    this.archived = false,
  });

  final String id;
  final String name;
  final String category;
  final String brand;
  final String model;
  final String serialNumber;
  final String location;
  final String notes;
  final String imagePath;
  final String thumbnailPath;
  final String imageSha256;
  final String manualPath;
  final String manualSourceUrl;
  final String invoicePath;
  final String retailer;
  final DateTime? purchaseDate;
  final DateTime? warrantyUntil;
  final double? price;
  final List<String> tags;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasManual => manualPath.trim().isNotEmpty;
  bool get hasInvoice => invoicePath.trim().isNotEmpty;

  HouseholdItem copyWith({
    String? name,
    String? category,
    String? brand,
    String? model,
    String? serialNumber,
    String? location,
    String? notes,
    String? imagePath,
    String? thumbnailPath,
    String? imageSha256,
    String? manualPath,
    String? manualSourceUrl,
    String? invoicePath,
    String? retailer,
    DateTime? purchaseDate,
    bool clearPurchaseDate = false,
    DateTime? warrantyUntil,
    bool clearWarrantyUntil = false,
    double? price,
    bool clearPrice = false,
    List<String>? tags,
    bool? archived,
    DateTime? updatedAt,
  }) {
    return HouseholdItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      imageSha256: imageSha256 ?? this.imageSha256,
      manualPath: manualPath ?? this.manualPath,
      manualSourceUrl: manualSourceUrl ?? this.manualSourceUrl,
      invoicePath: invoicePath ?? this.invoicePath,
      retailer: retailer ?? this.retailer,
      purchaseDate:
          clearPurchaseDate ? null : purchaseDate ?? this.purchaseDate,
      warrantyUntil:
          clearWarrantyUntil ? null : warrantyUntil ?? this.warrantyUntil,
      price: clearPrice ? null : price ?? this.price,
      tags: tags ?? this.tags,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'category': category,
        'brand': brand,
        'model': model,
        'serialNumber': serialNumber,
        'location': location,
        'notes': notes,
        'imagePath': imagePath,
        'thumbnailPath': thumbnailPath,
        'imageSha256': imageSha256,
        'manualPath': manualPath,
        'manualSourceUrl': manualSourceUrl,
        'invoicePath': invoicePath,
        'retailer': retailer,
        'purchaseDate': purchaseDate?.toIso8601String(),
        'warrantyUntil': warrantyUntil?.toIso8601String(),
        'price': price,
        'tags': tags,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HouseholdItem.fromJson(Map<String, dynamic> json) => HouseholdItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Artículo sin nombre',
        category: json['category'] as String? ?? 'Sin categoría',
        brand: json['brand'] as String? ?? '',
        model: json['model'] as String? ?? '',
        serialNumber: json['serialNumber'] as String? ?? '',
        location: json['location'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        imagePath: json['imagePath'] as String? ?? '',
        thumbnailPath: json['thumbnailPath'] as String? ?? '',
        imageSha256: json['imageSha256'] as String? ?? '',
        manualPath: json['manualPath'] as String? ?? '',
        manualSourceUrl: json['manualSourceUrl'] as String? ?? '',
        invoicePath: json['invoicePath'] as String? ?? '',
        retailer: json['retailer'] as String? ?? '',
        purchaseDate: DateTime.tryParse(json['purchaseDate'] as String? ?? ''),
        warrantyUntil:
            DateTime.tryParse(json['warrantyUntil'] as String? ?? ''),
        price: (json['price'] as num?)?.toDouble(),
        tags: stringList(json['tags']),
        archived: json['archived'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
