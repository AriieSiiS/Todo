class DaySettings {
  const DaySettings({
    this.dayEndsAtHour = 5,
    this.nextDayVisibleAtHour = 10,
  });

  final int dayEndsAtHour;
  final int nextDayVisibleAtHour;

  DaySettings copyWith({
    int? dayEndsAtHour,
    int? nextDayVisibleAtHour,
  }) {
    return DaySettings(
      dayEndsAtHour: dayEndsAtHour ?? this.dayEndsAtHour,
      nextDayVisibleAtHour: nextDayVisibleAtHour ?? this.nextDayVisibleAtHour,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'dayEndsAtHour': dayEndsAtHour,
      'nextDayVisibleAtHour': nextDayVisibleAtHour,
    };
  }

  factory DaySettings.fromJson(Map<String, dynamic> json) {
    return DaySettings(
      dayEndsAtHour: (json['dayEndsAtHour'] as num?)?.toInt() ?? 5,
      nextDayVisibleAtHour:
          (json['nextDayVisibleAtHour'] as num?)?.toInt() ?? 10,
    );
  }
}

class DeviceNotificationSettings {
  const DeviceNotificationSettings({
    this.notificationsEnabled = true,
    this.webPermissionGranted = false,
    this.windowsPermissionGranted = true,
    this.dayStartReminderEnabled = true,
    this.dayEndReminderEnabled = true,
    this.defaultMinutesBeforeTask = 30,
  });

  final bool notificationsEnabled;
  final bool webPermissionGranted;
  final bool windowsPermissionGranted;
  final bool dayStartReminderEnabled;
  final bool dayEndReminderEnabled;
  final int defaultMinutesBeforeTask;

  DeviceNotificationSettings copyWith({
    bool? notificationsEnabled,
    bool? webPermissionGranted,
    bool? windowsPermissionGranted,
    bool? dayStartReminderEnabled,
    bool? dayEndReminderEnabled,
    int? defaultMinutesBeforeTask,
  }) {
    return DeviceNotificationSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      webPermissionGranted: webPermissionGranted ?? this.webPermissionGranted,
      windowsPermissionGranted:
          windowsPermissionGranted ?? this.windowsPermissionGranted,
      dayStartReminderEnabled:
          dayStartReminderEnabled ?? this.dayStartReminderEnabled,
      dayEndReminderEnabled:
          dayEndReminderEnabled ?? this.dayEndReminderEnabled,
      defaultMinutesBeforeTask:
          defaultMinutesBeforeTask ?? this.defaultMinutesBeforeTask,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'notificationsEnabled': notificationsEnabled,
      'webPermissionGranted': webPermissionGranted,
      'windowsPermissionGranted': windowsPermissionGranted,
      'dayStartReminderEnabled': dayStartReminderEnabled,
      'dayEndReminderEnabled': dayEndReminderEnabled,
      'defaultMinutesBeforeTask': defaultMinutesBeforeTask,
    };
  }

  factory DeviceNotificationSettings.fromJson(Map<String, dynamic> json) {
    return DeviceNotificationSettings(
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      webPermissionGranted: json['webPermissionGranted'] as bool? ?? false,
      windowsPermissionGranted:
          json['windowsPermissionGranted'] as bool? ?? true,
      dayStartReminderEnabled: json['dayStartReminderEnabled'] as bool? ?? true,
      dayEndReminderEnabled: json['dayEndReminderEnabled'] as bool? ?? true,
      defaultMinutesBeforeTask:
          (json['defaultMinutesBeforeTask'] as num?)?.toInt() ?? 30,
    );
  }
}

class CalendarIntegrationSettings {
  const CalendarIntegrationSettings({
    this.webClientId = '',
    this.desktopClientId = '',
    this.desktopClientSecret = '',
    this.selectedCalendarId = 'primary',
    this.selectedCalendarName = 'Primary',
    this.connectedEmail = '',
    this.connected = false,
    this.lastError = '',
  });

  final String webClientId;
  final String desktopClientId;
  final String desktopClientSecret;
  final String selectedCalendarId;
  final String selectedCalendarName;
  final String connectedEmail;
  final bool connected;
  final String lastError;

  CalendarIntegrationSettings copyWith({
    String? webClientId,
    String? desktopClientId,
    String? desktopClientSecret,
    String? selectedCalendarId,
    String? selectedCalendarName,
    String? connectedEmail,
    bool? connected,
    String? lastError,
  }) {
    return CalendarIntegrationSettings(
      webClientId: webClientId ?? this.webClientId,
      desktopClientId: desktopClientId ?? this.desktopClientId,
      desktopClientSecret: desktopClientSecret ?? this.desktopClientSecret,
      selectedCalendarId: selectedCalendarId ?? this.selectedCalendarId,
      selectedCalendarName: selectedCalendarName ?? this.selectedCalendarName,
      connectedEmail: connectedEmail ?? this.connectedEmail,
      connected: connected ?? this.connected,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'webClientId': webClientId,
      'desktopClientId': desktopClientId,
      'desktopClientSecret': desktopClientSecret,
      'selectedCalendarId': selectedCalendarId,
      'selectedCalendarName': selectedCalendarName,
      'connectedEmail': connectedEmail,
      'connected': connected,
      'lastError': lastError,
    };
  }

  factory CalendarIntegrationSettings.fromJson(Map<String, dynamic> json) {
    return CalendarIntegrationSettings(
      webClientId: json['webClientId'] as String? ?? '',
      desktopClientId: json['desktopClientId'] as String? ?? '',
      desktopClientSecret: json['desktopClientSecret'] as String? ?? '',
      selectedCalendarId: json['selectedCalendarId'] as String? ?? 'primary',
      selectedCalendarName:
          json['selectedCalendarName'] as String? ?? 'Primary',
      connectedEmail: json['connectedEmail'] as String? ?? '',
      connected: json['connected'] as bool? ?? false,
      lastError: json['lastError'] as String? ?? '',
    );
  }
}
