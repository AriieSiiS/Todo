import 'enums.dart';
import 'json_helpers.dart';

class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.type,
    required this.title,
    this.status = LibraryItemStatus.completed,
    this.completedDate,
    this.coverUrl,
    this.rating,
    this.note,
    this.platform,
    this.developer,
    this.author,
    this.mediaType,
    this.releaseYear,
    this.creatorOrDirector,
    this.genre,
    this.format,
    this.duration,
    this.pages,
    this.country,
    this.collectionName,
    this.collectionNumber,
    this.showCollectionNumber = false,
    this.linkedGoalId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final LibraryItemType type;
  final String title;
  final LibraryItemStatus status;
  final DateTime? completedDate;
  final String? coverUrl;
  final double? rating;
  final String? note;
  final String? platform;
  final String? developer;
  final String? author;
  final LibraryMediaType? mediaType;
  final int? releaseYear;
  final String? creatorOrDirector;
  final String? genre;
  final String? format;
  final String? duration;
  final String? pages;
  final String? country;
  final String? collectionName;
  final int? collectionNumber;
  final bool showCollectionNumber;
  final String? linkedGoalId;
  final DateTime createdAt;
  final DateTime updatedAt;

  int? get yearGroup => completedDate?.year;

  LibraryItem copyWith({
    String? id,
    LibraryItemType? type,
    String? title,
    LibraryItemStatus? status,
    DateTime? completedDate,
    bool clearCompletedDate = false,
    String? coverUrl,
    bool clearCoverUrl = false,
    double? rating,
    bool clearRating = false,
    String? note,
    bool clearNote = false,
    String? platform,
    bool clearPlatform = false,
    String? developer,
    bool clearDeveloper = false,
    String? author,
    bool clearAuthor = false,
    LibraryMediaType? mediaType,
    bool clearMediaType = false,
    int? releaseYear,
    bool clearReleaseYear = false,
    String? creatorOrDirector,
    bool clearCreatorOrDirector = false,
    String? genre,
    bool clearGenre = false,
    String? format,
    bool clearFormat = false,
    String? duration,
    bool clearDuration = false,
    String? pages,
    bool clearPages = false,
    String? country,
    bool clearCountry = false,
    String? collectionName,
    bool clearCollectionName = false,
    int? collectionNumber,
    bool clearCollectionNumber = false,
    bool? showCollectionNumber,
    String? linkedGoalId,
    bool clearLinkedGoalId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LibraryItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      status: status ?? this.status,
      completedDate:
          clearCompletedDate ? null : completedDate ?? this.completedDate,
      coverUrl: clearCoverUrl ? null : coverUrl ?? this.coverUrl,
      rating: clearRating ? null : rating ?? this.rating,
      note: clearNote ? null : note ?? this.note,
      platform: clearPlatform ? null : platform ?? this.platform,
      developer: clearDeveloper ? null : developer ?? this.developer,
      author: clearAuthor ? null : author ?? this.author,
      mediaType: clearMediaType ? null : mediaType ?? this.mediaType,
      releaseYear: clearReleaseYear ? null : releaseYear ?? this.releaseYear,
      creatorOrDirector: clearCreatorOrDirector
          ? null
          : creatorOrDirector ?? this.creatorOrDirector,
      genre: clearGenre ? null : genre ?? this.genre,
      format: clearFormat ? null : format ?? this.format,
      duration: clearDuration ? null : duration ?? this.duration,
      pages: clearPages ? null : pages ?? this.pages,
      country: clearCountry ? null : country ?? this.country,
      collectionName:
          clearCollectionName ? null : collectionName ?? this.collectionName,
      collectionNumber: clearCollectionNumber
          ? null
          : collectionNumber ?? this.collectionNumber,
      showCollectionNumber: showCollectionNumber ?? this.showCollectionNumber,
      linkedGoalId:
          clearLinkedGoalId ? null : linkedGoalId ?? this.linkedGoalId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'title': title,
      'status': status.name,
      'completedDate': completedDate?.toIso8601String(),
      'yearGroup': yearGroup,
      'coverUrl': coverUrl,
      'rating': rating,
      'note': note,
      'platform': platform,
      'developer': developer,
      'author': author,
      'mediaType': mediaType?.name,
      'releaseYear': releaseYear,
      'creatorOrDirector': creatorOrDirector,
      'genre': genre,
      'format': format,
      'duration': duration,
      'pages': pages,
      'country': country,
      'collectionName': collectionName,
      'collectionNumber': collectionNumber,
      'showCollectionNumber': showCollectionNumber,
      'linkedGoalId': linkedGoalId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    final completed = DateTime.tryParse(
      json['completedDate'] as String? ?? '',
    );
    return LibraryItem(
      id: json['id'] as String? ?? '',
      type: enumByName(
        LibraryItemType.values,
        json['type'] as String?,
        LibraryItemType.game,
      ),
      title: json['title'] as String? ?? '',
      status: enumByName(
        LibraryItemStatus.values,
        json['status'] as String?,
        LibraryItemStatus.completed,
      ),
      completedDate: completed,
      coverUrl: json['coverUrl'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      note: json['note'] as String?,
      platform: json['platform'] as String?,
      developer: json['developer'] as String?,
      author: json['author'] as String?,
      mediaType: json['mediaType'] == null
          ? null
          : enumByName(
              LibraryMediaType.values,
              json['mediaType'] as String?,
              LibraryMediaType.movie,
            ),
      releaseYear: (json['releaseYear'] as num?)?.toInt(),
      creatorOrDirector: json['creatorOrDirector'] as String?,
      genre: json['genre'] as String?,
      format: json['format'] as String?,
      duration: json['duration'] as String?,
      pages: json['pages'] as String?,
      country: json['country'] as String?,
      collectionName: json['collectionName'] as String?,
      collectionNumber: (json['collectionNumber'] as num?)?.toInt(),
      showCollectionNumber: json['showCollectionNumber'] as bool? ?? false,
      linkedGoalId: json['linkedGoalId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          completed ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          completed ??
          DateTime.now(),
    );
  }
}
