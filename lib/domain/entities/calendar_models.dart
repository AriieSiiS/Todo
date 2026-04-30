class CalendarEventModel {
  const CalendarEventModel({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.startAt,
    required this.endAt,
    this.description,
    this.originTaskId,
  });

  final String id;
  final String calendarId;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final String? description;
  final String? originTaskId;

  CalendarEventModel copyWith({
    String? id,
    String? calendarId,
    String? title,
    DateTime? startAt,
    DateTime? endAt,
    String? description,
    bool clearDescription = false,
    String? originTaskId,
    bool clearOriginTaskId = false,
  }) {
    return CalendarEventModel(
      id: id ?? this.id,
      calendarId: calendarId ?? this.calendarId,
      title: title ?? this.title,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      description: clearDescription ? null : description ?? this.description,
      originTaskId:
          clearOriginTaskId ? null : originTaskId ?? this.originTaskId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'calendarId': calendarId,
      'title': title,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'description': description,
      'originTaskId': originTaskId,
    };
  }

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) {
    return CalendarEventModel(
      id: json['id'] as String? ?? '',
      calendarId: json['calendarId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      startAt: DateTime.tryParse(json['startAt'] as String? ?? '') ??
          DateTime.now(),
      endAt:
          DateTime.tryParse(json['endAt'] as String? ?? '') ?? DateTime.now(),
      description: json['description'] as String?,
      originTaskId: json['originTaskId'] as String?,
    );
  }
}

class CalendarAccount {
  const CalendarAccount({
    required this.email,
    required this.calendars,
  });

  final String email;
  final List<CalendarListItemModel> calendars;
}

class CalendarListItemModel {
  const CalendarListItemModel({
    required this.id,
    required this.name,
    this.primary = false,
  });

  final String id;
  final String name;
  final bool primary;
}
