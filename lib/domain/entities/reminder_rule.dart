import 'enums.dart';
import 'json_helpers.dart';

class ReminderRule {
  const ReminderRule({
    this.triggerMode = ReminderTriggerMode.minutesBefore,
    this.minutesBefore = 30,
    this.firesAtDayStart = false,
    this.firesAtDayEnd = false,
    this.deliveryMode = ReminderDeliveryMode.normal,
    this.enabled = false,
  });

  final ReminderTriggerMode triggerMode;
  final int minutesBefore;
  final bool firesAtDayStart;
  final bool firesAtDayEnd;
  final ReminderDeliveryMode deliveryMode;
  final bool enabled;

  bool get isImportant => deliveryMode == ReminderDeliveryMode.important;

  ReminderRule copyWith({
    ReminderTriggerMode? triggerMode,
    int? minutesBefore,
    bool? firesAtDayStart,
    bool? firesAtDayEnd,
    ReminderDeliveryMode? deliveryMode,
    bool? enabled,
  }) {
    return ReminderRule(
      triggerMode: triggerMode ?? this.triggerMode,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      firesAtDayStart: firesAtDayStart ?? this.firesAtDayStart,
      firesAtDayEnd: firesAtDayEnd ?? this.firesAtDayEnd,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'triggerMode': triggerMode.name,
      'minutesBefore': minutesBefore,
      'firesAtDayStart': firesAtDayStart,
      'firesAtDayEnd': firesAtDayEnd,
      'deliveryMode': deliveryMode.name,
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
      deliveryMode: enumByName(
        ReminderDeliveryMode.values,
        json['deliveryMode'] as String?,
        ReminderDeliveryMode.normal,
      ),
      enabled: json['enabled'] as bool? ?? false,
    );
  }
}
