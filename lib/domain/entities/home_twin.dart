class HomeTwinScene {
  const HomeTwinScene({this.rooms = const <HomeTwinRoom>[]});

  final List<HomeTwinRoom> rooms;

  factory HomeTwinScene.fromJson(Map<String, dynamic> json) {
    return HomeTwinScene(
      rooms: (json['rooms'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map((value) => HomeTwinRoom.fromJson(value.cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': 1,
        'rooms': rooms.map((room) => room.toJson()).toList(),
      };
}

class HomeTwinRoom {
  const HomeTwinRoom({
    required this.id,
    required this.name,
    required this.modelPath,
    required this.position,
    this.floor = 0,
    this.rotationDegrees = 0,
    this.objects = const <HomeTwinObject>[],
  });

  final String id;
  final String name;
  final String modelPath;
  final HomeTwinPosition position;
  final int floor;
  final double rotationDegrees;
  final List<HomeTwinObject> objects;

  factory HomeTwinRoom.fromJson(Map<String, dynamic> json) => HomeTwinRoom(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        modelPath: json['modelPath'] as String? ?? '',
        position: HomeTwinPosition.fromJson(
          (json['position'] as Map<dynamic, dynamic>? ??
                  const <dynamic, dynamic>{})
              .cast<String, dynamic>(),
        ),
        floor: (json['floor'] as num?)?.toInt() ?? 0,
        rotationDegrees: (json['rotationDegrees'] as num?)?.toDouble() ?? 0,
        objects: (json['objects'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map((value) =>
                HomeTwinObject.fromJson(value.cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'modelPath': modelPath,
        'position': position.toJson(),
        'floor': floor,
        'rotationDegrees': rotationDegrees,
        'objects': objects.map((object) => object.toJson()).toList(),
      };
}

class HomeTwinPosition {
  const HomeTwinPosition({this.x = 0, this.y = 0, this.z = 0});

  final double x;
  final double y;
  final double z;

  factory HomeTwinPosition.fromJson(Map<String, dynamic> json) =>
      HomeTwinPosition(
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        z: (json['z'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'x': x,
        'y': y,
        'z': z,
      };
}

class HomeTwinObject {
  const HomeTwinObject({
    required this.id,
    required this.name,
    required this.nodeName,
    this.kind = 'otro',
    this.householdItemId,
  });

  final String id;
  final String name;
  final String nodeName;
  final String kind;
  final String? householdItemId;

  factory HomeTwinObject.fromJson(Map<String, dynamic> json) => HomeTwinObject(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        nodeName: json['nodeName'] as String? ?? '',
        kind: json['kind'] as String? ?? 'otro',
        householdItemId: json['householdItemId'] as String?,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'nodeName': nodeName,
        'kind': kind,
        'householdItemId': householdItemId,
      };
}
