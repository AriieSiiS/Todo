import 'enums.dart';
import 'json_helpers.dart';
import 'library_reading.dart';

class LibraryItem {
  const LibraryItem({
    required this.id,
    required this.type,
    required this.title,
    this.status = LibraryItemStatus.completed,
    this.completedDate,
    this.coverUrl,
    this.externalUrl,
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
    this.universeName,
    this.collectionName,
    this.collectionNumber,
    this.showCollectionNumber = false,
    this.rewatchCount = 1,
    this.seasonCount,
    this.nextSeasonConfirmed = false,
    this.progressCurrent,
    this.progressTotal,
    this.progressSeason,
    this.publicationStatus,
    this.linkedGoalId,
    this.reading,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final LibraryItemType type;
  final String title;
  final LibraryItemStatus status;
  final DateTime? completedDate;
  final String? coverUrl;
  final String? externalUrl;
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
  /// Universo superior (p. ej. «Warhammer 40.000»); la saga cuelga de él.
  final String? universeName;
  final String? collectionName;
  final int? collectionNumber;
  final bool showCollectionNumber;
  final int rewatchCount;
  final int? seasonCount;
  final bool nextSeasonConfirmed;

  /// Progreso manual de series, anime y manga: episodio o capítulo actual.
  final int? progressCurrent;

  /// Total de episodios o capítulos.
  final int? progressTotal;

  /// Temporada actual (opcional, solo series y anime).
  final int? progressSeason;
  final LibraryPublicationStatus? publicationStatus;
  final String? linkedGoalId;
  final LibraryReading? reading;
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
    String? externalUrl,
    bool clearExternalUrl = false,
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
    String? universeName,
    bool clearUniverseName = false,
    String? collectionName,
    bool clearCollectionName = false,
    int? collectionNumber,
    bool clearCollectionNumber = false,
    bool? showCollectionNumber,
    int? rewatchCount,
    int? seasonCount,
    bool clearSeasonCount = false,
    bool? nextSeasonConfirmed,
    int? progressCurrent,
    bool clearProgressCurrent = false,
    int? progressTotal,
    bool clearProgressTotal = false,
    int? progressSeason,
    bool clearProgressSeason = false,
    LibraryPublicationStatus? publicationStatus,
    bool clearPublicationStatus = false,
    String? linkedGoalId,
    bool clearLinkedGoalId = false,
    LibraryReading? reading,
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
      externalUrl: clearExternalUrl ? null : externalUrl ?? this.externalUrl,
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
      universeName:
          clearUniverseName ? null : universeName ?? this.universeName,
      collectionName:
          clearCollectionName ? null : collectionName ?? this.collectionName,
      collectionNumber: clearCollectionNumber
          ? null
          : collectionNumber ?? this.collectionNumber,
      showCollectionNumber: showCollectionNumber ?? this.showCollectionNumber,
      rewatchCount: rewatchCount ?? this.rewatchCount,
      seasonCount: clearSeasonCount ? null : seasonCount ?? this.seasonCount,
      nextSeasonConfirmed: nextSeasonConfirmed ?? this.nextSeasonConfirmed,
      progressCurrent:
          clearProgressCurrent ? null : progressCurrent ?? this.progressCurrent,
      progressTotal:
          clearProgressTotal ? null : progressTotal ?? this.progressTotal,
      progressSeason:
          clearProgressSeason ? null : progressSeason ?? this.progressSeason,
      publicationStatus: clearPublicationStatus
          ? null
          : publicationStatus ?? this.publicationStatus,
      linkedGoalId:
          clearLinkedGoalId ? null : linkedGoalId ?? this.linkedGoalId,
      reading: reading ?? this.reading,
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
      'externalUrl': externalUrl,
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
      'universeName': universeName,
      'collectionName': collectionName,
      'collectionNumber': collectionNumber,
      'showCollectionNumber': showCollectionNumber,
      'rewatchCount': rewatchCount,
      'seasonCount': seasonCount,
      'nextSeasonConfirmed': nextSeasonConfirmed,
      'progressCurrent': progressCurrent,
      'progressTotal': progressTotal,
      'progressSeason': progressSeason,
      'publicationStatus': publicationStatus?.name,
      'linkedGoalId': linkedGoalId,
      'reading': reading?.toJson(),
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
      externalUrl: json['externalUrl'] as String?,
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
      universeName: json['universeName'] as String?,
      collectionName: json['collectionName'] as String?,
      collectionNumber: (json['collectionNumber'] as num?)?.toInt(),
      showCollectionNumber: json['showCollectionNumber'] as bool? ?? false,
      rewatchCount: ((json['rewatchCount'] as num?)?.toInt() ?? 1).clamp(1, 99),
      seasonCount: (json['seasonCount'] as num?)?.toInt(),
      nextSeasonConfirmed: json['nextSeasonConfirmed'] as bool? ?? false,
      progressCurrent: (json['progressCurrent'] as num?)?.toInt(),
      progressTotal: (json['progressTotal'] as num?)?.toInt(),
      progressSeason: (json['progressSeason'] as num?)?.toInt(),
      publicationStatus: json['publicationStatus'] == null
          ? null
          : enumByName(
              LibraryPublicationStatus.values,
              json['publicationStatus'] as String?,
              LibraryPublicationStatus.ongoing,
            ),
      linkedGoalId: json['linkedGoalId'] as String?,
      reading: json['reading'] is Map
          ? LibraryReading.fromJson(
              Map<String, dynamic>.from(json['reading'] as Map))
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          completed ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          completed ??
          DateTime.now(),
    );
  }
}

/// Devuelve un enlace web `http` o `https` limpio, o `null` si no es válido.
/// Si falta el esquema se asume `https`.
String? normalizarEnlaceExterno(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(
    texto.contains('://') ? texto : 'https://$texto',
  );
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      !uri.host.contains('.')) {
    return null;
  }
  return uri.toString();
}

/// Nombre de la ficha externa según el tipo de elemento: Goodreads para
/// libros y Letterboxd para películas y series.
String? nombreFichaExterna(LibraryItemType type) => switch (type) {
      LibraryItemType.book => 'Goodreads',
      LibraryItemType.movieSeries => 'Letterboxd',
      LibraryItemType.game => null,
    };

/// ¿Admite el elemento un progreso manual de episodios o capítulos?
bool admiteProgresoManual(LibraryItem item) => switch (item.type) {
      LibraryItemType.movieSeries => item.mediaType == LibraryMediaType.series,
      LibraryItemType.book => item.creatorOrDirector == 'Manga',
      LibraryItemType.game => false,
    };

/// Devuelve el elemento con un episodio o capítulo más, sin pasar del total
/// si lo hay. Si no admite progreso manual, lo devuelve sin cambios.
LibraryItem conUnaUnidadMasDeProgreso(LibraryItem item) {
  if (!admiteProgresoManual(item)) return item;
  final siguiente = (item.progressCurrent ?? 0) + 1;
  final total = item.progressTotal;
  final limitado =
      total != null && total > 0 && siguiente > total ? total : siguiente;
  return item.copyWith(progressCurrent: limitado);
}

/// Texto del progreso manual: «T1 · 3 / 9 episodios» o «24 / 86 capítulos».
String? textoProgresoManual(LibraryItem item) {
  if (!admiteProgresoManual(item)) return null;
  final actual = item.progressCurrent;
  final total = item.progressTotal;
  if (actual == null && total == null) return null;
  final esManga = item.type == LibraryItemType.book;
  final unidad = esManga ? 'capítulos' : 'episodios';
  final temporada = !esManga && item.progressSeason != null
      ? 'T${item.progressSeason} · '
      : '';
  final cuenta =
      total != null && total > 0 ? '${actual ?? 0} / $total' : '${actual ?? 0}';
  return '$temporada$cuenta $unidad';
}

/// Fracción de 0 a 1 del progreso manual, o `null` si no se puede calcular.
double? fraccionProgresoManual(LibraryItem item) {
  if (!admiteProgresoManual(item)) return null;
  final total = item.progressTotal;
  if (total == null || total <= 0) return null;
  return ((item.progressCurrent ?? 0) / total).clamp(0.0, 1.0);
}
