import 'dart:convert';
import 'dart:io';

import 'package:todo_core/kindle_workspace.dart';
import 'package:todo_core/task_agenda.dart';
import 'package:todo_core/runtime_writer_lock.dart';
import 'package:todo_core/domain/enums.dart';
import 'package:todo_core/domain/library_item.dart';
import 'package:todo_core/domain/settings.dart';
import 'package:todo_core/domain/task.dart';

/// Transacciones breves del agente: nunca escribe mientras la app posee el estado.
class KindleBackgroundStore {
  KindleBackgroundStore(this.directory);
  final Directory directory;

  Future<Map<String, dynamic>> execute(
      String name, Map<String, dynamic> args) async {
    final lease =
        await RuntimeWriterLock.acquire(directory, timeout: Duration.zero);
    try {
      final file = File('${directory.path}/todo_state.json');
      await _recover(file);
      final state =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final rawTasks = (state['tasks'] as List? ?? []).cast<Map>();
      final rawBooks = (state['libraryItems'] as List? ?? []).cast<Map>();
      final tasks = rawTasks
          .map((value) => TaskModel.fromJson(Map<String, dynamic>.from(value)))
          .toList();
      final books = rawBooks
          .map(
              (value) => LibraryItem.fromJson(Map<String, dynamic>.from(value)))
          .toList();
      final originalTasks = List<TaskModel>.from(tasks);
      final originalBooks = List<LibraryItem>.from(books);
      final receipts = Map<String, dynamic>.from(
          state['agentOperationReceipts'] as Map? ?? {});
      Map<String, String> names(String key) => TaskAgenda.firstNames([
            for (final value in state[key] as List? ?? [])
              if (value is Map &&
                  value['id'] is String &&
                  value['name'] is String)
                (value['id'] as String, value['name'] as String),
          ]);
      final agenda = TaskAgenda(
        tasks: tasks,
        now: DateTime.now(),
        daySettings: DaySettings.fromJson(
            Map<String, dynamic>.from(state['daySettings'] as Map? ?? {})),
        manualDate:
            DateTime.tryParse(state['manualLogicalDate'] as String? ?? ''),
        manualStartedAt: DateTime.tryParse(
            state['manualLogicalDateStartedAt'] as String? ?? ''),
        sort: TodaySort.values.firstWhere(
            (value) => value.name == state['todaySort'],
            orElse: () => TodaySort.manual),
        categoryNames: names('categories'),
        projectNames: names('projects'),
      );
      final workspace = KindleWorkspace(
        tasks: tasks,
        books: books,
        receipts: receipts,
        agenda: agenda,
        source: 'background',
        save: () async {
          state['tasks'] = [
            for (var index = 0; index < tasks.length; index++)
              if (identical(tasks[index], originalTasks[index]))
                rawTasks.elementAt(index)
              else
                {...rawTasks.elementAt(index), ...tasks[index].toJson()},
          ];
          state['libraryItems'] = [
            for (var index = 0; index < books.length; index++)
              if (identical(books[index], originalBooks[index]))
                rawBooks.elementAt(index)
              else
                {
                  ...rawBooks.elementAt(index),
                  ...books[index].toJson(),
                  'reading': {
                    ...?rawBooks.elementAt(index)['reading'] as Map?,
                    ...?books[index].reading?.toJson()
                  }
                },
          ];
          state['agentOperationReceipts'] = receipts;
          state['updatedAt'] = DateTime.now().toIso8601String();
          final metadataFile = File('${directory.path}/sync_metadata.json');
          await _recover(metadataFile);
          final metadata = await metadataFile.exists()
              ? jsonDecode(await metadataFile.readAsString())
                  as Map<String, dynamic>
              : <String, dynamic>{};
          metadata['pendingLocalChanges'] = true;
          await _write(metadataFile, metadata);
          await _write(file, state);
        },
      );
      return await workspace.execute(name, args);
    } finally {
      await lease.release();
    }
  }

  Future<void> _write(File file, Map<String, dynamic> state) async {
    final temporary = File('${file.path}.tmp');
    final previous = File('${file.path}.previous');
    await temporary.writeAsString(
        const JsonEncoder.withIndent('  ').convert(state),
        flush: true);
    if (await file.exists()) await file.copy(previous.path);
    try {
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
      if (await previous.exists()) await previous.delete();
    } catch (_) {
      if (!await file.exists() && await previous.exists()) {
        await previous.copy(file.path);
      }
      rethrow;
    }
  }

  Future<void> _recover(File file) async {
    if (await file.exists()) return;
    for (final suffix in ['.tmp', '.previous']) {
      final candidate = File('${file.path}$suffix');
      try {
        if (jsonDecode(await candidate.readAsString()) is! Map) continue;
      } on FileSystemException {
        continue;
      } on FormatException {
        continue;
      }
      await candidate.copy(file.path);
      return;
    }
  }
}
