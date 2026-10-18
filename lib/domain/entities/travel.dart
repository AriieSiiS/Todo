enum TripReservationKind { flight, lodging, transport, activity, other }

extension TripReservationKindLabel on TripReservationKind {
  String get label => switch (this) {
        TripReservationKind.flight => 'Vuelo',
        TripReservationKind.lodging => 'Alojamiento',
        TripReservationKind.transport => 'Transporte',
        TripReservationKind.activity => 'Actividad',
        TripReservationKind.other => 'Otro',
      };
}

/// Reserva o parada del itinerario de un viaje.
class TripReservation {
  const TripReservation({
    required this.id,
    required this.title,
    this.kind = TripReservationKind.activity,
    this.date,
    this.confirmation = '',
    this.note = '',
  });

  final String id;
  final String title;
  final TripReservationKind kind;
  final DateTime? date;
  final String confirmation;
  final String note;

  TripReservation copyWith({
    String? title,
    TripReservationKind? kind,
    DateTime? date,
    bool clearDate = false,
    String? confirmation,
    String? note,
  }) =>
      TripReservation(
        id: id,
        title: title ?? this.title,
        kind: kind ?? this.kind,
        date: clearDate ? null : date ?? this.date,
        confirmation: confirmation ?? this.confirmation,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'kind': kind.name,
        'date': date?.toIso8601String(),
        'confirmation': confirmation,
        'note': note,
      };

  factory TripReservation.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String?;
    return TripReservation(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      kind: TripReservationKind.values.firstWhere(
        (value) => value.name == kindName,
        orElse: () => TripReservationKind.other,
      ),
      date: DateTime.tryParse(json['date'] as String? ?? ''),
      confirmation: json['confirmation'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }
}

/// Documento del viaje: un PDF copiado a la carpeta de Todo o un enlace.
class TripDocument {
  const TripDocument({
    required this.id,
    required this.title,
    this.filePath = '',
    this.url = '',
  });

  final String id;
  final String title;

  /// Ruta relativa del PDF dentro de la carpeta de viajes.
  final String filePath;
  final String url;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'filePath': filePath,
        'url': url,
      };

  factory TripDocument.fromJson(Map<String, dynamic> json) => TripDocument(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        filePath: json['filePath'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );
}

class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
    this.destination = '',
    this.notes = '',
    this.packingListId,
    this.reservations = const <TripReservation>[],
    this.documents = const <TripDocument>[],
    this.archived = false,
  });

  final String id;
  final String name;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final String notes;

  /// Maleta de Ropa asociada, si existe.
  final String? packingListId;

  final List<TripReservation> reservations;
  final List<TripDocument> documents;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get durationDays => endDate.difference(startDate).inDays + 1;

  Trip copyWith({
    String? name,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    String? packingListId,
    bool clearPackingListId = false,
    List<TripReservation>? reservations,
    List<TripDocument>? documents,
    bool? archived,
    DateTime? updatedAt,
  }) =>
      Trip(
        id: id,
        name: name ?? this.name,
        destination: destination ?? this.destination,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        notes: notes ?? this.notes,
        packingListId:
            clearPackingListId ? null : packingListId ?? this.packingListId,
        reservations: reservations ?? this.reservations,
        documents: documents ?? this.documents,
        archived: archived ?? this.archived,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'destination': destination,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'notes': notes,
        'packingListId': packingListId,
        'reservations': reservations.map((item) => item.toJson()).toList(),
        'documents': documents.map((item) => item.toJson()).toList(),
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Trip.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now();
    final start =
        DateTime.tryParse(json['startDate'] as String? ?? '') ?? created;
    final end = DateTime.tryParse(json['endDate'] as String? ?? '') ?? start;
    return Trip(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      startDate: DateTime(start.year, start.month, start.day),
      endDate: DateTime(end.year, end.month, end.day),
      notes: json['notes'] as String? ?? '',
      packingListId: json['packingListId'] as String?,
      reservations:
          (json['reservations'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<dynamic, dynamic>>()
              .map((item) =>
                  TripReservation.fromJson(item.cast<String, dynamic>()))
              .toList(),
      documents: (json['documents'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => TripDocument.fromJson(item.cast<String, dynamic>()))
          .toList(),
      archived: json['archived'] as bool? ?? false,
      createdAt: created,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? created,
    );
  }
}
