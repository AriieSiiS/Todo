import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/services/important_alarm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la alarma activa se persiste, se pospone y se recupera', () async {
    final directory = await Directory.systemTemp.createTemp('todo_alarm_test_');
    addTearDown(() => directory.delete(recursive: true));
    final service = ImportantAlarmService(runtimeDirectory: directory);

    await service.initialize();
    await service.showTest();
    expect(service.current?.taskTitle, 'Prueba de alarma importante');

    final before = DateTime.now().add(const Duration(minutes: 5));
    await service.snoozeCurrent();
    final after = DateTime.now().add(const Duration(minutes: 5));
    expect(service.current, isNull);
    expect(service.occurrences.single.status, ImportantAlarmStatus.snoozed);
    expect(service.occurrences.single.triggerAt.isBefore(before), isFalse);
    expect(service.occurrences.single.triggerAt.isAfter(after), isFalse);
    service.dispose();

    final recovered = ImportantAlarmService(runtimeDirectory: directory);
    await recovered.initialize();
    expect(recovered.occurrences, hasLength(1));
    expect(recovered.occurrences.single.status, ImportantAlarmStatus.snoozed);
    recovered.dispose();
  });

  test('las alarmas simultáneas se atienden en orden', () async {
    final directory =
        await Directory.systemTemp.createTemp('todo_alarm_queue_');
    addTearDown(() => directory.delete(recursive: true));
    final now = DateTime.now();
    final records = [
      ImportantAlarmOccurrence(
        id: 'segunda',
        taskId: 'dos',
        taskTitle: 'Segunda',
        originalTriggerAt: now,
        triggerAt: now,
        minutesBefore: 0,
        status: ImportantAlarmStatus.active,
      ),
      ImportantAlarmOccurrence(
        id: 'primera',
        taskId: 'uno',
        taskTitle: 'Primera',
        originalTriggerAt: now.subtract(const Duration(minutes: 1)),
        triggerAt: now.subtract(const Duration(minutes: 1)),
        minutesBefore: 5,
        status: ImportantAlarmStatus.active,
      ),
    ];
    await File('${directory.path}${Platform.pathSeparator}'
            'important_alarm_state.json')
        .writeAsString(jsonEncode({
      'version': 1,
      'alarms': records.map((item) => item.toJson()).toList(),
    }));

    final service = ImportantAlarmService(runtimeDirectory: directory);
    await service.initialize();
    expect(service.current?.id, 'primera');
    expect(service.remainingCount, 2);
    await service.stopCurrent(keepApplicationOpen: true);
    expect(service.current?.id, 'segunda');
    expect(service.remainingCount, 1);
    service.dispose();
  });
}
