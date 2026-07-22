import 'dart:convert';

enum KnowledgeAssetKind { image, audio, video, pdf, file }

enum KnowledgePropertyType {
  text,
  number,
  checkbox,
  select,
  multiSelect,
  status,
  date,
  url,
  asset,
  relation,
  rollup,
}

enum KnowledgeViewType { table, list, gallery, board, calendar, timeline }

class KnowledgePage {
  const KnowledgePage({
    required this.id,
    required this.title,
    required this.document,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.icon,
    this.coverAssetId,
    this.collectionId,
    this.properties = const <String, dynamic>{},
    this.canonicalSource,
    this.canonicalId,
    this.sortOrder = 0,
    this.isTrashed = false,
    this.deletedAt,
    this.revision = 1,
  });

  final String id;
  final String? parentId;
  final String title;
  final String? icon;
  final String? coverAssetId;
  final Map<String, dynamic> document;
  final String? collectionId;
  final Map<String, dynamic> properties;
  final String? canonicalSource;
  final String? canonicalId;
  final int sortOrder;
  final bool isTrashed;
  final DateTime? deletedAt;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;

  KnowledgePage copyWith({
    String? parentId,
    bool clearParentId = false,
    String? title,
    String? icon,
    bool clearIcon = false,
    String? coverAssetId,
    bool clearCoverAssetId = false,
    Map<String, dynamic>? document,
    String? collectionId,
    bool clearCollectionId = false,
    Map<String, dynamic>? properties,
    String? canonicalSource,
    String? canonicalId,
    int? sortOrder,
    bool? isTrashed,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    int? revision,
    DateTime? updatedAt,
  }) {
    return KnowledgePage(
      id: id,
      parentId: clearParentId ? null : parentId ?? this.parentId,
      title: title ?? this.title,
      icon: clearIcon ? null : icon ?? this.icon,
      coverAssetId:
          clearCoverAssetId ? null : coverAssetId ?? this.coverAssetId,
      document: document ?? this.document,
      collectionId:
          clearCollectionId ? null : collectionId ?? this.collectionId,
      properties: properties ?? this.properties,
      canonicalSource: canonicalSource ?? this.canonicalSource,
      canonicalId: canonicalId ?? this.canonicalId,
      sortOrder: sortOrder ?? this.sortOrder,
      isTrashed: isTrashed ?? this.isTrashed,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'parentId': parentId,
        'title': title,
        'icon': icon,
        'coverAssetId': coverAssetId,
        'document': document,
        'collectionId': collectionId,
        'properties': properties,
        'canonicalSource': canonicalSource,
        'canonicalId': canonicalId,
        'sortOrder': sortOrder,
        'isTrashed': isTrashed,
        'deletedAt': deletedAt?.toIso8601String(),
        'revision': revision,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class KnowledgeAsset {
  const KnowledgeAsset({
    required this.id,
    required this.kind,
    required this.mimeType,
    required this.relativePath,
    required this.size,
    required this.createdAt,
    this.sourceUrl,
    this.sourcePageUrl,
    this.author,
    this.altText,
    this.remoteStatus = 'local',
  });

  final String id;
  final KnowledgeAssetKind kind;
  final String mimeType;
  final String relativePath;
  final int size;
  final String? sourceUrl;
  final String? sourcePageUrl;
  final String? author;
  final String? altText;
  final String remoteStatus;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        'mimeType': mimeType,
        'relativePath': relativePath,
        'size': size,
        'sourceUrl': sourceUrl,
        'sourcePageUrl': sourcePageUrl,
        'author': author,
        'altText': altText,
        'remoteStatus': remoteStatus,
        'createdAt': createdAt.toIso8601String(),
      };
}

class KnowledgePropertyDefinition {
  const KnowledgePropertyDefinition({
    required this.id,
    required this.name,
    required this.type,
    this.options = const <String>[],
    this.relationCollectionId,
    this.rollupPropertyId,
    this.rollupOperation,
  });

  final String id;
  final String name;
  final KnowledgePropertyType type;
  final List<String> options;
  final String? relationCollectionId;
  final String? rollupPropertyId;
  final String? rollupOperation;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': type.name,
        'options': options,
        'relationCollectionId': relationCollectionId,
        'rollupPropertyId': rollupPropertyId,
        'rollupOperation': rollupOperation,
      };
}

class KnowledgeCollectionView {
  const KnowledgeCollectionView({
    required this.id,
    required this.name,
    required this.type,
    this.configuration = const <String, dynamic>{},
  });

  final String id;
  final String name;
  final KnowledgeViewType type;
  final Map<String, dynamic> configuration;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': type.name,
        'configuration': configuration,
      };
}

class KnowledgeCollection {
  const KnowledgeCollection({
    required this.id,
    required this.pageId,
    required this.name,
    required this.properties,
    required this.views,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String pageId;
  final String name;
  final List<KnowledgePropertyDefinition> properties;
  final List<KnowledgeCollectionView> views;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'pageId': pageId,
        'name': name,
        'properties': properties.map((item) => item.toJson()).toList(),
        'views': views.map((item) => item.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class KnowledgeTab {
  const KnowledgeTab({
    required this.pageId,
    this.pinned = false,
    this.backHistory = const <String>[],
    this.forwardHistory = const <String>[],
  });

  final String pageId;
  final bool pinned;
  final List<String> backHistory;
  final List<String> forwardHistory;

  String encodeBackHistory() => jsonEncode(backHistory);
  String encodeForwardHistory() => jsonEncode(forwardHistory);
}
