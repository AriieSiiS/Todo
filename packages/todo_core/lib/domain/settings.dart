import 'enums.dart';

class AppVisibilitySettings {
  const AppVisibilitySettings({
    this.hiddenSections = const [],
    this.hiddenTabs = const {},
  });

  final List<String> hiddenSections;
  final Map<String, List<String>> hiddenTabs;

  static const tabs = <AppSection, Map<String, String>>{
    AppSection.wardrobe: {
      'wardrobe': 'Armario',
      'outfits': 'Conjuntos',
      'planner': 'Planificador',
      'laundry': 'Lavandería',
      'packing': 'Maletas',
      'stats': 'Estadísticas',
    },
    AppSection.household: {
      'inventory': 'Inventario',
      'shopping': 'Compras',
      'twin': 'Gemelo 3D',
      'qr': 'Códigos QR',
    },
    AppSection.library: {'library': 'Biblioteca', 'goals': 'Propósitos'},
    AppSection.recipes: {'recipes': 'Recetas', 'menus': 'Menús semanales'},
    AppSection.expenses: {
      'monthly': 'Vista mensual',
      'annual': 'Resumen anual',
      'fixed': 'Suscripciones',
      'categories': 'Categorías',
      'methods': 'Métodos de pago',
    },
    AppSection.calendar: {'month': 'Mes', 'week': 'Semana', 'agenda': 'Agenda'},
  };

  bool sectionVisible(AppSection section) =>
      section == AppSection.settings || !hiddenSections.contains(section.name);

  List<String> visibleTabs(AppSection section) {
    final available = tabs[section]?.keys.toList() ?? <String>[];
    final visible = available
        .where((id) => !(hiddenTabs[section.name] ?? const []).contains(id))
        .toList();
    return visible.isEmpty && available.isNotEmpty
        ? [available.first]
        : visible;
  }

  Map<String, dynamic> toJson() => {
        'hiddenSections': hiddenSections,
        'hiddenTabs': hiddenTabs,
      };

  factory AppVisibilitySettings.fromJson(Map<String, dynamic> json) =>
      AppVisibilitySettings(
        hiddenSections: (json['hiddenSections'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
        hiddenTabs: (json['hiddenTabs'] as Map<String, dynamic>? ?? const {})
            .map((section, value) => MapEntry(section,
                (value as List<dynamic>).whereType<String>().toList())),
      );
}

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

class WardrobeDisplaySettings {
  const WardrobeDisplaySettings({
    this.showUsageCount = false,
  });

  final bool showUsageCount;

  WardrobeDisplaySettings copyWith({
    bool? showUsageCount,
  }) {
    return WardrobeDisplaySettings(
      showUsageCount: showUsageCount ?? this.showUsageCount,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'showUsageCount': showUsageCount,
    };
  }

  factory WardrobeDisplaySettings.fromJson(Map<String, dynamic> json) {
    return WardrobeDisplaySettings(
      showUsageCount: json['showUsageCount'] as bool? ?? false,
    );
  }
}

class DeviceNotificationSettings {
  const DeviceNotificationSettings({
    this.notificationsEnabled = false,
    this.permissionGranted = false,
    this.dayStartReminderEnabled = false,
    this.dayEndReminderEnabled = false,
    this.defaultMinutesBeforeTask = 30,
  });

  final bool notificationsEnabled;
  final bool permissionGranted;
  final bool dayStartReminderEnabled;
  final bool dayEndReminderEnabled;
  final int defaultMinutesBeforeTask;

  DeviceNotificationSettings copyWith({
    bool? notificationsEnabled,
    bool? permissionGranted,
    bool? dayStartReminderEnabled,
    bool? dayEndReminderEnabled,
    int? defaultMinutesBeforeTask,
  }) {
    return DeviceNotificationSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      permissionGranted: permissionGranted ?? this.permissionGranted,
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
      'notificationPermissionGranted': permissionGranted,
      'dayStartReminderEnabled': dayStartReminderEnabled,
      'dayEndReminderEnabled': dayEndReminderEnabled,
      'defaultMinutesBeforeTask': defaultMinutesBeforeTask,
    };
  }

  factory DeviceNotificationSettings.fromJson(Map<String, dynamic> json) {
    return DeviceNotificationSettings(
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      permissionGranted: json['notificationPermissionGranted'] as bool? ??
          json['windowsPermissionGranted'] as bool? ??
          false,
      dayStartReminderEnabled:
          json['dayStartReminderEnabled'] as bool? ?? false,
      dayEndReminderEnabled: json['dayEndReminderEnabled'] as bool? ?? false,
      defaultMinutesBeforeTask:
          (json['defaultMinutesBeforeTask'] as num?)?.toInt() ?? 30,
    );
  }
}

class CalendarIntegrationSettings {
  const CalendarIntegrationSettings({
    this.desktopClientId = '',
    this.desktopClientSecret = '',
    this.selectedCalendarId = 'primary',
    this.selectedCalendarName = 'Principal',
    this.connectedEmail = '',
    this.connected = false,
    this.lastError = '',
  });

  final String desktopClientId;
  final String desktopClientSecret;
  final String selectedCalendarId;
  final String selectedCalendarName;
  final String connectedEmail;
  final bool connected;
  final String lastError;

  CalendarIntegrationSettings copyWith({
    String? desktopClientId,
    String? desktopClientSecret,
    String? selectedCalendarId,
    String? selectedCalendarName,
    String? connectedEmail,
    bool? connected,
    String? lastError,
  }) {
    return CalendarIntegrationSettings(
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
      desktopClientId: json['desktopClientId'] as String? ?? '',
      desktopClientSecret: json['desktopClientSecret'] as String? ?? '',
      selectedCalendarId: json['selectedCalendarId'] as String? ?? 'primary',
      selectedCalendarName:
          json['selectedCalendarName'] as String? ?? 'Principal',
      connectedEmail: json['connectedEmail'] as String? ?? '',
      connected: json['connected'] as bool? ?? false,
      lastError: json['lastError'] as String? ?? '',
    );
  }
}
