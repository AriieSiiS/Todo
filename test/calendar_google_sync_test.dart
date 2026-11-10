import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/domain/repositories/calendar_repository.dart';

class _GoogleSimulado implements CalendarRepository {
  final Map<String, CalendarEventModel> remotos = {};
  final List<String> borrados = [];
  final List<String> tokensRecibidos = [];
  bool caducarToken = false;
  int contador = 0;
  DateTime reloj = DateTime(2026, 11, 9, 12);

  DateTime _avanzar() => reloj = reloj.add(const Duration(minutes: 1));

  void ponerRemoto(CalendarEventModel evento) {
    remotos[evento.googleEventId!] =
        evento.copyWith(googleUpdatedAt: _avanzar());
  }

  List<CalendarRemoteChange> cambiosPendientes = [];

  @override
  Future<CalendarRemoteDelta> pullEvents({
    required String syncToken,
    required DateTime from,
    required DateTime to,
  }) async {
    tokensRecibidos.add(syncToken);
    if (caducarToken && syncToken.isNotEmpty) {
      caducarToken = false;
      throw const CalendarSyncTokenExpired();
    }
    final cambios = syncToken.isEmpty
        ? remotos.values
            .map((e) => CalendarRemoteChange(
                googleEventId: e.googleEventId!,
                event: e,
                updatedAt: e.googleUpdatedAt))
            .toList()
        : cambiosPendientes;
    cambiosPendientes = [];
    return CalendarRemoteDelta(
        changes: cambios,
        syncToken: 'token-${tokensRecibidos.length}',
        full: syncToken.isEmpty);
  }

  @override
  Future<CalendarEventModel> pushEvent(CalendarEventModel event) async {
    final id = event.googleEventId ?? 'g${++contador}';
    final guardado = event.copyWith(
        googleEventId: id,
        googleUpdatedAt: _avanzar(),
        clearLocalUpdatedAt: true);
    remotos[id] = guardado;
    return guardado;
  }

  @override
  Future<void> deleteEvent(String googleEventId) async {
    borrados.add(googleEventId);
    remotos.remove(googleEventId);
  }

  @override
  Future<bool> connect(CalendarIntegrationSettings settings) async => true;
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> restoreSession(String? encodedSession) async {}
  @override
  Future<String?> exportSession() async => null;
  @override
  Future<CalendarAccount?> getAccount() async => null;
  @override
  Future<String?> getLastError() async => null;
  @override
  Future<TaskModel> importEventAsTask({required CalendarEventModel event}) =>
      throw UnimplementedError();
  @override
  Future<CalendarLink> upsertTaskEvent({
    required CalendarIntegrationSettings settings,
    required TaskModel task,
  }) =>
      throw UnimplementedError();
}

CalendarEventModel _remoto(String id, String titulo, DateTime inicio,
        {String? tarea}) =>
    CalendarEventModel(
      id: id,
      calendarId: 'primary',
      title: titulo,
      startAt: inicio,
      endAt: inicio.add(const Duration(hours: 1)),
      originTaskId: tarea,
      googleEventId: id,
    );

TodoWorkspace _crear(_GoogleSimulado google) {
  SharedPreferences.setMockInitialValues({});
  final controller = TodoWorkspace.createForTest(calendarService: google);
  controller.updateCalendarSettings(
      controller.calendarSettings.copyWith(connected: true));
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final hoy = DateTime.now();
  final manana = DateTime(hoy.year, hoy.month, hoy.day + 1, 9);

  test('trae los eventos de Google y no duplica los de tareas enlazadas',
      () async {
    final google = _GoogleSimulado()
      ..ponerRemoto(_remoto('a', 'Dentista', manana))
      ..ponerRemoto(_remoto('b', 'De una tarea', manana, tarea: 't1'));
    final controller = _crear(google);
    addTearDown(controller.dispose);

    await controller.syncCalendar();

    expect(controller.calendarEvents.map((e) => e.title), ['Dentista']);
    expect(controller.calendarSettings.syncToken, isNotEmpty);
    expect(controller.calendarSettings.lastSyncAt, isNotNull);
  });

  test('los eventos creados, editados y borrados en Todo llegan a Google',
      () async {
    final google = _GoogleSimulado();
    final controller = _crear(google);
    addTearDown(controller.dispose);

    final evento = controller.createCalendarEvent(
        title: 'Cena',
        startAt: manana,
        endAt: manana.add(const Duration(hours: 2)));
    await controller.syncCalendar();
    final enlazado = controller.calendarEvents.single;
    expect(enlazado.googleEventId, 'g1');
    expect(enlazado.localUpdatedAt, isNull);
    expect(google.remotos['g1']!.title, 'Cena');

    controller.updateCalendarEvent(enlazado.copyWith(title: 'Cena con Marta'));
    await controller.syncCalendar();
    expect(google.remotos['g1']!.title, 'Cena con Marta');

    controller.deleteCalendarEvent(evento.id);
    expect(controller.calendarEvents, isEmpty);
    await controller.syncCalendar();
    expect(google.borrados, ['g1']);
    expect(controller.calendarSettings.pendingDeletions, isEmpty);
  });

  test('los cambios y borrados de Google llegan con el token incremental',
      () async {
    final google = _GoogleSimulado()
      ..ponerRemoto(_remoto('a', 'Dentista', manana))
      ..ponerRemoto(_remoto('b', 'Gimnasio', manana));
    final controller = _crear(google);
    addTearDown(controller.dispose);
    await controller.syncCalendar();

    final cambiado = _remoto('a', 'Dentista (cambio de hora)', manana).copyWith(
        googleUpdatedAt: DateTime.now().add(const Duration(minutes: 5)));
    google.cambiosPendientes = [
      CalendarRemoteChange(
          googleEventId: 'a',
          event: cambiado,
          updatedAt: cambiado.googleUpdatedAt),
      CalendarRemoteChange(
          googleEventId: 'b',
          updatedAt: DateTime.now().add(const Duration(minutes: 5))),
    ];
    await controller.syncCalendar();

    expect(google.tokensRecibidos.last, startsWith('token-'));
    expect(controller.calendarEvents.map((e) => e.title),
        ['Dentista (cambio de hora)']);
  });

  test('ante un conflicto gana el cambio más reciente', () async {
    final google = _GoogleSimulado()
      ..ponerRemoto(_remoto('a', 'Original', manana));
    final controller = _crear(google);
    addTearDown(controller.dispose);
    await controller.syncCalendar();

    // Edición local posterior a la de Google: gana Todo.
    controller.updateCalendarEvent(
        controller.calendarEvents.single.copyWith(title: 'Local'));
    google.cambiosPendientes = [
      CalendarRemoteChange(
          googleEventId: 'a',
          event: _remoto('a', 'Remoto antiguo', manana),
          updatedAt: DateTime.now().subtract(const Duration(hours: 1))),
    ];
    await controller.syncCalendar();
    expect(controller.calendarEvents.single.title, 'Local');
    expect(google.remotos['a']!.title, 'Local');

    // Edición de Google posterior a la local: gana Google.
    controller.updateCalendarEvent(
        controller.calendarEvents.single.copyWith(title: 'Local 2'));
    google.cambiosPendientes = [
      CalendarRemoteChange(
          googleEventId: 'a',
          event: _remoto('a', 'Remoto nuevo', manana),
          updatedAt: DateTime.now().add(const Duration(hours: 1))),
    ];
    await controller.syncCalendar();
    expect(controller.calendarEvents.single.title, 'Remoto nuevo');
  });

  test('si Google invalida el token se lee de nuevo la ventana completa',
      () async {
    final google = _GoogleSimulado()
      ..ponerRemoto(_remoto('a', 'Dentista', manana));
    final controller = _crear(google);
    addTearDown(controller.dispose);
    await controller.syncCalendar();

    google.caducarToken = true;
    google.remotos.remove('a');
    await controller.syncCalendar();

    expect(google.tokensRecibidos.where((t) => t.isEmpty).length, 2);
    expect(controller.calendarEvents, isEmpty);
  });
}
