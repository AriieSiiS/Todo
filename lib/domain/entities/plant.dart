import 'enums.dart';
import 'json_helpers.dart';
import 'recurrence_rule.dart';

class PlantSource {
  const PlantSource({required this.title, required this.url});

  final String title;
  final String url;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'url': url,
      };

  factory PlantSource.fromJson(Map<String, dynamic> json) => PlantSource(
        title: json['title'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );
}

class PlantCareRoutine {
  const PlantCareRoutine({
    required this.id,
    required this.type,
    required this.title,
    required this.instructions,
    required this.firstDueDate,
    required this.recurrence,
    this.enabled = true,
  });

  final String id;
  final PlantCareType type;
  final String title;
  final String instructions;
  final DateTime firstDueDate;
  final RecurrenceRule recurrence;
  final bool enabled;

  PlantCareRoutine copyWith({
    PlantCareType? type,
    String? title,
    String? instructions,
    DateTime? firstDueDate,
    RecurrenceRule? recurrence,
    bool? enabled,
  }) {
    return PlantCareRoutine(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      instructions: instructions ?? this.instructions,
      firstDueDate: firstDueDate ?? this.firstDueDate,
      recurrence: recurrence ?? this.recurrence,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'title': title,
        'instructions': instructions,
        'firstDueDate': firstDueDate.toIso8601String(),
        'recurrence': recurrence.toJson(),
        'enabled': enabled,
      };

  factory PlantCareRoutine.fromJson(Map<String, dynamic> json) =>
      PlantCareRoutine(
        id: json['id'] as String? ?? '',
        type: enumByName(
          PlantCareType.values,
          json['type'] as String?,
          PlantCareType.custom,
        ),
        title: json['title'] as String? ?? 'Cuidado de la planta',
        instructions: json['instructions'] as String? ?? '',
        firstDueDate:
            DateTime.tryParse(json['firstDueDate'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
        recurrence: RecurrenceRule.fromJson(
          (json['recurrence'] as Map<dynamic, dynamic>? ??
                  const <dynamic, dynamic>{})
              .cast<String, dynamic>(),
        ),
        enabled: json['enabled'] as bool? ?? true,
      );
}

class PlantPhoto {
  const PlantPhoto(
      {required this.id,
      required this.takenAt,
      required this.imagePath,
      required this.thumbnailPath,
      required this.imageSha256,
      this.notes = ''});
  final String id;
  final DateTime takenAt;
  final String imagePath;
  final String thumbnailPath;
  final String imageSha256;
  final String notes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'takenAt': takenAt.toIso8601String(),
        'imagePath': imagePath,
        'thumbnailPath': thumbnailPath,
        'imageSha256': imageSha256,
        'notes': notes,
      };
  factory PlantPhoto.fromJson(Map<String, dynamic> json) => PlantPhoto(
        id: json['id'] as String? ?? '',
        takenAt: DateTime.tryParse(json['takenAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        imagePath: json['imagePath'] as String? ?? '',
        thumbnailPath: json['thumbnailPath'] as String? ?? '',
        imageSha256: json['imageSha256'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );
}

class Plant {
  const Plant({
    required this.id,
    required this.name,
    required this.commonName,
    required this.scientificName,
    required this.createdAt,
    required this.updatedAt,
    this.cultivar = '',
    this.location = '',
    this.acquiredAt,
    this.description = '',
    this.light = '',
    this.watering = '',
    this.humidity = '',
    this.temperature = '',
    this.substrate = '',
    this.fertilizing = '',
    this.pruning = '',
    this.propagation = '',
    this.repotting = '',
    this.commonProblems = '',
    this.catSafety = PlantCatSafety.unknown,
    this.catSafetyNotes = '',
    this.sources = const <PlantSource>[],
    this.routines = const <PlantCareRoutine>[],
    this.tags = const <String>[],
    this.notes = '',
    this.imagePath = '',
    this.thumbnailPath = '',
    this.imageSha256 = '',
    this.photos = const <PlantPhoto>[],
    this.archived = false,
  });

  final String id;
  final String name;
  final String commonName;
  final String scientificName;
  final String cultivar;
  final String location;
  final DateTime? acquiredAt;
  final String description;
  final String light;
  final String watering;
  final String humidity;
  final String temperature;
  final String substrate;
  final String fertilizing;
  final String pruning;
  final String propagation;
  final String repotting;
  final String commonProblems;
  final PlantCatSafety catSafety;
  final String catSafetyNotes;
  final List<PlantSource> sources;
  final List<PlantCareRoutine> routines;
  final List<String> tags;
  final String notes;
  final String imagePath;
  final String thumbnailPath;
  final String imageSha256;
  final List<PlantPhoto> photos;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  Plant copyWith({
    String? name,
    String? commonName,
    String? scientificName,
    String? cultivar,
    String? location,
    DateTime? acquiredAt,
    bool clearAcquiredAt = false,
    String? description,
    String? light,
    String? watering,
    String? humidity,
    String? temperature,
    String? substrate,
    String? fertilizing,
    String? pruning,
    String? propagation,
    String? repotting,
    String? commonProblems,
    PlantCatSafety? catSafety,
    String? catSafetyNotes,
    List<PlantSource>? sources,
    List<PlantCareRoutine>? routines,
    List<String>? tags,
    String? notes,
    String? imagePath,
    String? thumbnailPath,
    String? imageSha256,
    List<PlantPhoto>? photos,
    bool? archived,
    DateTime? updatedAt,
  }) {
    return Plant(
      id: id,
      name: name ?? this.name,
      commonName: commonName ?? this.commonName,
      scientificName: scientificName ?? this.scientificName,
      cultivar: cultivar ?? this.cultivar,
      location: location ?? this.location,
      acquiredAt: clearAcquiredAt ? null : acquiredAt ?? this.acquiredAt,
      description: description ?? this.description,
      light: light ?? this.light,
      watering: watering ?? this.watering,
      humidity: humidity ?? this.humidity,
      temperature: temperature ?? this.temperature,
      substrate: substrate ?? this.substrate,
      fertilizing: fertilizing ?? this.fertilizing,
      pruning: pruning ?? this.pruning,
      propagation: propagation ?? this.propagation,
      repotting: repotting ?? this.repotting,
      commonProblems: commonProblems ?? this.commonProblems,
      catSafety: catSafety ?? this.catSafety,
      catSafetyNotes: catSafetyNotes ?? this.catSafetyNotes,
      sources: sources ?? this.sources,
      routines: routines ?? this.routines,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      imageSha256: imageSha256 ?? this.imageSha256,
      photos: photos ?? this.photos,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'commonName': commonName,
        'scientificName': scientificName,
        'cultivar': cultivar,
        'location': location,
        'acquiredAt': acquiredAt?.toIso8601String(),
        'description': description,
        'light': light,
        'watering': watering,
        'humidity': humidity,
        'temperature': temperature,
        'substrate': substrate,
        'fertilizing': fertilizing,
        'pruning': pruning,
        'propagation': propagation,
        'repotting': repotting,
        'commonProblems': commonProblems,
        'catSafety': catSafety.name,
        'catSafetyNotes': catSafetyNotes,
        'sources': sources.map((source) => source.toJson()).toList(),
        'routines': routines.map((routine) => routine.toJson()).toList(),
        'tags': tags,
        'notes': notes,
        'imagePath': imagePath,
        'thumbnailPath': thumbnailPath,
        'imageSha256': imageSha256,
        'photos': photos.map((photo) => photo.toJson()).toList(),
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Plant.fromJson(Map<String, dynamic> json) => Plant(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Planta sin nombre',
        commonName: json['commonName'] as String? ?? '',
        scientificName: json['scientificName'] as String? ?? '',
        cultivar: json['cultivar'] as String? ?? '',
        location: json['location'] as String? ?? '',
        acquiredAt: DateTime.tryParse(json['acquiredAt'] as String? ?? ''),
        description: json['description'] as String? ?? '',
        light: json['light'] as String? ?? '',
        watering: json['watering'] as String? ?? '',
        humidity: json['humidity'] as String? ?? '',
        temperature: json['temperature'] as String? ?? '',
        substrate: json['substrate'] as String? ?? '',
        fertilizing: json['fertilizing'] as String? ?? '',
        pruning: json['pruning'] as String? ?? '',
        propagation: json['propagation'] as String? ?? '',
        repotting: json['repotting'] as String? ?? '',
        commonProblems: json['commonProblems'] as String? ?? '',
        catSafety: enumByName(
          PlantCatSafety.values,
          json['catSafety'] as String?,
          PlantCatSafety.unknown,
        ),
        catSafetyNotes: json['catSafetyNotes'] as String? ?? '',
        sources: (json['sources'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map((value) => PlantSource.fromJson(value.cast<String, dynamic>()))
            .toList(),
        routines: (json['routines'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map((value) =>
                PlantCareRoutine.fromJson(value.cast<String, dynamic>()))
            .toList(),
        tags: stringList(json['tags']),
        notes: json['notes'] as String? ?? '',
        imagePath: json['imagePath'] as String? ?? '',
        thumbnailPath: json['thumbnailPath'] as String? ?? '',
        imageSha256: json['imageSha256'] as String? ?? '',
        photos: (json['photos'] as List<dynamic>? ?? const [])
            .map((photo) =>
                PlantPhoto.fromJson((photo as Map).cast<String, dynamic>()))
            .toList(),
        archived: json['archived'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
