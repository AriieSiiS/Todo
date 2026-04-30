import 'enums.dart';
import 'json_helpers.dart';

class CalendarLink {
  const CalendarLink({
    required this.provider,
    required this.calendarId,
    required this.eventId,
    this.syncStatus = CalendarSyncStatus.idle,
    this.lastSyncedAt,
  });

  final CalendarProvider provider;
  final String calendarId;
  final String eventId;
  final CalendarSyncStatus syncStatus;
  final DateTime? lastSyncedAt;

  CalendarLink copyWith({
    CalendarProvider? provider,
    String? calendarId,
    String? eventId,
    CalendarSyncStatus? syncStatus,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
  }) {
    return CalendarLink(
      provider: provider ?? this.provider,
      calendarId: calendarId ?? this.calendarId,
      eventId: eventId ?? this.eventId,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt:
          clearLastSyncedAt ? null : lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'provider': provider.name,
      'calendarId': calendarId,
      'eventId': eventId,
      'syncStatus': syncStatus.name,
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    };
  }

  factory CalendarLink.fromJson(Map<String, dynamic> json) {
    return CalendarLink(
      provider: enumByName(CalendarProvider.values, json['provider'] as String?,
          CalendarProvider.google),
      calendarId: json['calendarId'] as String? ?? 'primary',
      eventId: json['eventId'] as String? ?? '',
      syncStatus: enumByName(CalendarSyncStatus.values,
          json['syncStatus'] as String?, CalendarSyncStatus.idle),
      lastSyncedAt: json['lastSyncedAt'] == null
          ? null
          : DateTime.tryParse(json['lastSyncedAt'] as String),
    );
  }
}
