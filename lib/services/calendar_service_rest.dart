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

  Future<List<CalendarEventModel>> listEvents({
    required String accessToken,
    required String calendarId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.get(
      Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/${Uri.encodeComponent(calendarId)}/events'
        '?singleEvents=true&orderBy=startTime&timeMin=${Uri.encodeQueryComponent(from.toUtc().toIso8601String())}'
        '&timeMax=${Uri.encodeQueryComponent(to.toUtc().toIso8601String())}',
      ),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudieron leer los eventos.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? const <dynamic>[];
    return items.map((item) {
      final map = (item as Map<dynamic, dynamic>).cast<String, dynamic>();
      final start = ((map['start'] as Map<dynamic, dynamic>? ??
              const <dynamic, dynamic>{})
          .cast<String, dynamic>());
      final end =
          ((map['end'] as Map<dynamic, dynamic>? ?? const <dynamic, dynamic>{})
              .cast<String, dynamic>());
      final startRaw =
          start['dateTime'] as String? ?? start['date'] as String? ?? '';
      final endRaw =
          end['dateTime'] as String? ?? end['date'] as String? ?? startRaw;
      return CalendarEventModel(
        id: map['id'] as String? ?? '',
        calendarId: calendarId,
        title: map['summary'] as String? ?? 'Evento sin titulo',
        startAt: DateTime.tryParse(startRaw)?.toLocal() ?? from,
        endAt: DateTime.tryParse(endRaw)?.toLocal() ?? to,
        description: map['description'] as String?,
        originTaskId: ((map['extendedProperties'] as Map<dynamic, dynamic>? ??
                const <dynamic, dynamic>{})['private']
            as Map<dynamic, dynamic>?)?['todoTaskId'] as String?,
      );
    }).toList();
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
