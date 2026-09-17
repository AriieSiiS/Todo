import 'calendar_link.dart';
import 'enums.dart';
import 'json_helpers.dart';
import 'recurrence_rule.dart';
import 'reminder_rule.dart';

class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.categoryIds = const <String>[],
    this.projectIds = const <String>[],
    this.scheduledAt,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.active,
    this.recurrence = const RecurrenceRule(),
    this.subtaskIds = const <String>[],
    this.checklist = const <String>[],
    this.materials = const <String>[],
    this.origin = TaskOrigin.manual,
    this.manualOrder = 0,
    this.parentTaskId,
    this.collapsed = false,
    this.calendarLink,
    this.reminderRules = const <ReminderRule>[],
    this.completedAt,
    this.recurrenceCompletions = const <String, DateTime>{},
  });

  final String id;
  final String title;
  final String? description;
  final List<String> categoryIds;
  final List<String> projectIds;
  final DateTime? scheduledAt;
  final TaskPriority priority;
  final TaskStatus status;
  final RecurrenceRule recurrence;
  final List<String> subtaskIds;
  final List<String> checklist;
  final List<String> materials;
  final TaskOrigin origin;
  final double manualOrder;
  final String? parentTaskId;
  final bool collapsed;
  final CalendarLink? calendarLink;
  final List<ReminderRule> reminderRules;
  final DateTime? completedAt;
  final Map<String, DateTime> recurrenceCompletions;

  bool get isSubtask => parentTaskId != null;

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    bool clearDescription = false,
    List<String>? categoryIds,
    List<String>? projectIds,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    TaskPriority? priority,
    TaskStatus? status,
    RecurrenceRule? recurrence,
    List<String>? subtaskIds,
    List<String>? checklist,
    List<String>? materials,
    TaskOrigin? origin,
    double? manualOrder,
    String? parentTaskId,
    bool clearParentTaskId = false,
    bool? collapsed,
    CalendarLink? calendarLink,
    bool clearCalendarLink = false,
    List<ReminderRule>? reminderRules,
    bool clearReminderRules = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    Map<String, DateTime>? recurrenceCompletions,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: clearDescription ? null : description ?? this.description,
      categoryIds: categoryIds ?? this.categoryIds,
      projectIds: projectIds ?? this.projectIds,
      scheduledAt: clearScheduledAt ? null : scheduledAt ?? this.scheduledAt,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      recurrence: recurrence ?? this.recurrence,
      subtaskIds: subtaskIds ?? this.subtaskIds,
      checklist: checklist ?? this.checklist,
      materials: materials ?? this.materials,
      origin: origin ?? this.origin,
      manualOrder: manualOrder ?? this.manualOrder,
      parentTaskId:
          clearParentTaskId ? null : parentTaskId ?? this.parentTaskId,
      collapsed: collapsed ?? this.collapsed,
      calendarLink:
          clearCalendarLink ? null : calendarLink ?? this.calendarLink,
      reminderRules: clearReminderRules
          ? const <ReminderRule>[]
          : reminderRules ?? this.reminderRules,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      recurrenceCompletions:
          recurrenceCompletions ?? this.recurrenceCompletions,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'categoryIds': categoryIds,
      'projectIds': projectIds,
      'scheduledAt': scheduledAt?.toIso8601String(),
      'priority': priority.name,
      'status': status.name,
      'recurrence': recurrence.toJson(),
      'subtaskIds': subtaskIds,
      'checklist': checklist,
      'materials': materials,
      'origin': origin.name,
      'manualOrder': manualOrder,
      'parentTaskId': parentTaskId,
      'collapsed': collapsed,
      'calendarLink': calendarLink?.toJson(),
      'reminderRules': reminderRules.map((rule) => rule.toJson()).toList(),
      // Compatibilidad temporal con versiones que solo admiten un aviso.
      'reminderRule':
          reminderRules.isEmpty ? null : reminderRules.first.toJson(),
      'completedAt': completedAt?.toIso8601String(),
      'recurrenceCompletions': recurrenceCompletions.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
    };
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      categoryIds: stringList(json['categoryIds']),
      projectIds: stringList(json['projectIds']),
      scheduledAt: json['scheduledAt'] == null
          ? null
          : DateTime.tryParse(json['scheduledAt'] as String),
      priority: enumByName(TaskPriority.values, json['priority'] as String?,
          TaskPriority.medium),
      status: enumByName(
          TaskStatus.values, json['status'] as String?, TaskStatus.active),
      recurrence: RecurrenceRule.fromJson(
          (json['recurrence'] as Map<dynamic, dynamic>? ??
                  const <dynamic, dynamic>{})
              .cast<String, dynamic>()),
      subtaskIds: stringList(json['subtaskIds']),
      checklist: stringList(json['checklist']),
      materials: stringList(json['materials']),
      origin: enumByName(
          TaskOrigin.values, json['origin'] as String?, TaskOrigin.manual),
      manualOrder: (json['manualOrder'] as num?)?.toDouble() ?? 0,
      parentTaskId: json['parentTaskId'] as String?,
      collapsed: json['collapsed'] as bool? ?? false,
      calendarLink: json['calendarLink'] == null
          ? null
          : CalendarLink.fromJson(
              (json['calendarLink'] as Map<dynamic, dynamic>)
                  .cast<String, dynamic>()),
      reminderRules: _reminderRulesFromJson(json),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(json['completedAt'] as String),
      recurrenceCompletions:
          _recurrenceCompletionsFromJson(json['recurrenceCompletions']),
    );
  }
}

List<ReminderRule> _reminderRulesFromJson(Map<String, dynamic> json) {
  if (json.containsKey('reminderRules')) {
    final values = json['reminderRules'] as List<dynamic>? ?? const <dynamic>[];
    return values
        .whereType<Map<dynamic, dynamic>>()
        .map((value) => ReminderRule.fromJson(value.cast<String, dynamic>()))
        .where((rule) => rule.enabled)
        .toList();
  }
  final legacy = json['reminderRule'];
  if (legacy is! Map<dynamic, dynamic>) return const <ReminderRule>[];
  final rule = ReminderRule.fromJson(legacy.cast<String, dynamic>());
  return rule.enabled ? <ReminderRule>[rule] : const <ReminderRule>[];
}

Map<String, DateTime> _recurrenceCompletionsFromJson(Object? value) {
  final source =
      (value as Map<dynamic, dynamic>? ?? const <dynamic, dynamic>{});
  final result = <String, DateTime>{};
  for (final entry in source.entries) {
    final parsed = DateTime.tryParse(entry.value as String? ?? '');
    if (parsed != null) {
      result[entry.key as String] = parsed;
    }
  }
  return result;
}
