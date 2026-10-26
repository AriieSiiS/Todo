import 'dart:math';

import 'domain/enums.dart';
import 'domain/settings.dart';
import 'domain/task.dart';

/// Reglas de agenda compartidas por Windows y el agente sin interfaz.
class TaskAgenda {
  TaskAgenda({
    required this.tasks,
    required this.daySettings,
    required this.now,
    this.manualDate,
    this.manualStartedAt,
    this.sort = TodaySort.manual,
    this.categoryNames = const {},
    this.projectNames = const {},
  });

  final List<TaskModel> tasks;
  final DaySettings daySettings;
  final DateTime now;
  final DateTime? manualDate;
  final DateTime? manualStartedAt;
  final TodaySort sort;
  final Map<String, String> categoryNames;
  final Map<String, String> projectNames;

  static Map<String, String> firstNames(Iterable<(String, String)> values) {
    final names = <String, String>{};
    for (final (id, name) in values) {
      names.putIfAbsent(id, () => name);
    }
    return names;
  }

  static String occurrenceKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime ruleBasedLogicalDate(DateTime value) {
    final day = value.hour < daySettings.dayEndsAtHour
        ? value.subtract(const Duration(days: 1))
        : value;
    return DateTime(day.year, day.month, day.day);
  }

  DateTime? activeManualDate(DateTime value) {
    if (manualDate == null ||
        manualStartedAt == null ||
        value.isBefore(manualStartedAt!)) {
      return null;
    }
    return sameDay(ruleBasedLogicalDate(value), manualDate!)
        ? null
        : manualDate;
  }

  DateTime logicalDate([DateTime? instant]) {
    final value = instant ?? now;
    return activeManualDate(value) ?? ruleBasedLogicalDate(value);
  }

  static bool recursOnDay(TaskModel task, DateTime day) {
    final start = task.scheduledAt == null
        ? day
        : DateTime(task.scheduledAt!.year, task.scheduledAt!.month,
            task.scheduledAt!.day);
    final target = DateTime(day.year, day.month, day.day);
    if (target.isBefore(start)) return false;
    if (task.recurrence.activeMonths.isNotEmpty &&
        !task.recurrence.activeMonths.contains(target.month)) {
      return false;
    }
    final days = target.difference(start).inDays;
    switch (task.recurrence.type) {
      case RecurrenceType.none:
        return false;
      case RecurrenceType.daily:
      case RecurrenceType.everyXDays:
        return days % task.recurrence.interval == 0;
      case RecurrenceType.weekly:
        return days % (7 * task.recurrence.interval) == 0;
      case RecurrenceType.monthly:
        final months =
            (target.year - start.year) * 12 + target.month - start.month;
        return months % task.recurrence.interval == 0 &&
            target.day ==
                min(start.day, DateTime(target.year, target.month + 1, 0).day);
      case RecurrenceType.yearly:
        return target.month == start.month &&
            target.day == start.day &&
            (target.year - start.year) % task.recurrence.interval == 0;
    }
  }

  List<TaskModel> tasksForDay(DateTime day) {
    final today = logicalDate();
    final key = occurrenceKey(day);
    final isToday = sameDay(day, today);
    return tasks.where((task) {
      if (task.status != TaskStatus.active || task.isSubtask) return false;
      if (task.recurrence.isRecurring) {
        if (task.recurrenceCompletions.containsKey(key) ||
            task.skippedRecurrenceOccurrences.contains(key)) {
          return false;
        }
        if (!isToday && task.recurrence.type == RecurrenceType.daily) {
          return false;
        }
        return recursOnDay(task, day);
      }
      final scheduled = task.scheduledAt;
      return scheduled == null ||
          (isToday && scheduled.isBefore(today)) ||
          sameDay(scheduled, day);
    }).toList();
  }

  List<TaskModel> sortTasks(List<TaskModel> list) {
    final sorted = List<TaskModel>.from(list);
    String label(TaskModel task, Map<String, String> names, List<String> ids) =>
        ids.isEmpty ? 'zzz' : names[ids.first] ?? 'zzz';
    switch (sort) {
      case TodaySort.manual:
        sorted.sort((a, b) => a.manualOrder.compareTo(b.manualOrder));
      case TodaySort.category:
        sorted.sort((a, b) => label(a, categoryNames, a.categoryIds)
            .compareTo(label(b, categoryNames, b.categoryIds)));
      case TodaySort.time:
        sorted.sort((a, b) => (a.scheduledAt ?? logicalDate())
            .compareTo(b.scheduledAt ?? logicalDate()));
      case TodaySort.project:
        sorted.sort((a, b) => label(a, projectNames, a.projectIds)
            .compareTo(label(b, projectNames, b.projectIds)));
      case TodaySort.priority:
        sorted.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    }
    return sorted;
  }
}
