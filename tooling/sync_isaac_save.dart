import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/services/isaac_save_service.dart';
import 'package:todo/services/knowledge_service.dart';

void main() {
  test('sincroniza el guardado configurado con la guía local', () async {
    final knowledge = KnowledgeService();
    IsaacSaveSyncService? sync;
    try {
      await knowledge.initialize();
      final roots = knowledge.listPages().where(
            (page) =>
                page.parentId == null &&
                page.title.toLowerCase().contains('binding of isaac'),
          );
      if (roots.isEmpty) {
        throw StateError('No se encontró la ficha raíz de Isaac.');
      }
      final root = roots.first;
      final backup = await knowledge.createLocalBackup();
      sync = IsaacSaveSyncService(knowledge);
      await sync.start();

      final source = knowledge.importSource(root.id, 'isaac-save');
      if (source == null) {
        throw StateError('No se encontró un slot de Isaac configurado.');
      }
      if (source.lastError != null && source.lastError!.isNotEmpty) {
        throw StateError(source.lastError!);
      }
      final entries = knowledge.listProgress(root.id, source: 'isaac-save');
      int completed(String prefix) => entries
          .where((entry) => entry.key.startsWith(prefix) && entry.isCompleted)
          .length;

      stdout.writeln(
        const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
          'backup': backup.path,
          'slot': source.slot,
          'lastImportedAt': source.lastImportedAt?.toUtc().toIso8601String(),
          'derivedEntries': entries.length,
          'achievementsUnlocked': completed('isaac.achievement.'),
          'challengesCompleted': completed('isaac.challenge.'),
          'collectiblesCollected': completed('isaac.collectible.'),
          'completionMarks': completed('isaac.character.'),
        }),
      );
    } finally {
      await sync?.dispose();
      knowledge.dispose();
    }
  });
}
