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
  final int targetYear;
  final LibraryGoalStatus status;
  final bool isFavorite;
  final String? coverUrl;
  final String? note;
  final String? platform;
  final String? author;
  final LibraryMediaType? mediaType;
  final int? releaseYear;
  final String? creatorOrDirector;
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
      'targetYear': targetYear,
      'status': status.name,
      'isFavorite': isFavorite,
      'coverUrl': coverUrl,
      'note': note,
      'platform': platform,
      'author': author,
      'mediaType': mediaType?.name,
      'releaseYear': releaseYear,
      'creatorOrDirector': creatorOrDirector,
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
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }
}
