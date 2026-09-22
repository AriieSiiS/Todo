import 'package:test/test.dart';

import '../bin/todo_lan_agent.dart';

void main() {
  test('la proyección comparte solo tareas y referencias necesarias', () {
    final projected = projectTaskSnapshot({
      'tasks': [
        {
          'id': 'activa',
          'title': 'Tarea visible',
          'status': 'active',
          'parentTaskId': null,
          'categoryIds': ['cat'],
          'projectIds': ['pro'],
          'calendarLink': {'secreto': true},
          'subtaskIds': ['sub'],
        },
        {
          'id': 'sub',
          'title': 'Subtarea',
          'status': 'completed',
          'parentTaskId': 'activa',
          'categoryIds': [],
          'projectIds': [],
        },
        {
          'id': 'archivada',
          'title': 'No visible',
          'status': 'archived',
          'parentTaskId': null,
        },
      ],
      'categories': [
        {'id': 'cat', 'name': 'Casa', 'colorValue': 1},
        {'id': 'otra', 'name': 'Privada'},
      ],
      'projects': [
        {'id': 'pro', 'name': 'Proyecto', 'colorValue': 2},
      ],
      'daySettings': {'dayEndsAtHour': 5, 'nextDayVisibleAtHour': 10},
      'notes': [
        {'text': 'no compartir'}
      ],
      'expenses': [
        {'amount': 200}
      ],
      'calendarSettings': {'desktopClientSecret': 'no compartir'},
    }, serverId: 'pc');

    expect(projected['tasks'], hasLength(2));
    expect(projected['categories'], hasLength(1));
    expect(projected['projects'], hasLength(1));
    expect(projected, isNot(contains('notes')));
    expect(projected, isNot(contains('expenses')));
    expect(projected, isNot(contains('calendarSettings')));
    expect((projected['tasks'] as List).first, isNot(contains('calendarLink')));
  });
}
