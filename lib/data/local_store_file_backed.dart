import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/models.dart';
import 'local_store.dart';
import 'runtime_state_paths.dart';

class FileBackedLocalStore implements LocalStore {
  FileBackedLocalStore({Directory? baseDirectory})
      : _baseDirectoryOverride = baseDirectory;

  final Directory? _baseDirectoryOverride;
  Future<void> _pendingOperation = Future<void>.value();

  // Lecturas, recuperación y escrituras comparten los archivos temporales.
  // Un fallo se propaga al solicitante sin bloquear la siguiente operación.
  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _pendingOperation.then((_) => operation());
    _pendingOperation =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static const String _snapshotKey = 'todo.snapshot.v1';
  static const String _calendarSessionKey = 'todo.calendar.session.v1';
  static const String _syncMetadataKey = 'todo.sync.metadata.v1';

  @override
  Future<AppStateSnapshot?> load() => _enqueue(_load);

  Future<AppStateSnapshot?> _load() async {
    final file = await _stateFile();
    await _recoverInterruptedWrite(file);
    if (await file.exists()) {
      final raw = await file.readAsString();
      if (raw.trim().isNotEmpty) {
        return AppStateSnapshot.fromEncodedJson(raw);
      }
    }

    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_snapshotKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    await _writeAtomically(file, raw);
    return AppStateSnapshot.fromEncodedJson(raw);
  }

  @override
  Future<void> save(AppStateSnapshot snapshot) =>
      _enqueue(() => _save(snapshot));

  Future<void> _save(AppStateSnapshot snapshot) async {
    // Se serializa una sola vez y se escribe solo en el archivo de estado.
    await _writeAtomically(await _stateFile(), snapshot.toEncodedJson());
  }

  @override
  Future<String?> loadCalendarSession() => _enqueue(_loadCalendarSession);

  Future<String?> _loadCalendarSession() async {
    final file = await _sessionFile();
    await _recoverInterruptedWrite(file);
    if (await file.exists()) {
      final raw = await file.readAsString();
      if (raw.trim().isNotEmpty) {
        return raw;
      }
    }

    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_calendarSessionKey);
  }

  @override
  Future<void> saveCalendarSession(String encodedSession) =>
      _enqueue(() => _saveCalendarSession(encodedSession));

  Future<void> _saveCalendarSession(String encodedSession) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_calendarSessionKey, encodedSession);
    await _writeAtomically(await _sessionFile(), encodedSession);
  }

  @override
  Future<void> clearCalendarSession() => _enqueue(_clearCalendarSession);

  Future<void> _clearCalendarSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_calendarSessionKey);
    final file = await _sessionFile();
    for (final candidate in [
      file,
      File('${file.path}.tmp'),
      File('${file.path}.previous')
    ]) {
      if (await candidate.exists()) {
        await candidate.delete();
      }
    }
  }

  @override
  Future<LocalSyncMetadata> loadSyncMetadata() => _enqueue(_loadSyncMetadata);

  Future<LocalSyncMetadata> _loadSyncMetadata() async {
    final file = await _syncMetadataFile();
    await _recoverInterruptedWrite(file);
    if (await file.exists()) {
      final raw = await file.readAsString();
      if (raw.trim().isNotEmpty) {
        return LocalSyncMetadata.fromJson(
          (jsonDecode(raw) as Map<dynamic, dynamic>).cast<String, dynamic>(),
        );
      }
    }

    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_syncMetadataKey);
    if (raw == null || raw.isEmpty) {
      return const LocalSyncMetadata();
    }
    await _writeAtomically(file, raw);
    return LocalSyncMetadata.fromJson(
      (jsonDecode(raw) as Map<dynamic, dynamic>).cast<String, dynamic>(),
    );
  }

  @override
  Future<void> saveSyncMetadata(LocalSyncMetadata metadata) =>
      _enqueue(() => _saveSyncMetadata(metadata));

  Future<void> _saveSyncMetadata(LocalSyncMetadata metadata) async {
    final encoded = jsonEncode(metadata.toJson());
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_syncMetadataKey, encoded);
    await _writeAtomically(await _syncMetadataFile(), encoded);
  }

  Future<Directory> _runtimeDirectory() async {
    final base = await _baseTodoDirectory();
    final directory = Directory(
      '${base.path}${Platform.pathSeparator}${RuntimeStatePaths.runtimeDirectoryName}',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> _baseTodoDirectory() async {
    if (_baseDirectoryOverride != null) return _baseDirectoryOverride;
    if (Platform.isAndroid || Platform.isIOS) {
      final support = await getApplicationSupportDirectory();
      return Directory('${support.path}${Platform.pathSeparator}Todo');
    }
    return _documentsTodoDirectory();
  }

  Directory _documentsTodoDirectory() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final documents = Directory('$home${Platform.pathSeparator}Documents');
    if (documents.existsSync()) {
      return Directory(
        '${documents.path}${Platform.pathSeparator}Todo',
      );
    }
    return Directory(home);
  }

  Future<File> _stateFile() async {
    final runtimeDirectory = await _runtimeDirectory();
    return File(
      '${runtimeDirectory.path}${Platform.pathSeparator}${RuntimeStatePaths.stateFileName}',
    );
  }

  Future<File> _sessionFile() async {
    final runtimeDirectory = await _runtimeDirectory();
    return File(
      '${runtimeDirectory.path}${Platform.pathSeparator}${RuntimeStatePaths.calendarSessionFileName}',
    );
  }

  Future<File> _syncMetadataFile() async {
    final runtimeDirectory = await _runtimeDirectory();
    return File(
      '${runtimeDirectory.path}${Platform.pathSeparator}${RuntimeStatePaths.syncMetadataFileName}',
    );
  }

  Future<void> _writeAtomically(File file, String contents) async {
    final temp = File('${file.path}.tmp');
    final previous = File('${file.path}.previous');
    if (!await temp.parent.exists()) {
      await temp.parent.create(recursive: true);
    }
    await temp.writeAsString(contents, flush: true);
    if (await file.exists()) {
      await file.copy(previous.path);
    }
    try {
      if (await file.exists()) {
        await file.delete();
      }
      await temp.rename(file.path);
      if (await previous.exists()) {
        await previous.delete();
      }
    } catch (_) {
      if (!await file.exists() && await previous.exists()) {
        await previous.copy(file.path);
      }
      rethrow;
    }
  }

  Future<void> _recoverInterruptedWrite(File file) async {
    if (await file.exists()) return;
    final temp = File('${file.path}.tmp');
    final previous = File('${file.path}.previous');
    if (await temp.exists() && await _containsValidJson(temp)) {
      await temp.rename(file.path);
      return;
    }
    if (await previous.exists() && await _containsValidJson(previous)) {
      await previous.copy(file.path);
    }
  }

  Future<bool> _containsValidJson(File file) async {
    try {
      jsonDecode(await file.readAsString());
      return true;
    } catch (_) {
      return false;
    }
  }
}

LocalStore createLocalStore() => FileBackedLocalStore();
