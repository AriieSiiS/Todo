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
    this.reminderRule,
    this.completedAt,
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
  final ReminderRule? reminderRule;
  final DateTime? completedAt;

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
    ReminderRule? reminderRule,
    bool clearReminderRule = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
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
      reminderRule:
          clearReminderRule ? null : reminderRule ?? this.reminderRule,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
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
      'reminderRule': reminderRule?.toJson(),
      'completedAt': completedAt?.toIso8601String(),
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
      reminderRule: json['reminderRule'] == null
          ? null
          : ReminderRule.fromJson(
              (json['reminderRule'] as Map<dynamic, dynamic>)
                  .cast<String, dynamic>()),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(json['completedAt'] as String),
    );
  }
}
