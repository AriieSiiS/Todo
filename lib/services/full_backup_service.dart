import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class FullBackupSummary {
  const FullBackupSummary({
    required this.createdAt,
    required this.directoryPath,
    required this.verifiedFiles,
    required this.totalBytes,
  });

  final DateTime createdAt;
  final String directoryPath;
  final int verifiedFiles;
  final int totalBytes;
}

class FullBackupOverview {
  const FullBackupOverview({
    this.latest,
    this.errorMessage,
    this.inProgress = false,
  });

  final FullBackupSummary? latest;
  final String? errorMessage;
  final bool inProgress;
}

class FullBackupService {
  FullBackupService({
    Directory? sourceDirectory,
    Directory? destinationRoot,
    AssetBundle? assetBundle,
  })  : _sourceDirectory = sourceDirectory,
        _destinationRoot = destinationRoot,
        _assetBundle = assetBundle ?? rootBundle;

  static const String _scriptAsset = 'tooling/backup_todo_data_full.ps1';

  final Directory? _sourceDirectory;
  final Directory? _destinationRoot;
  final AssetBundle _assetBundle;

  bool get isSupported => Platform.isWindows;

  Directory get sourceDirectory => _sourceDirectory ?? _defaultTodoDirectory();

  Directory get destinationRoot =>
      _destinationRoot ?? _defaultBackupDirectory();

  File get statusFile => File(
        '${destinationRoot.path}${Platform.pathSeparator}last_backup_status.json',
      );

  Future<FullBackupOverview> loadOverview() async {
    if (!isSupported) {
      return const FullBackupOverview(
        errorMessage:
            'Las copias completas desde la app solo están disponibles en Windows.',
      );
    }

    FullBackupSummary? latest;
    if (await destinationRoot.exists()) {
      await for (final entry in destinationRoot.list(followLinks: false)) {
        if (entry is! Directory ||
            !_fileName(entry.path).startsWith('Todo-completo-')) {
          continue;
        }
        final summary = await _readManifest(entry);
        if (summary != null &&
            (latest == null || summary.createdAt.isAfter(latest.createdAt))) {
          latest = summary;
        }
      }
    }

    String? errorMessage;
    var inProgress = false;
    final status = await _readJsonFile(statusFile);
    if (status != null) {
      final state = status['status'] as String? ?? '';
      if (state == 'error') {
        errorMessage = status['message'] as String? ??
            'La última copia no pudo completarse.';
      } else if (state == 'en_curso') {
        final startedAt =
            DateTime.tryParse(status['startedAt'] as String? ?? '');
        if (startedAt != null &&
            DateTime.now().difference(startedAt) <
                const Duration(minutes: 30)) {
          inProgress = true;
        } else {
          errorMessage = 'La última copia no terminó correctamente.';
        }
      }
    }

    return FullBackupOverview(
      latest: latest,
      errorMessage: errorMessage,
      inProgress: inProgress,
    );
  }

  Future<void> scheduleAfterAppCloses() async {
    if (!isSupported) {
      throw UnsupportedError(
        'Las copias completas desde la app solo están disponibles en Windows.',
      );
    }
    if (!await sourceDirectory.exists()) {
      throw StateError(
        'No se encuentra la carpeta de datos: ${sourceDirectory.path}',
      );
    }

    await destinationRoot.create(recursive: true);
    await _writeJsonAtomically(statusFile, <String, Object?>{
      'status': 'en_curso',
      'startedAt': DateTime.now().toIso8601String(),
    });

    File? scriptFile;
    try {
      final scriptSource = await _assetBundle.loadString(_scriptAsset);
      scriptFile = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'todo_backup_helper_${pid}_${DateTime.now().microsecondsSinceEpoch}.ps1',
      );
      await scriptFile.writeAsBytes(
        <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(scriptSource)],
        flush: true,
      );

      await Process.start(
        'powershell.exe',
        <String>[
          '-NoProfile',
          '-WindowStyle',
          'Hidden',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          scriptFile.path,
          '-SourceDirectory',
          sourceDirectory.path,
          '-DestinationRoot',
          destinationRoot.path,
          '-WaitForProcessId',
          '$pid',
          '-RelaunchExecutable',
          Platform.resolvedExecutable,
          '-StatusPath',
          statusFile.path,
          '-DeleteSelfWhenDone',
        ],
        mode: ProcessStartMode.detached,
      );
    } catch (_) {
      if (scriptFile != null && await scriptFile.exists()) {
        await scriptFile.delete();
      }
      await _writeJsonAtomically(statusFile, <String, Object?>{
        'status': 'error',
        'finishedAt': DateTime.now().toIso8601String(),
        'message': 'No se pudo iniciar el proceso de copia de seguridad.',
      });
      rethrow;
    }
  }

  Future<void> openBackupFolder() async {
    if (!isSupported) return;
    await destinationRoot.create(recursive: true);
    await Process.start(
      'explorer.exe',
      <String>[destinationRoot.path],
      mode: ProcessStartMode.detached,
    );
  }

  Future<FullBackupSummary?> _readManifest(Directory directory) async {
    final manifest = await _readJsonFile(File(
      '${directory.path}${Platform.pathSeparator}backup_manifest.json',
    ));
    if (manifest == null || manifest['format'] != 'todo-full-backup-v1') {
      return null;
    }
    final createdAt = DateTime.tryParse(manifest['createdAt'] as String? ?? '');
    if (createdAt == null) return null;
    return FullBackupSummary(
      createdAt: createdAt,
      directoryPath: directory.path,
      verifiedFiles: (manifest['verifiedFiles'] as num?)?.toInt() ?? 0,
      totalBytes: (manifest['totalBytes'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Map<String, dynamic>?> _readJsonFile(File file) async {
    if (!await file.exists()) return null;
    try {
      final source = (await file.readAsString()).replaceFirst('\ufeff', '');
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on Object {
      return null;
    }
  }

  Future<void> _writeJsonAtomically(
    File target,
    Map<String, Object?> value,
  ) async {
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(value),
      encoding: utf8,
      flush: true,
    );
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  Directory _defaultTodoDirectory() {
    final profile = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final documents = Directory('$profile${Platform.pathSeparator}Documents');
    return documents.existsSync()
        ? Directory('${documents.path}${Platform.pathSeparator}Todo')
        : Directory(profile);
  }

  Directory _defaultBackupDirectory() {
    final profile = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final documents = Directory('$profile${Platform.pathSeparator}Documents');
    final base = documents.existsSync() ? documents : Directory(profile);
    return Directory('${base.path}${Platform.pathSeparator}Todo Backups');
  }

  String _fileName(String path) =>
      path.split(Platform.pathSeparator).where((part) => part.isNotEmpty).last;
}
