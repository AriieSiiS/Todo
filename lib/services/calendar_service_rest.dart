import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

class CalendarRestClient {
  CalendarRestClient(this._client);

  final http.Client _client;

  Future<String> fetchAccountEmail(String accessToken) async {
    final response = await _client.get(
      Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo leer el perfil de Google.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['email'] as String? ?? '';
  }

  Future<List<CalendarListItemModel>> listCalendars({
    required String accessToken,
  }) async {
    final response = await _client.get(
      Uri.parse('https://www.googleapis.com/calendar/v3/users/me/calendarList'),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudieron leer los calendarios.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? const <dynamic>[];
    return items.map((item) {
      final map = (item as Map<dynamic, dynamic>).cast<String, dynamic>();
      return CalendarListItemModel(
        id: map['id'] as String? ?? 'primary',
        name: map['summary'] as String? ?? 'Principal',
        primary: map['primary'] as bool? ?? false,
      );
    }).toList();
  }

  static const String _eventsUrl =
      'https://www.googleapis.com/calendar/v3/calendars/primary/events';

  /// Lee del calendario principal los cambios desde [syncToken]. Sin token lee
  /// la ventana completa entre [from] y [to] y devuelve un token nuevo.
  Future<CalendarRemoteDelta> pullChanges({
    required String syncToken,
    required DateTime from,
    required DateTime to,
  }) async {
    final changes = <CalendarRemoteChange>[];
    final full = syncToken.isEmpty;
    String? pageToken;
    String nextSyncToken = '';
    do {
      final query = <String, String>{
        'singleEvents': 'true',
        'maxResults': '250',
        if (full) 'timeMin': from.toUtc().toIso8601String(),
        if (full) 'timeMax': to.toUtc().toIso8601String(),
        if (!full) 'syncToken': syncToken,
        if (pageToken != null) 'pageToken': pageToken,
      };
      final response = await _client
          .get(Uri.parse(_eventsUrl).replace(queryParameters: query));
      if (response.statusCode == 410) {
        throw const CalendarSyncTokenExpired();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('No se pudieron leer los eventos de Google Calendar.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      for (final item in data['items'] as List<dynamic>? ?? const <dynamic>[]) {
        final change = _parseChange((item as Map).cast<String, dynamic>());
        if (change != null) changes.add(change);
      }
      pageToken = data['nextPageToken'] as String?;
      nextSyncToken = data['nextSyncToken'] as String? ?? nextSyncToken;
    } while (pageToken != null);
    return CalendarRemoteDelta(
      changes: changes,
      syncToken: nextSyncToken,
      full: full,
    );
  }

  CalendarRemoteChange? _parseChange(Map<String, dynamic> map) {
    final id = map['id'] as String? ?? '';
    if (id.isEmpty || map['eventType'] == 'workingLocation') return null;
    final updatedAt =
        DateTime.tryParse(map['updated'] as String? ?? '')?.toLocal();
    if (map['status'] == 'cancelled') {
      return CalendarRemoteChange(googleEventId: id, updatedAt: updatedAt);
    }
    final start = (map['start'] as Map?)?.cast<String, dynamic>() ?? const {};
    final end = (map['end'] as Map?)?.cast<String, dynamic>() ?? const {};
    final startRaw = start['dateTime'] as String? ?? start['date'] as String?;
    if (startRaw == null) return null;
    final endRaw = end['dateTime'] as String? ?? end['date'] as String?;
    final startAt = DateTime.tryParse(startRaw)?.toLocal();
    if (startAt == null) return null;
    final endAt = DateTime.tryParse(endRaw ?? '')?.toLocal() ??
        startAt.add(const Duration(hours: 1));
    final privateProperties =
        ((map['extendedProperties'] as Map?)?['private'] as Map?)
            ?.cast<String, dynamic>();
    return CalendarRemoteChange(
      googleEventId: id,
      updatedAt: updatedAt,
      event: CalendarEventModel(
        id: id,
        calendarId: 'primary',
        title: (map['summary'] as String?)?.trim().isNotEmpty == true
            ? map['summary'] as String
            : 'Evento sin título',
        startAt: startAt,
        endAt: endAt,
        description: map['description'] as String?,
        originTaskId: privateProperties?['todoTaskId'] as String?,
        googleEventId: id,
        googleUpdatedAt: updatedAt,
      ),
    );
  }

  Map<String, dynamic> _eventBody(CalendarEventModel event) {
    String day(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    Map<String, dynamic> moment(DateTime value) => event.isAllDay
        ? <String, dynamic>{'date': day(value), 'dateTime': null}
        : <String, dynamic>{
            'dateTime': value.toUtc().toIso8601String(),
            'date': null,
          };
    return <String, dynamic>{
      'summary': event.title,
      'description': event.description ?? '',
      'start': moment(event.startAt),
      'end': moment(event.endAt),
    };
  }

  /// Crea el evento en Google o, si ya existe allí, lo actualiza. Devuelve el
  /// evento enlazado con su id de Google y su fecha de modificación.
  Future<CalendarEventModel> pushEvent(CalendarEventModel event) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final body = jsonEncode(_eventBody(event));
    final googleId = event.googleEventId;
    http.Response? response;
    if (googleId != null) {
      response = await _client.patch(
        Uri.parse('$_eventsUrl/${Uri.encodeComponent(googleId)}'),
        headers: headers,
        body: body,
      );
      // Si Google ya no tiene el evento se vuelve a crear.
      if (response.statusCode == 404 || response.statusCode == 410) {
        response = null;
      }
    }
    response ??=
        await _client.post(Uri.parse(_eventsUrl), headers: headers, body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Google Calendar rechazó el evento «${event.title}» (${response.statusCode}).');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return event.copyWith(
      googleEventId: data['id'] as String? ?? googleId,
      googleUpdatedAt:
          DateTime.tryParse(data['updated'] as String? ?? '')?.toLocal(),
      clearLocalUpdatedAt: true,
    );
  }

  Future<void> deleteEvent(String googleEventId) async {
    final response = await _client
        .delete(Uri.parse('$_eventsUrl/${Uri.encodeComponent(googleEventId)}'));
    final gone = response.statusCode == 404 || response.statusCode == 410;
    if (!gone && (response.statusCode < 200 || response.statusCode >= 300)) {
      throw Exception('No se pudo borrar el evento en Google Calendar.');
    }
  }

  Future<CalendarLink> upsertTaskEvent({
    required String accessToken,
    required String calendarId,
    required TaskModel task,
  }) async {
    final uri = task.calendarLink == null
        ? Uri.parse(
            'https://www.googleapis.com/calendar/v3/calendars/${Uri.encodeComponent(calendarId)}/events')
        : Uri.parse(
            'https://www.googleapis.com/calendar/v3/calendars/${Uri.encodeComponent(calendarId)}/events/${task.calendarLink!.eventId}',
          );
    final body = jsonEncode(<String, dynamic>{
      'summary': task.title,
      'description': task.description ?? '',
      'start': <String, dynamic>{
        'dateTime':
            (task.scheduledAt ?? DateTime.now()).toUtc().toIso8601String(),
      },
      'end': <String, dynamic>{
        'dateTime': (task.scheduledAt ?? DateTime.now())
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
      },
      'extendedProperties': <String, dynamic>{
        'private': <String, dynamic>{'todoTaskId': task.id},
      },
    });
    final response = task.calendarLink == null
        ? await _client.post(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: body,
          )
        : await _client.patch(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: body,
          );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo sincronizar la tarea con Google Calendar.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return CalendarLink(
      provider: CalendarProvider.google,
      calendarId: calendarId,
      eventId: data['id'] as String? ?? '',
      syncStatus: CalendarSyncStatus.synced,
      lastSyncedAt: DateTime.now(),
    );
  }
}
