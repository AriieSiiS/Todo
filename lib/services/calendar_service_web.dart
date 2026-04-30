import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:http/http.dart' as http;

import '../domain/models.dart';
import 'calendar_service.dart';
import 'calendar_service_rest.dart';

@JS('todoGoogleBridge')
external _TodoGoogleBridge? get _todoGoogleBridge;

extension type _TodoGoogleBridge(JSObject _) implements JSObject {
  external JSPromise<JSObject> requestAccessToken(
      JSString clientId, JSString scope);
  external JSPromise<JSAny?> revoke(JSString token);
}

class WebCalendarService implements CalendarService {
  final CalendarRestClient _restClient = CalendarRestClient(http.Client());

  String? _accessToken;
  String? _email;
  String? _lastError;
  List<CalendarListItemModel> _calendars = const <CalendarListItemModel>[];

  @override
  Future<bool> connect(CalendarIntegrationSettings settings) async {
    if (settings.webClientId.trim().isEmpty) {
      _lastError = 'Falta el Web Client ID de Google en Ajustes.';
      return false;
    }
    final bridge = _todoGoogleBridge;
    if (bridge == null) {
      _lastError = 'El puente web de Google no esta cargado.';
      return false;
    }
    try {
      final tokenResponse = await bridge
          .requestAccessToken(
            settings.webClientId.toJS,
            'https://www.googleapis.com/auth/calendar openid email profile'
                .toJS,
          )
          .toDart;
      final accessToken =
          tokenResponse.getProperty('access_token'.toJS)?.dartify() as String?;
      if (accessToken == null || accessToken.isEmpty) {
        _lastError = 'Google no devolvio un access token.';
        return false;
      }
      _accessToken = accessToken;
      _email = await _restClient.fetchAccountEmail(accessToken);
      _calendars = await _restClient.listCalendars(accessToken: accessToken);
      _lastError = null;
      return true;
    } catch (error) {
      _lastError = error.toString();
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    final token = _accessToken;
    final bridge = _todoGoogleBridge;
    if (token != null && bridge != null) {
      try {
        await bridge.revoke(token.toJS).toDart;
      } catch (_) {}
    }
    _accessToken = null;
    _email = null;
    _calendars = const <CalendarListItemModel>[];
  }

  @override
  Future<String?> exportSession() async => null;

  @override
  Future<CalendarAccount?> getAccount() async {
    final email = _email;
    if (email == null || email.isEmpty) {
      return null;
    }
    return CalendarAccount(email: email, calendars: _calendars);
  }

  @override
  Future<String?> getLastError() async => _lastError;

  @override
  Future<TaskModel> importEventAsTask(
      {required CalendarEventModel event}) async {
    return TaskModel(
      id: 'calendar-${event.id}',
      title: event.title,
      description: event.description,
      scheduledAt: event.startAt,
      origin: TaskOrigin.calendar,
      calendarLink: CalendarLink(
        provider: CalendarProvider.google,
        calendarId: event.calendarId,
        eventId: event.id,
        syncStatus: CalendarSyncStatus.synced,
        lastSyncedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<CalendarListItemModel>> listCalendars(
      CalendarIntegrationSettings settings) async {
    final token = _accessToken;
    if (token == null) {
      return const <CalendarListItemModel>[];
    }
    _calendars = await _restClient.listCalendars(accessToken: token);
    return _calendars;
  }

  @override
  Future<List<CalendarEventModel>> listEvents({
    required CalendarIntegrationSettings settings,
    required DateTime from,
    required DateTime to,
  }) async {
    final token = _accessToken;
    if (token == null) {
      return const <CalendarEventModel>[];
    }
    return _restClient.listEvents(
      accessToken: token,
      calendarId: settings.selectedCalendarId,
      from: from,
      to: to,
    );
  }

  @override
  Future<void> restoreSession(String? encodedSession) async {
    if (encodedSession == null || encodedSession.isEmpty) {
      return;
    }
    try {
      final data = jsonDecode(encodedSession) as Map<String, dynamic>;
      _email = data['email'] as String?;
    } catch (_) {}
  }

  @override
  Future<CalendarLink> upsertTaskEvent({
    required CalendarIntegrationSettings settings,
    required TaskModel task,
  }) async {
    final token = _accessToken;
    if (token == null) {
      throw Exception('Conecta Google Calendar antes de sincronizar.');
    }
    return _restClient.upsertTaskEvent(
      accessToken: token,
      calendarId: task.calendarLink?.calendarId ?? settings.selectedCalendarId,
      task: task,
    );
  }
}

CalendarService createCalendarServicePlatform() => WebCalendarService();
