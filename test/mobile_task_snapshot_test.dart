import 'package:flutter_test/flutter_test.dart';
import 'package:todo/mobile/mobile_task_snapshot.dart';

void main() {
  test('Hoy conserva vencidas, tareas sin fecha y excluye completadas', () {
    final snapshot = MobileTaskSnapshot.fromJson({
      'protocolVersion': 1,
      'serverId': 'pc',
      'revision': 'revision',
      'generatedAt': '2026-09-22T08:00:00Z',
      'daySettings': {'dayEndsAtHour': 5, 'nextDayVisibleAtHour': 10},
      'categories': <Object>[],
      'projects': <Object>[],
      'tasks': [
        _task('vencida', scheduledAt: '2026-09-20T09:00:00'),
        _task('hoy', scheduledAt: '2026-09-22T12:00:00'),
        _task('sin-fecha'),
        _task(
          'completada',
          scheduledAt: '2026-09-22T10:00:00',
          status: 'completed',
        ),
      ],
    });

    final today = snapshot.tasksForToday(DateTime(2026, 9, 22, 13));
    expect(today.map((task) => task.id),
        containsAll(['vencida', 'hoy', 'sin-fecha']));
    expect(today.map((task) => task.id), isNot(contains('completada')));
  });

  test('Próximas materializa la siguiente ocurrencia recurrente', () {
    final recurring = _task('semanal', scheduledAt: '2026-09-21T08:30:00')
      ..['recurrence'] = {
        'type': 'weekly',
        'interval': 1,
        'weekdays': <int>[],
        'activeMonths': <int>[],
      };
    final snapshot = MobileTaskSnapshot.fromJson({
      'protocolVersion': 1,
      'serverId': 'pc',
      'revision': 'revision',
      'generatedAt': '2026-09-22T08:00:00Z',
      'daySettings': {'dayEndsAtHour': 5, 'nextDayVisibleAtHour': 10},
      'categories': <Object>[],
      'projects': <Object>[],
      'tasks': [recurring],
    });

    final upcoming = snapshot.upcomingTasks(DateTime(2026, 9, 22, 13));
    expect(upcoming, hasLength(1));
    expect(upcoming.single.scheduledAt, DateTime(2026, 9, 28, 8, 30));
  });
}

Map<String, dynamic> _task(
  String id, {
  String? scheduledAt,
  String status = 'active',
}) =>
    <String, dynamic>{
      'id': id,
      'title': id,
      'status': status,
      'scheduledAt': scheduledAt,
      'priority': 'medium',
      'parentTaskId': null,
      'categoryIds': <String>[],
      'projectIds': <String>[],
      'subtaskIds': <String>[],
      'checklist': <String>[],
      'materials': <String>[],
      'reminderRules': <Object>[],
      'recurrence': {
        'type': 'none',
        'interval': 1,
        'weekdays': <int>[],
        'activeMonths': <int>[],
      },
    };
