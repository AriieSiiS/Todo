import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/services/full_backup_service.dart';

void main() {
  late Directory temporaryRoot;
  late Directory source;
  late Directory backups;

  setUp(() async {
    temporaryRoot = await Directory.systemTemp.createTemp('todo_backup_test_');
    source = Directory(
      '${temporaryRoot.path}${Platform.pathSeparator}Todo',
    );
    backups = Directory(
      '${temporaryRoot.path}${Platform.pathSeparator}Todo Backups',
    );
    await source.create();
    await backups.create();
  });

  tearDown(() async {
    if (await temporaryRoot.exists()) {
      await temporaryRoot.delete(recursive: true);
    }
  });

  test('indica que todavía no existe una copia completa', () async {
    final service = FullBackupService(
      sourceDirectory: source,
      destinationRoot: backups,
    );

    final overview = await service.loadOverview();

    expect(overview.latest, isNull);
    expect(overview.errorMessage, isNull);
    expect(overview.inProgress, isFalse);
  });

  test('elige la copia verificada más reciente', () async {
    await _writeManifest(
      backups,
      'Todo-completo-20260901-100000',
      DateTime(2026, 9),
      verifiedFiles: 12,
      totalBytes: 2048,
    );
    final expected = await _writeManifest(
      backups,
      'Todo-completo-20260907-120000',
      DateTime(2026, 9, 7, 12),
      verifiedFiles: 28,
      totalBytes: 4096,
    );
    final service = FullBackupService(
      sourceDirectory: source,
      destinationRoot: backups,
    );

    final overview = await service.loadOverview();

    expect(overview.latest?.directoryPath, expected.path);
    expect(overview.latest?.verifiedFiles, 28);
    expect(overview.latest?.totalBytes, 4096);
  });

  test('conserva la última copia y avisa si el intento nuevo falló', () async {
    await _writeManifest(
      backups,
      'Todo-completo-20260907-120000',
      DateTime(2026, 9, 7, 12),
      verifiedFiles: 28,
      totalBytes: 4096,
    );
    await File(
      '${backups.path}${Platform.pathSeparator}last_backup_status.json',
    ).writeAsString(jsonEncode(<String, Object?>{
      'status': 'error',
      'message': 'La verificación falló para recipes\\imagen.png',
    }));
    final service = FullBackupService(
      sourceDirectory: source,
      destinationRoot: backups,
    );

    final overview = await service.loadOverview();

    expect(overview.latest, isNotNull);
    expect(overview.errorMessage, contains('La verificación falló'));
  });
}

Future<Directory> _writeManifest(
  Directory root,
  String name,
  DateTime createdAt, {
  required int verifiedFiles,
  required int totalBytes,
}) async {
  final directory = Directory(
    '${root.path}${Platform.pathSeparator}$name',
  );
  await directory.create();
  await File(
    '${directory.path}${Platform.pathSeparator}backup_manifest.json',
  ).writeAsString(jsonEncode(<String, Object?>{
    'format': 'todo-full-backup-v1',
    'createdAt': createdAt.toIso8601String(),
    'verifiedFiles': verifiedFiles,
    'totalBytes': totalBytes,
  }));
  return directory;
}
