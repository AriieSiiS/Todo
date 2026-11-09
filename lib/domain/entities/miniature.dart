/// Estado de montaje y pintura de una miniatura, en el orden en que avanza.
enum MiniatureStatus { unbuilt, built, primed, painting, painted }

extension MiniatureStatusLabel on MiniatureStatus {
  String get label => switch (this) {
        MiniatureStatus.unbuilt => 'Sin montar',
        MiniatureStatus.built => 'Montada',
        MiniatureStatus.primed => 'Imprimada',
        MiniatureStatus.painting => 'Pintando',
        MiniatureStatus.painted => 'Terminada',
      };

  /// Etiqueta para un grupo de miniaturas (en plural).
  String get pluralLabel => switch (this) {
        MiniatureStatus.unbuilt => 'Sin montar',
        MiniatureStatus.built => 'Montadas',
        MiniatureStatus.primed => 'Imprimadas',
        MiniatureStatus.painting => 'Pintando',
        MiniatureStatus.painted => 'Terminadas',
      };
}

MiniatureStatus _statusFromJson(Object? value) {
  for (final status in MiniatureStatus.values) {
    if (status.name == value) return status;
  }
  return MiniatureStatus.unbuilt;
}

/// Una figura concreta de la caja, con su propio avance.
class MiniatureModel {
  const MiniatureModel({
    required this.id,
    required this.name,
    this.status = MiniatureStatus.unbuilt,
  });

  final String id;
  final String name;
  final MiniatureStatus status;

  MiniatureModel copyWith({String? name, MiniatureStatus? status}) =>
      MiniatureModel(
        id: id,
        name: name ?? this.name,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'status': status.name,
      };

  factory MiniatureModel.fromJson(Map<String, dynamic> json) => MiniatureModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        status: _statusFromJson(json['status']),
      );
}

/// Pintura que pide la guía, con su tipo (base, lavado, capa…) y si ya se
/// tiene.
class MiniaturePaint {
  const MiniaturePaint({
    required this.name,
    this.kind = '',
    this.color = '',
    this.owned = false,
  });

  final String name;
  final String kind;

  /// Color aproximado del bote, en formato `#RRGGBB`.
  final String color;
  final bool owned;

  MiniaturePaint copyWith({
    String? name,
    String? kind,
    String? color,
    bool? owned,
  }) =>
      MiniaturePaint(
        name: name ?? this.name,
        kind: kind ?? this.kind,
        color: color ?? this.color,
        owned: owned ?? this.owned,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'kind': kind,
        'color': color,
        'owned': owned,
      };

  factory MiniaturePaint.fromJson(Map<String, dynamic> json) => MiniaturePaint(
        name: json['name'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        color: json['color'] as String? ?? '',
        owned: json['owned'] as bool? ?? false,
      );
}

/// Paso de la guía de pintura.
class MiniaturePaintStep {
  const MiniaturePaintStep({
    required this.title,
    this.description = '',
    this.paints = const <String>[],
    this.phase = '',
    this.zones = const <String, String>{},
    this.done = false,
  });

  final String title;
  final String description;
  final List<String> paints;

  /// Fase del proceso (Montaje, Imprimación, Armadura…), para el diagrama.
  final String phase;

  /// Color que deja este paso en cada zona del modelo 3D. Un asterisco final
  /// indica acabado metálico; la zona «todo» colorea la figura entera.
  final Map<String, String> zones;
  final bool done;

  MiniaturePaintStep copyWith({
    String? title,
    String? description,
    List<String>? paints,
    bool? done,
  }) =>
      MiniaturePaintStep(
        title: title ?? this.title,
        description: description ?? this.description,
        paints: paints ?? this.paints,
        phase: phase,
        zones: zones,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'description': description,
        'paints': paints,
        'phase': phase,
        'zones': zones,
        'done': done,
      };

  factory MiniaturePaintStep.fromJson(Map<String, dynamic> json) {
    final zonas = json['zones'];
    return MiniaturePaintStep(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      paints: (json['paints'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
      phase: json['phase'] as String? ?? '',
      zones: <String, String>{
        if (zonas is Map)
          for (final entry in zonas.entries)
            if (entry.value is String)
              entry.key.toString(): entry.value as String,
      },
      done: json['done'] as bool? ?? false,
    );
  }
}

/// Paso de montaje con su imagen de las instrucciones.
class MiniatureAssemblyStep {
  const MiniatureAssemblyStep({
    required this.title,
    this.description = '',
    this.imagePath = '',
    this.done = false,
  });

  final String title;
  final String description;
  final String imagePath;
  final bool done;

  MiniatureAssemblyStep copyWith({bool? done}) => MiniatureAssemblyStep(
        title: title,
        description: description,
        imagePath: imagePath,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'description': description,
        'imagePath': imagePath,
        'done': done,
      };

  factory MiniatureAssemblyStep.fromJson(Map<String, dynamic> json) =>
      MiniatureAssemblyStep(
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        imagePath: json['imagePath'] as String? ?? '',
        done: json['done'] as bool? ?? false,
      );
}

/// Foto propia de las miniaturas ya pintadas.
class MiniaturePhoto {
  const MiniaturePhoto({
    required this.id,
    required this.imagePath,
    required this.createdAt,
    this.thumbnailPath = '',
    this.caption = '',
  });

  final String id;
  final String imagePath;
  final String thumbnailPath;
  final String caption;
  final DateTime createdAt;

  MiniaturePhoto copyWith({String? caption}) => MiniaturePhoto(
        id: id,
        imagePath: imagePath,
        thumbnailPath: thumbnailPath,
        caption: caption ?? this.caption,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'imagePath': imagePath,
        'thumbnailPath': thumbnailPath,
        'caption': caption,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MiniaturePhoto.fromJson(Map<String, dynamic> json) => MiniaturePhoto(
        id: json['id'] as String? ?? '',
        imagePath: json['imagePath'] as String? ?? '',
        thumbnailPath: json['thumbnailPath'] as String? ?? '',
        caption: json['caption'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Caja o unidad de miniaturas (por ejemplo, una escuadra de Warhammer), con
/// sus figuras, la guía de pintura y las fotos propias.
class MiniatureKit {
  const MiniatureKit({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.game = '',
    this.faction = '',
    this.note = '',
    this.externalUrl = '',
    this.imagePath = '',
    this.thumbnailPath = '',
    this.coverPath = '',
    this.heroPath = '',
    this.gallery = const <String>[],
    this.assembly = const <MiniatureAssemblyStep>[],
    this.models = const <MiniatureModel>[],
    this.paints = const <MiniaturePaint>[],
    this.guide = const <MiniaturePaintStep>[],
    this.photos = const <MiniaturePhoto>[],
  });

  final String id;
  final String name;

  /// Juego o sistema, como «Warhammer 40.000».
  final String game;
  final String faction;
  final String note;
  final String externalUrl;

  /// Imagen de la caja, relativa a la carpeta de miniaturas.
  final String imagePath;
  final String thumbnailPath;

  /// Foto de la miniatura pintada para la portada.
  final String coverPath;

  /// Imagen ancha para la cabecera de la ficha.
  final String heroPath;

  /// Fotos de referencia oficiales.
  final List<String> gallery;
  final List<MiniatureAssemblyStep> assembly;
  final List<MiniatureModel> models;
  final List<MiniaturePaint> paints;
  final List<MiniaturePaintStep> guide;
  final List<MiniaturePhoto> photos;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasImage => imagePath.isNotEmpty;

  /// Imagen para la portada: la miniatura pintada si existe, si no la caja.
  String get coverImage => coverPath.isNotEmpty
      ? coverPath
      : (thumbnailPath.isNotEmpty ? thumbnailPath : imagePath);

  int get assemblyDone => assembly.where((step) => step.done).length;

  int get guideDone => guide.where((step) => step.done).length;

  MiniaturePaint? paintNamed(String name) {
    for (final paint in paints) {
      if (paint.name == name) return paint;
    }
    return null;
  }

  int countWith(MiniatureStatus status) =>
      models.where((model) => model.status == status).length;

  int get paintedCount => countWith(MiniatureStatus.painted);

  /// El estado más atrasado de sus figuras: la caja no está terminada hasta
  /// que lo están todas.
  MiniatureStatus get status {
    if (models.isEmpty) return MiniatureStatus.unbuilt;
    var lowest = MiniatureStatus.painted;
    for (final model in models) {
      if (model.status.index < lowest.index) lowest = model.status;
    }
    return lowest;
  }

  /// Avance de 0 a 1: cada figura suma según su estado.
  double get progress {
    if (models.isEmpty) return 0;
    final steps = MiniatureStatus.values.length - 1;
    final total =
        models.fold<int>(0, (sum, model) => sum + model.status.index);
    return total / (steps * models.length);
  }

  MiniatureKit copyWith({
    String? name,
    String? game,
    String? faction,
    String? note,
    String? externalUrl,
    String? imagePath,
    String? thumbnailPath,
    String? coverPath,
    String? heroPath,
    List<String>? gallery,
    List<MiniatureAssemblyStep>? assembly,
    List<MiniatureModel>? models,
    List<MiniaturePaint>? paints,
    List<MiniaturePaintStep>? guide,
    List<MiniaturePhoto>? photos,
    DateTime? updatedAt,
  }) =>
      MiniatureKit(
        id: id,
        name: name ?? this.name,
        game: game ?? this.game,
        faction: faction ?? this.faction,
        note: note ?? this.note,
        externalUrl: externalUrl ?? this.externalUrl,
        imagePath: imagePath ?? this.imagePath,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        coverPath: coverPath ?? this.coverPath,
        heroPath: heroPath ?? this.heroPath,
        gallery: gallery ?? this.gallery,
        assembly: assembly ?? this.assembly,
        models: models ?? this.models,
        paints: paints ?? this.paints,
        guide: guide ?? this.guide,
        photos: photos ?? this.photos,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'game': game,
        'faction': faction,
        'note': note,
        'externalUrl': externalUrl,
        'imagePath': imagePath,
        'thumbnailPath': thumbnailPath,
        'coverPath': coverPath,
        'heroPath': heroPath,
        'gallery': gallery,
        'assembly': assembly.map((item) => item.toJson()).toList(),
        'models': models.map((item) => item.toJson()).toList(),
        'paints': paints.map((item) => item.toJson()).toList(),
        'guide': guide.map((item) => item.toJson()).toList(),
        'photos': photos.map((item) => item.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MiniatureKit.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now();
    List<Map<String, dynamic>> lista(String key) =>
        (json[key] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList();
    return MiniatureKit(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      game: json['game'] as String? ?? '',
      faction: json['faction'] as String? ?? '',
      note: json['note'] as String? ?? '',
      externalUrl: json['externalUrl'] as String? ?? '',
      imagePath: json['imagePath'] as String? ?? '',
      thumbnailPath: json['thumbnailPath'] as String? ?? '',
      coverPath: json['coverPath'] as String? ?? '',
      heroPath: json['heroPath'] as String? ?? '',
      gallery: (json['gallery'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
      assembly: lista('assembly').map(MiniatureAssemblyStep.fromJson).toList(),
      models: lista('models').map(MiniatureModel.fromJson).toList(),
      paints: lista('paints').map(MiniaturePaint.fromJson).toList(),
      guide: lista('guide').map(MiniaturePaintStep.fromJson).toList(),
      photos: lista('photos').map(MiniaturePhoto.fromJson).toList(),
      createdAt: created,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? created,
    );
  }
}
