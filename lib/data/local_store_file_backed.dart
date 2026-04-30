import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import 'local_store.dart';
import 'runtime_state_paths.dart';

class FileBackedLocalStore implements LocalStore {
  static const String _snapshotKey = 'todo.snapshot.v1';
  static const String _calendarSessionKey = 'todo.calendar.session.v1';

  @override
  Future<AppStateSnapshot?> load() async {
    final file = await _stateFile();
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
  Future<void> save(AppStateSnapshot snapshot) async {
    final encoded = snapshot.toEncodedJson();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_snapshotKey, encoded);
    await _writeAtomically(await _stateFile(), encoded);
  }

  @override
  Future<String?> loadCalendarSession() async {
    final file = await _sessionFile();
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
  Future<void> saveCalendarSession(String encodedSession) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_calendarSessionKey, encodedSession);
    await _writeAtomically(await _sessionFile(), encodedSession);
  }

  @override
  Future<void> clearCalendarSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_calendarSessionKey);
    final file = await _sessionFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _runtimeDirectory() async {
    final base = _documentsTodoDirectory();
    final directory = Directory(
      '${base.path}${Platform.pathSeparator}${RuntimeStatePaths.runtimeDirectoryName}',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
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

  Future<void> _writeAtomically(File file, String contents) async {
    final temp = File('${file.path}.tmp');
    if (!await temp.parent.exists()) {
      await temp.parent.create(recursive: true);
    }
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonDecode(contents)),
    );
    await temp.rename(file.path);
  }
}

LocalStore createLocalStore() => FileBackedLocalStore();
