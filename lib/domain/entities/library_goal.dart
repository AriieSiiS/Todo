import 'enums.dart';
import 'json_helpers.dart';

class LibraryGoal {
  const LibraryGoal({
    required this.id,
    required this.type,
    required this.title,
    required this.targetYear,
    this.status = LibraryGoalStatus.pending,
    this.isFavorite = false,
    this.coverUrl,
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
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final LibraryItemType type;
  final String title;
  final int targetYear;
  final LibraryGoalStatus status;
  final bool isFavorite;
  final String? coverUrl;
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
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => status == LibraryGoalStatus.completed;

  LibraryGoal copyWith({
    String? id,
    LibraryItemType? type,
    String? title,
    int? targetYear,
    LibraryGoalStatus? status,
    bool? isFavorite,
    String? coverUrl,
    bool clearCoverUrl = false,
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LibraryGoal(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      targetYear: targetYear ?? this.targetYear,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
      coverUrl: clearCoverUrl ? null : coverUrl ?? this.coverUrl,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'title': title,
      'targetYear': targetYear,
      'status': status.name,
      'isFavorite': isFavorite,
      'coverUrl': coverUrl,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory LibraryGoal.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return LibraryGoal(
      id: json['id'] as String? ?? '',
      type: enumByName(
        LibraryItemType.values,
        json['type'] as String?,
        LibraryItemType.game,
      ),
      title: json['title'] as String? ?? '',
      targetYear: (json['targetYear'] as num?)?.toInt() ?? now.year,
      status: enumByName(
        LibraryGoalStatus.values,
        json['status'] as String?,
        LibraryGoalStatus.pending,
      ),
      isFavorite: json['isFavorite'] as bool? ?? false,
      coverUrl: json['coverUrl'] as String?,
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
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }
}
