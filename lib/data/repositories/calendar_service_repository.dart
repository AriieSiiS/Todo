import '../../domain/models.dart';
import '../../domain/repositories/calendar_repository.dart';
import '../../services/calendar_service.dart';

class CalendarServiceRepository implements CalendarRepository {
  CalendarServiceRepository(this._service);

  final CalendarService _service;

  @override
  Future<bool> connect(CalendarIntegrationSettings settings) =>
      _service.connect(settings);

  @override
  Future<void> disconnect() => _service.disconnect();

  @override
  Future<String?> exportSession() => _service.exportSession();

  @override
  Future<CalendarAccount?> getAccount() => _service.getAccount();

  @override
  Future<String?> getLastError() => _service.getLastError();

  @override
  Future<TaskModel> importEventAsTask({required CalendarEventModel event}) =>
      _service.importEventAsTask(event: event);

  @override
  Future<List<CalendarEventModel>> listEvents({
    required CalendarIntegrationSettings settings,
    required DateTime from,
    required DateTime to,
  }) =>
      _service.listEvents(settings: settings, from: from, to: to);

  @override
  Future<void> restoreSession(String? encodedSession) =>
      _service.restoreSession(encodedSession);

  @override
  Future<CalendarLink> upsertTaskEvent({
    required CalendarIntegrationSettings settings,
    required TaskModel task,
  }) =>
      _service.upsertTaskEvent(settings: settings, task: task);
}
