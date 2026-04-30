import 'enums.dart';
import 'json_helpers.dart';

class ReminderRule {
  const ReminderRule({
    this.triggerMode = ReminderTriggerMode.minutesBefore,
    this.minutesBefore = 30,
    this.firesAtDayStart = false,
    this.firesAtDayEnd = false,
    this.enabled = false,
  });

  final ReminderTriggerMode triggerMode;
  final int minutesBefore;
  final bool firesAtDayStart;
  final bool firesAtDayEnd;
  final bool enabled;

  ReminderRule copyWith({
    ReminderTriggerMode? triggerMode,
    int? minutesBefore,
    bool? firesAtDayStart,
    bool? firesAtDayEnd,
    bool? enabled,
  }) {
    return ReminderRule(
      triggerMode: triggerMode ?? this.triggerMode,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      firesAtDayStart: firesAtDayStart ?? this.firesAtDayStart,
      firesAtDayEnd: firesAtDayEnd ?? this.firesAtDayEnd,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'triggerMode': triggerMode.name,
      'minutesBefore': minutesBefore,
      'firesAtDayStart': firesAtDayStart,
      'firesAtDayEnd': firesAtDayEnd,
      'enabled': enabled,
    };
  }

  factory ReminderRule.fromJson(Map<String, dynamic> json) {
    return ReminderRule(
      triggerMode: enumByName(ReminderTriggerMode.values,
          json['triggerMode'] as String?, ReminderTriggerMode.minutesBefore),
      minutesBefore: (json['minutesBefore'] as num?)?.toInt() ?? 30,
      firesAtDayStart: json['firesAtDayStart'] as bool? ?? false,
      firesAtDayEnd: json['firesAtDayEnd'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? false,
    );
  }
}
