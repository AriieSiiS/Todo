import 'enums.dart';

/// Una sesión de un club de lectura: qué libro se comenta, en qué club y qué
/// día. Los libros del club van aparte de Biblioteca: su ficha se guarda en
/// [book] y solo entra en Biblioteca si se añade a mano.
class ReadingClubMeeting {
  const ReadingClubMeeting({
    required this.id,
    required this.bookId,
    required this.club,
    required this.date,
    this.pendingConfirmation = false,
    this.note,
    this.book,
  });

  final String id;

  /// Identificador del libro en `libraryItems` cuando ya está en Biblioteca;
  /// si no, el de la ficha guardada en [book].
  final String bookId;

  /// Ficha del libro en el formato de `LibraryItem`, sin estado de lectura.
  final Map<String, dynamic>? book;

  /// Nombre del club o de su categoría, como «Novela negra».
  final String club;

  /// Día de la sesión, sin hora.
  final DateTime date;

  /// El club aún no ha confirmado este libro.
  final bool pendingConfirmation;
  final String? note;

  ReadingClubMeeting copyWith({
    String? bookId,
    String? club,
    DateTime? date,
    bool? pendingConfirmation,
    String? note,
    bool clearNote = false,
    Map<String, dynamic>? book,
  }) =>
      ReadingClubMeeting(
        id: id,
        bookId: bookId ?? this.bookId,
        club: club ?? this.club,
        date: date ?? this.date,
        pendingConfirmation: pendingConfirmation ?? this.pendingConfirmation,
        note: clearNote ? null : note ?? this.note,
        book: book ?? this.book,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'club': club,
        'date': _fechaSinHora(date),
        if (pendingConfirmation) 'pendingConfirmation': true,
        if (note != null && note!.trim().isNotEmpty) 'note': note,
        if (book != null) 'book': book,
      };

  static ReadingClubMeeting? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final bookId = json['bookId'];
    final club = json['club'];
    final date = DateTime.tryParse('${json['date'] ?? ''}');
    if (id is! String || bookId is! String || club is! String || date == null) {
      return null;
    }
    return ReadingClubMeeting(
      id: id,
      bookId: bookId,
      club: club,
      date: DateTime(date.year, date.month, date.day),
      pendingConfirmation: json['pendingConfirmation'] == true,
      note: json['note'] is String ? json['note'] as String : null,
      book: json['book'] is Map
          ? Map<String, dynamic>.from(json['book'] as Map)
          : null,
    );
  }

  static String _fechaSinHora(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}

class AppVisibilitySettings {
  const AppVisibilitySettings({
    this.hiddenSections = const [],
    this.hiddenTabs = const {},
    this.hiddenCollectionWorks = const [],
    this.collectionWorkEdits = const {},
    this.readingClubVisible = true,
    this.readingClubByDate = false,
    this.readingClubMeetings = const [],
  });

  /// Muestra el acceso «Club de lectura» en la vista de libros.
  final bool readingClubVisible;

  /// Muestra el club ordenado por fecha en vez de agrupado por clubs.
  final bool readingClubByDate;

  /// Sesiones de los clubs de lectura, de cualquier club y fecha.
  final List<ReadingClubMeeting> readingClubMeetings;

  AppVisibilitySettings copyWith({
    List<String>? hiddenSections,
    Map<String, List<String>>? hiddenTabs,
    List<String>? hiddenCollectionWorks,
    Map<String, Map<String, dynamic>>? collectionWorkEdits,
    bool? readingClubVisible,
    bool? readingClubByDate,
    List<ReadingClubMeeting>? readingClubMeetings,
  }) =>
      AppVisibilitySettings(
        hiddenSections: hiddenSections ?? this.hiddenSections,
        hiddenTabs: hiddenTabs ?? this.hiddenTabs,
        hiddenCollectionWorks:
            hiddenCollectionWorks ?? this.hiddenCollectionWorks,
        collectionWorkEdits: collectionWorkEdits ?? this.collectionWorkEdits,
        readingClubVisible: readingClubVisible ?? this.readingClubVisible,
        readingClubByDate: readingClubByDate ?? this.readingClubByDate,
        readingClubMeetings: readingClubMeetings ?? this.readingClubMeetings,
      );

  final List<String> hiddenSections;
  final Map<String, List<String>> hiddenTabs;

  /// Obras quitadas de una colección, como `coleccion/obra`.
  final List<String> hiddenCollectionWorks;

  /// Cambios propios en obras del catálogo de Colecciones, por
  /// `coleccion/obra`, con los campos de `LibraryItem` que se sustituyen.
  final Map<String, Map<String, dynamic>> collectionWorkEdits;

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
    AppSection.library: {
      'library': 'Biblioteca',
      'goals': 'Propósitos',
      'collections': 'Colecciones',
    },
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
        'hiddenCollectionWorks': hiddenCollectionWorks,
        if (collectionWorkEdits.isNotEmpty)
          'collectionWorkEdits': collectionWorkEdits,
        if (!readingClubVisible) 'readingClubVisible': false,
        if (readingClubByDate) 'readingClubByDate': true,
        if (readingClubMeetings.isNotEmpty)
          'readingClubMeetings':
              readingClubMeetings.map((meeting) => meeting.toJson()).toList(),
      };

  factory AppVisibilitySettings.fromJson(Map<String, dynamic> json) =>
      AppVisibilitySettings(
        hiddenSections: (json['hiddenSections'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(),
        hiddenTabs: (json['hiddenTabs'] as Map<String, dynamic>? ?? const {})
            .map((section, value) => MapEntry(section,
                (value as List<dynamic>).whereType<String>().toList())),
        hiddenCollectionWorks:
            (json['hiddenCollectionWorks'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .toList(),
        collectionWorkEdits: {
          for (final entrada
              in (json['collectionWorkEdits'] as Map? ?? const {}).entries)
            if (entrada.key is String && entrada.value is Map)
              entrada.key as String:
                  Map<String, dynamic>.from(entrada.value as Map),
        },
        readingClubVisible: json['readingClubVisible'] != false,
        readingClubByDate: json['readingClubByDate'] == true,
        readingClubMeetings:
            (json['readingClubMeetings'] as List<dynamic>? ?? const [])
                .map(ReadingClubMeeting.fromJson)
                .whereType<ReadingClubMeeting>()
                .toList(),
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
    this.syncToken = '',
    this.lastSyncAt,
    this.lastFullSyncAt,
    this.pendingDeletions = const <String, DateTime>{},
  });

  final String desktopClientId;
  final String desktopClientSecret;
  final String selectedCalendarId;
  final String selectedCalendarName;
  final String connectedEmail;
  final bool connected;
  final String lastError;

  /// Token de Google para pedir solo los cambios desde la última sincronización.
  final String syncToken;
  final DateTime? lastSyncAt;
  final DateTime? lastFullSyncAt;

  /// Eventos borrados en Todo que Google aún no sabe: id de Google y momento del borrado.
  final Map<String, DateTime> pendingDeletions;

  CalendarIntegrationSettings copyWith({
    String? desktopClientId,
    String? desktopClientSecret,
    String? selectedCalendarId,
    String? selectedCalendarName,
    String? connectedEmail,
    bool? connected,
    String? lastError,
    String? syncToken,
    DateTime? lastSyncAt,
    DateTime? lastFullSyncAt,
    Map<String, DateTime>? pendingDeletions,
  }) {
    return CalendarIntegrationSettings(
      desktopClientId: desktopClientId ?? this.desktopClientId,
      desktopClientSecret: desktopClientSecret ?? this.desktopClientSecret,
      selectedCalendarId: selectedCalendarId ?? this.selectedCalendarId,
      selectedCalendarName: selectedCalendarName ?? this.selectedCalendarName,
      connectedEmail: connectedEmail ?? this.connectedEmail,
      connected: connected ?? this.connected,
      lastError: lastError ?? this.lastError,
      syncToken: syncToken ?? this.syncToken,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastFullSyncAt: lastFullSyncAt ?? this.lastFullSyncAt,
      pendingDeletions: pendingDeletions ?? this.pendingDeletions,
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
      'syncToken': syncToken,
      'lastSyncAt': lastSyncAt?.toUtc().toIso8601String(),
      'lastFullSyncAt': lastFullSyncAt?.toUtc().toIso8601String(),
      'pendingDeletions': pendingDeletions
          .map((id, moment) => MapEntry(id, moment.toUtc().toIso8601String())),
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
      syncToken: json['syncToken'] as String? ?? '',
      lastSyncAt:
          DateTime.tryParse(json['lastSyncAt'] as String? ?? '')?.toLocal(),
      lastFullSyncAt:
          DateTime.tryParse(json['lastFullSyncAt'] as String? ?? '')?.toLocal(),
      pendingDeletions: {
        for (final entry
            in ((json['pendingDeletions'] as Map?) ?? const <String, dynamic>{})
                .entries)
          if (DateTime.tryParse('${entry.value}') != null)
            '${entry.key}': DateTime.parse('${entry.value}').toLocal(),
      },
    );
  }
}
