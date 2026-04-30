import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:url_launcher/url_launcher.dart';

import '../domain/models.dart';
import 'calendar_service.dart';
import 'calendar_service_rest.dart';

class IoCalendarService implements CalendarService {
  final http.Client _httpClient = http.Client();
  late final CalendarRestClient _restClient = CalendarRestClient(_httpClient);

  oauth2.Client? _oauthClient;
  String? _email;
  String? _lastError;
  List<CalendarListItemModel> _calendars = const <CalendarListItemModel>[];

  static final Uri _authEndpoint =
      Uri.parse('https://accounts.google.com/o/oauth2/v2/auth');
  static final Uri _tokenEndpoint =
      Uri.parse('https://oauth2.googleapis.com/token');

  @override
  Future<bool> connect(CalendarIntegrationSettings settings) async {
    if (settings.desktopClientId.trim().isEmpty) {
      _lastError = 'Falta el Desktop Client ID de Google en Ajustes.';
      return false;
    }
    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final redirectUri =
          Uri.parse('http://127.0.0.1:${server.port}/oauth2callback');
      final grant = oauth2.AuthorizationCodeGrant(
        settings.desktopClientId,
        _authEndpoint,
        _tokenEndpoint,
        secret: settings.desktopClientSecret.isEmpty
            ? null
            : settings.desktopClientSecret,
      );
      final authorizationUrl = grant
          .getAuthorizationUrl(
        redirectUri,
        scopes: const <String>[
          'https://www.googleapis.com/auth/calendar',
          'openid',
          'email',
          'profile',
        ],
        state: 'todo-calendar',
      )
          .replace(queryParameters: <String, String>{
        ...grant
            .getAuthorizationUrl(
              redirectUri,
              scopes: const <String>[
                'https://www.googleapis.com/auth/calendar',
                'openid',
                'email',
                'profile',
              ],
              state: 'todo-calendar',
            )
            .queryParameters,
        'access_type': 'offline',
        'prompt': 'consent',
      });

      if (!await launchUrl(authorizationUrl,
          mode: LaunchMode.externalApplication)) {
        await server.close(force: true);
        _lastError = 'No se pudo abrir el navegador para autenticar Google.';
        return false;
      }

      final request = await server.first.timeout(const Duration(minutes: 4));
      final code = request.uri.queryParameters['code'];
      final error = request.uri.queryParameters['error'];
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '<html><body style="font-family:sans-serif;padding:24px;">'
        '<h2>Todo</h2><p>Puedes cerrar esta ventana y volver a la app.</p></body></html>',
      );
      await request.response.close();
      await server.close(force: true);

      if (error != null) {
        _lastError = error;
        return false;
      }
      if (code == null || code.isEmpty) {
        _lastError = 'Google no devolvio un codigo de autorizacion.';
        return false;
      }

      _oauthClient = await grant.handleAuthorizationCode(code);
      _email = await _restClient
          .fetchAccountEmail(_oauthClient!.credentials.accessToken);
      _calendars = await _restClient.listCalendars(
          accessToken: _oauthClient!.credentials.accessToken);
      _lastError = null;
      return true;
    } catch (error) {
      _lastError = error.toString();
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _oauthClient?.close();
    _oauthClient = null;
    _email = null;
    _calendars = const <CalendarListItemModel>[];
  }

  @override
  Future<String?> exportSession() async {
    final client = _oauthClient;
    final email = _email;
    if (client == null || email == null) {
      return null;
    }
    return jsonEncode(<String, dynamic>{
      'credentials': client.credentials.toJson(),
      'email': email,
      'calendars': _calendars
          .map((calendar) => <String, dynamic>{
                'id': calendar.id,
                'name': calendar.name,
                'primary': calendar.primary,
              })
          .toList(),
    });
  }

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
    final token = _oauthClient?.credentials.accessToken;
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
    final token = _oauthClient?.credentials.accessToken;
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
      final data = (jsonDecode(encodedSession) as Map<dynamic, dynamic>)
          .cast<String, dynamic>();
      final credentials =
          oauth2.Credentials.fromJson(data['credentials'] as String);
      _oauthClient = oauth2.Client(credentials, httpClient: _httpClient);
      _email = data['email'] as String?;
      final calendars =
          data['calendars'] as List<dynamic>? ?? const <dynamic>[];
      _calendars = calendars
          .map(
            (item) => CalendarListItemModel(
              id: ((item as Map<dynamic, dynamic>)['id'] as String?) ??
                  'primary',
              name: (item['name'] as String?) ?? 'Primary',
              primary: item['primary'] as bool? ?? false,
            ),
          )
          .toList();
    } catch (_) {}
  }

  @override
  Future<CalendarLink> upsertTaskEvent({
    required CalendarIntegrationSettings settings,
    required TaskModel task,
  }) async {
    final token = _oauthClient?.credentials.accessToken;
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

CalendarService createCalendarServicePlatform() => IoCalendarService();
