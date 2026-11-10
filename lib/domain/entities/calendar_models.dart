class CalendarEventModel {
  const CalendarEventModel({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.startAt,
    required this.endAt,
    this.description,
    this.originTaskId,
    this.googleEventId,
    this.googleUpdatedAt,
    this.localUpdatedAt,
  });

  final String id;
  final String calendarId;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final String? description;
  final String? originTaskId;

  /// Identificador del evento en Google Calendar; es nulo si aún no se ha enviado.
  final String? googleEventId;

  /// Fecha de última modificación que Google indicó en la última sincronización.
  final DateTime? googleUpdatedAt;

  /// Momento del último cambio hecho en Todo que Google todavía no conoce.
  final DateTime? localUpdatedAt;

  /// Un evento de día completo empieza y acaba a medianoche y dura al menos un día.
  bool get isAllDay =>
      startAt.hour == 0 &&
      startAt.minute == 0 &&
      endAt.hour == 0 &&
      endAt.minute == 0 &&
      endAt.difference(startAt).inHours >= 23;

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
    String? googleEventId,
    bool clearGoogleEventId = false,
    DateTime? googleUpdatedAt,
    DateTime? localUpdatedAt,
    bool clearLocalUpdatedAt = false,
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
      googleEventId:
          clearGoogleEventId ? null : googleEventId ?? this.googleEventId,
      googleUpdatedAt: googleUpdatedAt ?? this.googleUpdatedAt,
      localUpdatedAt:
          clearLocalUpdatedAt ? null : localUpdatedAt ?? this.localUpdatedAt,
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
      'googleEventId': googleEventId,
      'googleUpdatedAt': googleUpdatedAt?.toUtc().toIso8601String(),
      'localUpdatedAt': localUpdatedAt?.toUtc().toIso8601String(),
    };
  }

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) {
    return CalendarEventModel(
      id: json['id'] as String? ?? '',
      calendarId: json['calendarId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      startAt:
          DateTime.tryParse(json['startAt'] as String? ?? '') ?? DateTime.now(),
      endAt:
          DateTime.tryParse(json['endAt'] as String? ?? '') ?? DateTime.now(),
      description: json['description'] as String?,
      originTaskId: json['originTaskId'] as String?,
      googleEventId: json['googleEventId'] as String?,
      googleUpdatedAt:
          DateTime.tryParse(json['googleUpdatedAt'] as String? ?? '')
              ?.toLocal(),
      localUpdatedAt:
          DateTime.tryParse(json['localUpdatedAt'] as String? ?? '')?.toLocal(),
    );
  }
}

/// Cambio recibido de Google: un evento nuevo o modificado, o un borrado.
class CalendarRemoteChange {
  const CalendarRemoteChange({
    required this.googleEventId,
    this.event,
    this.updatedAt,
  });

  final String googleEventId;

  /// Momento en que Google registró el cambio (también en los borrados).
  final DateTime? updatedAt;

  /// Es nulo cuando Google ha borrado el evento.
  final CalendarEventModel? event;
}

class CalendarRemoteDelta {
  const CalendarRemoteDelta({
    required this.changes,
    required this.syncToken,
    required this.full,
  });

  final List<CalendarRemoteChange> changes;
  final String syncToken;

  /// Verdadero si se ha leído la ventana completa en lugar de solo los cambios.
  final bool full;
}

/// Google ya no acepta el token de sincronización: hay que leer todo de nuevo.
class CalendarSyncTokenExpired implements Exception {
  const CalendarSyncTokenExpired();
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
