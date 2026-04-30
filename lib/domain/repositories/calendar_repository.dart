import '../models.dart';

abstract class CalendarRepository {
  Future<bool> connect(CalendarIntegrationSettings settings);
  Future<void> disconnect();
  Future<void> restoreSession(String? encodedSession);
  Future<String?> exportSession();
  Future<CalendarAccount?> getAccount();
  Future<String?> getLastError();
  Future<List<CalendarEventModel>> listEvents({
    required CalendarIntegrationSettings settings,
    required DateTime from,
    required DateTime to,
  });
  Future<TaskModel> importEventAsTask({required CalendarEventModel event});
  Future<CalendarLink> upsertTaskEvent({
    required CalendarIntegrationSettings settings,
    required TaskModel task,
  });
}
