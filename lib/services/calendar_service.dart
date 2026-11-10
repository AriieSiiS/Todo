import '../domain/models.dart';
import 'calendar_service_factory.dart';

abstract class CalendarService {
  Future<void> restoreSession(String? encodedSession);
  Future<bool> connect(CalendarIntegrationSettings settings);
  Future<void> disconnect();
  Future<CalendarAccount?> getAccount();
  Future<List<CalendarListItemModel>> listCalendars(
      CalendarIntegrationSettings settings);
  Future<CalendarRemoteDelta> pullEvents({
    required String syncToken,
    required DateTime from,
    required DateTime to,
  });
  Future<CalendarEventModel> pushEvent(CalendarEventModel event);
  Future<void> deleteEvent(String googleEventId);
  Future<CalendarLink> upsertTaskEvent({
    required CalendarIntegrationSettings settings,
    required TaskModel task,
  });
  Future<TaskModel> importEventAsTask({
    required CalendarEventModel event,
  });
  Future<String?> exportSession();
  Future<String?> getLastError();
}

CalendarService createCalendarService() => createCalendarServiceImpl();
