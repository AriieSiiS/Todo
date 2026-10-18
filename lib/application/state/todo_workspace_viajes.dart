part of 'todo_workspace.dart';

extension TodoWorkspaceViajes on TodoWorkspace {
  Trip? tripById(String id) {
    for (final trip in _trips) {
      if (trip.id == id) return trip;
    }
    return null;
  }

  /// Viajes que se solapan con el día indicado y no están archivados.
  List<Trip> tripsOnDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _trips
        .where((trip) =>
            !trip.archived &&
            !trip.startDate.isAfter(date) &&
            !trip.endDate.isBefore(date))
        .toList();
  }

  Trip createTrip({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    String destination = '',
    String notes = '',
    bool createPackingList = false,
  }) {
    final now = DateTime.now();
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    var end = DateTime(endDate.year, endDate.month, endDate.day);
    if (end.isBefore(start)) end = start;
    String? packingListId;
    if (createPackingList) {
      packingListId = createWardrobePackingList(
        name: name.trim().isEmpty ? destination : name,
        startDate: start,
        endDate: end,
      ).id;
    }
    final trip = Trip(
      id: _id('trip'),
      name: name.trim().isEmpty ? 'Viaje sin nombre' : name.trim(),
      destination: destination.trim(),
      startDate: start,
      endDate: end,
      notes: notes.trim(),
      packingListId: packingListId,
      createdAt: now,
      updatedAt: now,
    );
    _trips.add(trip);
    _commit();
    return trip;
  }

  void updateTrip(
    String id, {
    String? name,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    String? packingListId,
    bool clearPackingListId = false,
    bool? archived,
  }) {
    final index = _trips.indexWhere((trip) => trip.id == id);
    if (index == -1) return;
    final current = _trips[index];
    var start = startDate == null
        ? current.startDate
        : DateTime(startDate.year, startDate.month, startDate.day);
    var end = endDate == null
        ? current.endDate
        : DateTime(endDate.year, endDate.month, endDate.day);
    if (end.isBefore(start)) end = start;
    _trips[index] = current.copyWith(
      name: name?.trim(),
      destination: destination?.trim(),
      startDate: start,
      endDate: end,
      notes: notes?.trim(),
      packingListId: packingListId,
      clearPackingListId: clearPackingListId,
      archived: archived,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  /// Guarda una reserva nueva o sustituye la que tenga el mismo identificador.
  TripReservation saveTripReservation(
    String tripId, {
    String? reservationId,
    required String title,
    TripReservationKind kind = TripReservationKind.activity,
    DateTime? date,
    String confirmation = '',
    String note = '',
  }) {
    final index = _trips.indexWhere((trip) => trip.id == tripId);
    if (index == -1) throw StateError('No se encuentra el viaje.');
    final trip = _trips[index];
    final reservation = TripReservation(
      id: reservationId ?? _id('trip-reservation'),
      title: title.trim().isEmpty ? kind.label : title.trim(),
      kind: kind,
      date: date,
      confirmation: confirmation.trim(),
      note: note.trim(),
    );
    final reservations = List<TripReservation>.of(trip.reservations);
    final existing = reservations.indexWhere((item) => item.id == reservation.id);
    if (existing == -1) {
      reservations.add(reservation);
    } else {
      reservations[existing] = reservation;
    }
    _trips[index] =
        trip.copyWith(reservations: reservations, updatedAt: DateTime.now());
    _commit();
    return reservation;
  }

  void deleteTripReservation(String tripId, String reservationId) {
    final index = _trips.indexWhere((trip) => trip.id == tripId);
    if (index == -1) return;
    final trip = _trips[index];
    _trips[index] = trip.copyWith(
      reservations: trip.reservations
          .where((item) => item.id != reservationId)
          .toList(),
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  Future<TripDocument> addTripPdf(
    String tripId,
    String sourcePath, {
    String title = '',
  }) async {
    final index = _trips.indexWhere((trip) => trip.id == tripId);
    if (index == -1) throw StateError('No se encuentra el viaje.');
    final relative =
        await _tripAssets.importPdf(tripId, sourcePath, kind: 'documents');
    final name = sourcePath.split(RegExp(r'[\\/]')).last;
    final document = TripDocument(
      id: _id('trip-document'),
      title: title.trim().isEmpty ? name : title.trim(),
      filePath: relative,
    );
    final latest = _trips.indexWhere((trip) => trip.id == tripId);
    if (latest == -1) return document;
    _trips[latest] = _trips[latest].copyWith(
      documents: [..._trips[latest].documents, document],
      updatedAt: DateTime.now(),
    );
    _commit();
    return document;
  }

  TripDocument addTripLink(String tripId, String title, String url) {
    final index = _trips.indexWhere((trip) => trip.id == tripId);
    if (index == -1) throw StateError('No se encuentra el viaje.');
    final document = TripDocument(
      id: _id('trip-document'),
      title: title.trim().isEmpty ? url.trim() : title.trim(),
      url: url.trim(),
    );
    _trips[index] = _trips[index].copyWith(
      documents: [..._trips[index].documents, document],
      updatedAt: DateTime.now(),
    );
    _commit();
    return document;
  }

  Future<String> tripDocumentAbsolutePath(TripDocument document) =>
      _tripAssets.absolutePath(document.filePath);

  Future<void> deleteTripDocument(String tripId, String documentId) async {
    final index = _trips.indexWhere((trip) => trip.id == tripId);
    if (index == -1) return;
    final trip = _trips[index];
    final removed = trip.documents.where((item) => item.id == documentId);
    _trips[index] = trip.copyWith(
      documents:
          trip.documents.where((item) => item.id != documentId).toList(),
      updatedAt: DateTime.now(),
    );
    _commit();
    for (final document in removed) {
      if (document.filePath.isNotEmpty) {
        await _tripAssets.deleteAsset(document.filePath);
      }
    }
  }

  Future<void> deleteTrip(String id) async {
    final trip = tripById(id);
    if (trip == null) return;
    _trips.removeWhere((item) => item.id == id);
    _commit();
    for (final document in trip.documents) {
      if (document.filePath.isNotEmpty) {
        await _tripAssets.deleteAsset(document.filePath);
      }
    }
  }
}
