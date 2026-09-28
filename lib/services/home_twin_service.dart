import 'dart:convert';
import 'dart:io';

import '../domain/entities/home_twin.dart';
import 'household_asset_service.dart';

class HomeTwinService {
  HomeTwinService({Directory? rootOverride})
      : _assets = HouseholdAssetService(rootOverride: rootOverride);

  final HouseholdAssetService _assets;
  Future<void> _windowWrites = Future<void>.value();

  Future<File> _windowStateFile() async {
    final directory = await root();
    return File('${directory.path}${Platform.pathSeparator}window_state.json');
  }

  Future<Map<String, bool>> _loadWindowStates() async {
    final file = await _windowStateFile();
    if (!await file.exists()) return {};
    try {
      final value = jsonDecode(await file.readAsString());
      if (value is! Map) return {};
      final windows = value['windows'];
      if (windows is Map) {
        return {
          for (final entry in windows.entries)
            if (entry.key is String) entry.key as String: entry.value == true,
        };
      }
      return {'dormitorio': value['open'] == true};
    } catch (_) {
      return {};
    }
  }

  Future<bool> loadWindowOpen([String roomId = 'dormitorio']) async =>
      (await _loadWindowStates())[roomId] ?? false;

  Future<void> saveWindowOpen(bool open, [String roomId = 'dormitorio']) {
    _windowWrites = _windowWrites.catchError((Object _) {}).then((_) async {
      final file = await _windowStateFile();
      await file.parent.create(recursive: true);
      final windows = await _loadWindowStates();
      windows[roomId] = open;
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        jsonEncode({'schemaVersion': 2, 'windows': windows}),
        flush: true,
      );
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
    });
    return _windowWrites;
  }

  Future<Directory> root() async {
    final household = await _assets.householdDirectory();
    return Directory('${household.path}${Platform.pathSeparator}twin');
  }

  Future<HomeTwinScene> load() async {
    final directory = await root();
    final file = File('${directory.path}${Platform.pathSeparator}house.json');
    if (!await file.exists()) return const HomeTwinScene();
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El gemelo de la casa no es válido.');
    }
    final scene = HomeTwinScene.fromJson(decoded);
    for (final room in scene.rooms) {
      if (room.id.isEmpty || room.name.isEmpty) {
        throw const FormatException(
            'Una habitación no tiene identidad válida.');
      }
      if (await modelFile(room.modelPath) == null) {
        throw FormatException('Falta el modelo de ${room.name}.');
      }
    }
    return scene;
  }

  Future<File?> modelFile(String relativePath) async {
    if (!RegExp(r'^models/[a-zA-Z0-9_-]+\.glb$').hasMatch(relativePath)) {
      return null;
    }
    final directory = await root();
    final path = relativePath.replaceAll('/', Platform.pathSeparator);
    final file = File('${directory.path}${Platform.pathSeparator}$path');
    return await file.exists() ? file : null;
  }
}
