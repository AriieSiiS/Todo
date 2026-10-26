import 'enums.dart';
import 'json_helpers.dart';

class RecurrenceRule {
  const RecurrenceRule({
    this.type = RecurrenceType.none,
    this.interval = 1,
    this.weekdays = const <int>[],
    this.activeMonths = const <int>[],
  });

  final RecurrenceType type;
  final int interval;
  final List<int> weekdays;
  final List<int> activeMonths;

  bool get isRecurring => type != RecurrenceType.none;

  RecurrenceRule copyWith({
    RecurrenceType? type,
    int? interval,
    List<int>? weekdays,
    List<int>? activeMonths,
  }) {
    return RecurrenceRule(
      type: type ?? this.type,
      interval: interval ?? this.interval,
      weekdays: weekdays ?? this.weekdays,
      activeMonths: activeMonths ?? this.activeMonths,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.name,
      'interval': interval,
      'weekdays': weekdays,
      'activeMonths': activeMonths,
    };
  }

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    return RecurrenceRule(
      type: enumByName(
          RecurrenceType.values, json['type'] as String?, RecurrenceType.none),
      interval: (json['interval'] as num?)?.toInt() ?? 1,
      weekdays: (json['weekdays'] as List<dynamic>? ?? const <dynamic>[])
          .map((value) => (value as num).toInt())
          .toList(),
      activeMonths:
          (json['activeMonths'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => (value as num).toInt())
              .where((value) => value >= 1 && value <= 12)
              .toList(),
    );
  }
}
