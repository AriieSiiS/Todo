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

  test('Ropa comparte prendas visibles y maletas sin datos ajenos', () {
    final projected = projectWardrobeSnapshot({
      'wardrobeItems': [
        {
          'id': 'camisa',
          'name': 'Camisa azul',
          'category': 'Camisas',
          'imagePath': 'items/privado.png',
          'imageSha256': 'abc',
          'price': 59,
          'laundryStatus': 'dirty',
        },
        {'id': 'abrigo', 'name': 'Abrigo', 'archived': true},
        {'id': 'oculta', 'name': 'Oculta', 'archived': true},
      ],
      'wardrobePackingLists': [
        {
          'id': 'viaje',
          'name': 'Viaje',
          'startDate': '2026-10-01',
          'endDate': '2026-10-05',
          'entries': [
            {'itemId': 'camisa', 'quantity': 3, 'packed': false},
            {'itemId': 'abrigo', 'quantity': 1, 'packed': true},
          ],
          'discardedItemIds': ['oculta'],
        },
      ],
      'wardrobeWearLogs': [
        {'private': true}
      ],
      'notes': [
        {'private': true}
      ],
    }, serverId: 'pc');
    final items = projected['items'] as List;
    expect(items, hasLength(2));
    expect(items.map((item) => item['id']), containsAll(['camisa', 'abrigo']));
    expect(items.first, isNot(contains('imagePath')));
    expect(items.first, isNot(contains('price')));
    expect(items.first, isNot(contains('laundryStatus')));
    expect(projected, isNot(contains('wardrobeWearLogs')));
    expect(projected, isNot(contains('notes')));
    expect((projected['packingLists'] as List).first,
        isNot(contains('discardedItemIds')));
  });
}
