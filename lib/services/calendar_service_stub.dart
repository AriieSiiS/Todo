import '../domain/models.dart';
import 'calendar_service.dart';

class UnsupportedCalendarService implements CalendarService {
  final String _lastError =
      'Google Calendar no está soportado en esta plataforma.';

  @override
  Future<bool> connect(CalendarIntegrationSettings settings) async => false;

  @override
  Future<void> disconnect() async {}

  @override
  Future<String?> exportSession() async => null;

  @override
  Future<CalendarAccount?> getAccount() async => null;

  @override
  Future<String?> getLastError() async => _lastError;

  @override
  Future<TaskModel> importEventAsTask(
      {required CalendarEventModel event}) async {
    throw UnsupportedError(_lastError);
  }

  @override
  Future<List<CalendarListItemModel>> listCalendars(
          CalendarIntegrationSettings settings) async =>
      const <CalendarListItemModel>[];

  @override
  Future<CalendarRemoteDelta> pullEvents({
    required String syncToken,
    required DateTime from,
    required DateTime to,
  }) async {
    throw UnsupportedError(_lastError);
  }

  @override
  Future<CalendarEventModel> pushEvent(CalendarEventModel event) async {
    throw UnsupportedError(_lastError);
  }

  @override
  Future<void> deleteEvent(String googleEventId) async {
    throw UnsupportedError(_lastError);
  }

  @override
  Future<void> restoreSession(String? encodedSession) async {}

  @override
  Future<CalendarLink> upsertTaskEvent({
    required CalendarIntegrationSettings settings,
    required TaskModel task,
  }) async {
    throw UnsupportedError(_lastError);
  }
}

CalendarService createCalendarServicePlatform() => UnsupportedCalendarService();
