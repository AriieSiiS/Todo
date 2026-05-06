import 'enums.dart';
import 'json_helpers.dart';

class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.completedDate,
    this.coverUrl,
    this.rating,
    this.note,
    this.platform,
    this.developer,
    this.author,
    this.mediaType,
    this.releaseYear,
    this.creatorOrDirector,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final LibraryItemType type;
  final String title;
  final DateTime completedDate;
  final String? coverUrl;
  final double? rating;
  final String? note;
  final String? platform;
  final String? developer;
  final String? author;
  final LibraryMediaType? mediaType;
  final int? releaseYear;
  final String? creatorOrDirector;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get yearGroup => completedDate.year;

  LibraryItem copyWith({
    String? id,
    LibraryItemType? type,
    String? title,
    DateTime? completedDate,
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LibraryItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      completedDate: completedDate ?? this.completedDate,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'title': title,
      'completedDate': completedDate.toIso8601String(),
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LibraryItem.fromJson(Map<String, dynamic> json) {
    final completed = DateTime.tryParse(
          json['completedDate'] as String? ?? '',
        ) ??
        DateTime.now();
    return LibraryItem(
      id: json['id'] as String? ?? '',
      type: enumByName(
        LibraryItemType.values,
        json['type'] as String?,
        LibraryItemType.game,
      ),
      title: json['title'] as String? ?? '',
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
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? completed,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? completed,
    );
  }
}
