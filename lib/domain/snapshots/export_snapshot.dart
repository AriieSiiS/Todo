import 'dart:convert';

import '../entities/category.dart';
import '../entities/calendar_models.dart';
import '../entities/enums.dart';
import '../entities/project.dart';
import '../entities/quick_note.dart';
import '../entities/settings.dart';
import '../entities/task.dart';

class ExportSnapshot {
  const ExportSnapshot({
    required this.tasks,
    required this.categories,
    required this.projects,
    required this.notes,
    required this.calendarEvents,
    required this.daySettings,
    required this.notificationSettings,
    required this.calendarSettings,
    this.visualMode = AppVisualMode.classic,
  });

  final List<TaskModel> tasks;
  final List<CategoryModel> categories;
  final List<ProjectModel> projects;
  final List<QuickNote> notes;
  final List<CalendarEventModel> calendarEvents;
  final DaySettings daySettings;
  final DeviceNotificationSettings notificationSettings;
  final CalendarIntegrationSettings calendarSettings;
  final AppVisualMode visualMode;

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'tasks': tasks.map((task) => task.toJson()).toList(),
      'categories': categories.map((category) => category.toJson()).toList(),
      'projects': projects.map((project) => project.toJson()).toList(),
      'notes': notes.map((note) => note.toJson()).toList(),
      'calendarEvents':
          calendarEvents.map((event) => event.toJson()).toList(),
      'daySettings': daySettings.toJson(),
      'notificationSettings': notificationSettings.toJson(),
      'calendarSettings': calendarSettings.toJson(),
      'visualMode': visualMode.name,
    });
  }
}
