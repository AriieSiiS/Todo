enum ShoppingStatus { saved, comparing, purchased }

extension ShoppingStatusLabel on ShoppingStatus {
  String get label => switch (this) {
        ShoppingStatus.saved => 'Guardado',
        ShoppingStatus.comparing => 'En comparación',
        ShoppingStatus.purchased => 'Comprado',
      };
}

class ShoppingOffer {
  const ShoppingOffer({required this.name, required this.sourceUrl});
  final String name;
  final String sourceUrl;
  Map<String, dynamic> toJson() => {'name': name, 'sourceUrl': sourceUrl};
  factory ShoppingOffer.fromJson(Map<String, dynamic> json) => ShoppingOffer(
      name: json['name'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '');
}

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.subcategory = '',
    this.sourceUrl = '',
    this.retailer = '',
    this.notes = '',
    this.researchNotes = '',
    this.imagePath = '',
    this.thumbnailPath = '',
    this.imageSha256 = '',
    this.referencePrice,
    this.targetPrice,
    this.priority = false,
    this.status = ShoppingStatus.saved,
    this.archived = false,
    this.grouped = true,
    this.offers = const [],
  });

  final String id;
  final String name;
  final String category;
  final String subcategory;
  final String sourceUrl;
  final String retailer;
  final String notes;
  final String researchNotes;
  final String imagePath;
  final String thumbnailPath;
  final String imageSha256;
  final double? referencePrice;
  final double? targetPrice;
  final bool priority;
  final ShoppingStatus status;
  final bool archived;
  final bool grouped;
  final List<ShoppingOffer> offers;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShoppingItem copyWith({
    String? name,
    String? category,
    String? subcategory,
    String? sourceUrl,
    String? retailer,
    String? notes,
    String? researchNotes,
    String? imagePath,
    String? thumbnailPath,
    String? imageSha256,
    double? referencePrice,
    bool clearReferencePrice = false,
    double? targetPrice,
    bool clearTargetPrice = false,
    bool? priority,
    ShoppingStatus? status,
    bool? archived,
    bool? grouped,
    List<ShoppingOffer>? offers,
    DateTime? updatedAt,
  }) =>
      ShoppingItem(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        subcategory: subcategory ?? this.subcategory,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        retailer: retailer ?? this.retailer,
        notes: notes ?? this.notes,
        researchNotes: researchNotes ?? this.researchNotes,
        imagePath: imagePath ?? this.imagePath,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        imageSha256: imageSha256 ?? this.imageSha256,
        referencePrice:
            clearReferencePrice ? null : referencePrice ?? this.referencePrice,
        targetPrice: clearTargetPrice ? null : targetPrice ?? this.targetPrice,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        archived: archived ?? this.archived,
        grouped: grouped ?? this.grouped,
        offers: offers ?? this.offers,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'subcategory': subcategory,
        'sourceUrl': sourceUrl,
        'retailer': retailer,
        'notes': notes,
        'researchNotes': researchNotes,
        'imagePath': imagePath,
        'thumbnailPath': thumbnailPath,
        'imageSha256': imageSha256,
        'referencePrice': referencePrice,
        'targetPrice': targetPrice,
        'priority': priority,
        'status': status.name,
        'archived': archived,
        'grouped': grouped,
        'offers': offers.map((offer) => offer.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Compra sin nombre',
        category: json['category'] as String? ?? 'Sin categoría',
        subcategory: json['subcategory'] as String? ?? '',
        sourceUrl: json['sourceUrl'] as String? ?? '',
        retailer: json['retailer'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        researchNotes: json['researchNotes'] as String? ?? '',
        imagePath: json['imagePath'] as String? ?? '',
        thumbnailPath: json['thumbnailPath'] as String? ?? '',
        imageSha256: json['imageSha256'] as String? ?? '',
        referencePrice: (json['referencePrice'] as num?)?.toDouble(),
        targetPrice: (json['targetPrice'] as num?)?.toDouble(),
        priority: json['priority'] as bool? ?? false,
        status: ShoppingStatus.values.firstWhere(
            (status) => status.name == json['status'],
            orElse: () => ShoppingStatus.saved),
        archived: json['archived'] as bool? ?? false,
        grouped: json['grouped'] as bool? ?? true,
        offers: (json['offers'] as List? ?? [])
            .map((value) =>
                ShoppingOffer.fromJson(Map<String, dynamic>.from(value as Map)))
            .toList(growable: false),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
