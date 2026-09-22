import 'dart:math' show min;

import '../domain/models.dart';

class MobileTaskSnapshot {
  const MobileTaskSnapshot({
    required this.serverId,
    required this.revision,
    required this.generatedAt,
    required this.tasks,
    required this.categories,
    required this.projects,
    required this.daySettings,
  });

  final String serverId;
  final String revision;
  final DateTime generatedAt;
  final List<TaskModel> tasks;
  final List<CategoryModel> categories;
  final List<ProjectModel> projects;
  final DaySettings daySettings;

  factory MobileTaskSnapshot.fromJson(Map<String, dynamic> json) {
    if ((json['protocolVersion'] as num?)?.toInt() != 1) {
      throw const FormatException(
          'La versión de sincronización no es compatible.');
    }
    return MobileTaskSnapshot(
      serverId: json['serverId'] as String? ?? '',
      revision: json['revision'] as String? ?? '',
      generatedAt:
          DateTime.tryParse(json['generatedAt'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      tasks: (json['tasks'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => TaskModel.fromJson(value.cast<String, dynamic>()))
          .toList(),
      categories: (json['categories'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => CategoryModel.fromJson(value.cast<String, dynamic>()))
          .toList(),
      projects: (json['projects'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => ProjectModel.fromJson(value.cast<String, dynamic>()))
          .toList(),
      daySettings: DaySettings.fromJson(
        (json['daySettings'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
    );
  }

  DateTime logicalDate([DateTime? instant]) {
    final value = instant ?? DateTime.now();
    if (value.hour < daySettings.dayEndsAtHour) {
      final previous = value.subtract(const Duration(days: 1));
      return DateTime(previous.year, previous.month, previous.day);
    }
    return DateTime(value.year, value.month, value.day);
  }

  List<TaskModel> tasksForToday([DateTime? now]) {
    final day = logicalDate(now);
    final values = tasks
        .where((task) => task.status == TaskStatus.active)
        .where((task) => !task.isSubtask)
        .where((task) => occursOnDay(task, day, today: day))
        .toList();
    values.sort(_compareTasks);
    return values;
  }

  List<TaskModel> upcomingTasks([DateTime? now]) {
    final today = logicalDate(now);
    final result = <TaskModel>[];
    for (final task in tasks.where(
      (value) => value.status == TaskStatus.active && !value.isSubtask,
    )) {
      if (!task.recurrence.isRecurring) {
        if (task.scheduledAt != null &&
            _date(task.scheduledAt!).isAfter(today)) {
          result.add(task);
        }
        continue;
      }
      for (var offset = 1; offset <= 366; offset++) {
        final candidate = today.add(Duration(days: offset));
        if (occursOnDay(task, candidate, today: today)) {
          final original = task.scheduledAt;
          result.add(
            task.copyWith(
              scheduledAt: DateTime(
                candidate.year,
                candidate.month,
                candidate.day,
                original?.hour ?? 0,
                original?.minute ?? 0,
              ),
            ),
          );
          break;
        }
      }
    }
    result.sort(_compareTasks);
    return result;
  }

  List<TaskModel> allActiveTasks() {
    final values = tasks
        .where((task) => task.status == TaskStatus.active && !task.isSubtask)
        .toList();
    values.sort(_compareTasks);
    return values;
  }

  List<TaskModel> subtasksOf(TaskModel task) =>
      task.subtaskIds.map(taskById).whereType<TaskModel>().toList();

  TaskModel? taskById(String id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  CategoryModel? categoryById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  ProjectModel? projectById(String id) {
    for (final project in projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  bool occursOnDay(
    TaskModel task,
    DateTime day, {
    required DateTime today,
  }) {
    final occurrenceKey = _occurrenceKey(day);
    final isToday = _sameDay(day, today);
    if (task.recurrence.isRecurring &&
        task.recurrenceCompletions.containsKey(occurrenceKey)) {
      return false;
    }
    if (task.recurrence.isRecurring) {
      if (!isToday && task.recurrence.type == RecurrenceType.daily) {
        return false;
      }
      return _recursOnDay(task, day);
    }
    final scheduled = task.scheduledAt;
    if (scheduled == null) return isToday;
    if (isToday && _date(scheduled).isBefore(today)) return true;
    return _sameDay(scheduled, day);
  }

  bool _recursOnDay(TaskModel task, DateTime day) {
    final start = task.scheduledAt == null ? day : _date(task.scheduledAt!);
    final target = _date(day);
    if (target.isBefore(start)) return false;
    if (task.recurrence.activeMonths.isNotEmpty &&
        !task.recurrence.activeMonths.contains(target.month)) {
      return false;
    }
    final interval =
        task.recurrence.interval < 1 ? 1 : task.recurrence.interval;
    final days = target.difference(start).inDays;
    switch (task.recurrence.type) {
      case RecurrenceType.none:
        return false;
      case RecurrenceType.daily:
      case RecurrenceType.everyXDays:
        return days % interval == 0;
      case RecurrenceType.weekly:
        return days % (7 * interval) == 0;
      case RecurrenceType.monthly:
        final months =
            (target.year - start.year) * 12 + target.month - start.month;
        if (months % interval != 0) return false;
        final lastDay = DateTime(target.year, target.month + 1, 0).day;
        return target.day == min(start.day, lastDay);
      case RecurrenceType.yearly:
        return target.month == start.month &&
            target.day == start.day &&
            (target.year - start.year) % interval == 0;
    }
  }

  int _compareTasks(TaskModel left, TaskModel right) {
    final leftDate = left.scheduledAt;
    final rightDate = right.scheduledAt;
    if (leftDate == null && rightDate != null) return 1;
    if (leftDate != null && rightDate == null) return -1;
    final dateComparison = leftDate?.compareTo(rightDate!) ?? 0;
    if (dateComparison != 0) return dateComparison;
    final order = left.manualOrder.compareTo(right.manualOrder);
    return order != 0 ? order : left.title.compareTo(right.title);
  }
}

DateTime _date(DateTime value) => DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _occurrenceKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
