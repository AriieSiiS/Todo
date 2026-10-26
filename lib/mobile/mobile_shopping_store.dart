import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'mobile_shopping.dart';

class MobileShoppingStore {
  MobileShoppingStore({Directory? directory}) : _directoryOverride = directory;

  final Directory? _directoryOverride;

  Future<File> _file() async {
    final base = _directoryOverride ?? await getApplicationSupportDirectory();
    final directory = Directory(
      '${base.path}${Platform.pathSeparator}Todo${Platform.pathSeparator}lan_sync',
    );
    await directory.create(recursive: true);
    return File(
        '${directory.path}${Platform.pathSeparator}shopping_progress_v1.json');
  }

  Future<MobileShoppingProgress> load() async {
    final file = await _file();
    for (final candidate in [file, File('${file.path}.bak')]) {
      if (!await candidate.exists()) continue;
      try {
        return MobileShoppingProgress.fromJson(
          (jsonDecode(await candidate.readAsString()) as Map)
              .cast<String, dynamic>(),
        );
      } catch (_) {
        // Se intenta la última copia válida.
      }
    }
    return MobileShoppingProgress();
  }

  Future<void> save(MobileShoppingProgress progress) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    await temporary.writeAsString(jsonEncode(progress.toJson()), flush: true);
    if (!await file.exists() && await backup.exists()) {
      await backup.rename(file.path);
    }
    if (await backup.exists()) await backup.delete();
    if (await file.exists()) await file.rename(backup.path);
    try {
      await temporary.rename(file.path);
    } catch (_) {
      if (await backup.exists()) await backup.rename(file.path);
      rethrow;
    }
    if (await backup.exists()) await backup.delete();
  }

  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
    final backup = File('${file.path}.bak');
    if (await backup.exists()) await backup.delete();
  }
}
