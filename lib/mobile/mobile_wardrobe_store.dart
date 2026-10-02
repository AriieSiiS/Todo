import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'mobile_wardrobe_snapshot.dart';

class MobileWardrobeStore {
  MobileWardrobeStore({Directory? directory}) : _directoryOverride = directory;

  final Directory? _directoryOverride;

  Future<Directory> _directory() async {
    if (_directoryOverride != null) {
      await _directoryOverride.create(recursive: true);
      return _directoryOverride;
    }
    final root = await getApplicationSupportDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}Todo${Platform.pathSeparator}lan_sync${Platform.pathSeparator}wardrobe',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> _file(String name) async =>
      File('${(await _directory()).path}${Platform.pathSeparator}$name');

  Future<MobileWardrobeSnapshot?> loadSnapshot() async {
    final file = await _file('snapshot_v1.json');
    if (!await file.exists()) return null;
    try {
      return MobileWardrobeSnapshot.fromJson(
        (jsonDecode(await file.readAsString()) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSnapshot(MobileWardrobeSnapshot snapshot) async {
    await _writeJson(await _file('snapshot_v1.json'), snapshot.toJson());
  }

  Future<Map<String, Map<String, int>>> loadUsage() async {
    final file = await _file('usage_v1.json');
    if (!await file.exists()) return {};
    try {
      final decoded = (jsonDecode(await file.readAsString()) as Map);
      return {
        for (final trip in decoded.entries)
          trip.key.toString(): {
            for (final item in (trip.value as Map).entries)
              item.key.toString(): (item.value as num).toInt(),
          },
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> saveUsage(Map<String, Map<String, int>> usage) async {
    await _writeJson(await _file('usage_v1.json'), usage);
  }

  Future<bool> hasImage(String itemId, String variant, String digest) async {
    final file = await imageFile(itemId, variant, digest);
    return file != null && await file.exists() && await file.length() > 0;
  }

  Future<File?> imageFile(String itemId, String variant, String digest) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(itemId) ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(digest) ||
        (variant != 'thumbnail' && variant != 'original')) {
      return null;
    }
    return _file('$itemId-$variant-${digest.toLowerCase()}.png');
  }

  Future<void> saveImage(
    String itemId,
    String variant,
    String digest,
    List<int> bytes,
  ) async {
    if (sha256.convert(bytes).toString() != digest.toLowerCase()) {
      throw const FormatException(
          'La foto descargada no supera la verificación.');
    }
    final file = await imageFile(itemId, variant, digest);
    if (file == null) {
      throw const FormatException('Identificador de foto inválido.');
    }
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file.path);
  }

  Future<void> clear() async {
    final directory = await _directory();
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> _writeJson(File file, Object value) async {
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await temporary.rename(file.path);
  }
}
