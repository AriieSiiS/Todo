import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';

void main() {
  for (final sort in [TodaySort.category, TodaySort.project]) {
    test('orden por ${sort.name}: relaciones, empates y cambios de nombre', () {
      final controller = TodoWorkspace.createForTest(
        snapshot: AppStateSnapshot(
          tasks: const [
            TaskModel(
                id: 'b',
                title: 'Segunda',
                categoryIds: ['b', 'a'],
                projectIds: ['b', 'a']),
            TaskModel(
                id: 'a',
                title: 'Primera',
                categoryIds: ['a'],
                projectIds: ['a']),
            TaskModel(id: 'sin', title: 'Sin relación'),
            TaskModel(
                id: 'rota',
                title: 'Relación ausente',
                categoryIds: ['ausente'],
                projectIds: ['ausente']),
            TaskModel(
                id: 'completada',
                title: 'Completada',
                status: TaskStatus.completed),
            TaskModel(id: 'subtarea', title: 'Subtarea', parentTaskId: 'a'),
          ],
          categories: const [
            CategoryModel(
                id: 'a', name: 'Alfa', colorValue: 0, icon: Icons.home),
            CategoryModel(
                id: 'b', name: 'Beta', colorValue: 0, icon: Icons.home),
            CategoryModel(
                id: 'a', name: 'Duplicada', colorValue: 0, icon: Icons.home),
          ],
          projects: const [
            ProjectModel(
                id: 'a',
                name: 'Alfa',
                description: '',
                colorValue: 0,
                icon: Icons.home),
            ProjectModel(
                id: 'b',
                name: 'Beta',
                description: '',
                colorValue: 0,
                icon: Icons.home),
            ProjectModel(
                id: 'a',
                name: 'Duplicado',
                description: '',
                colorValue: 0,
                icon: Icons.home),
          ],
          notes: const [],
          daySettings: const DaySettings(),
          notificationSettings: const DeviceNotificationSettings(),
          calendarSettings: const CalendarIntegrationSettings(),
          section: AppSection.today,
          todaySort: sort,
        ),
      );
      addTearDown(controller.dispose);
      final originalIds = controller.tasks.map((task) => task.id).toList();
      final ordered = controller.tasksForToday();
      expect(ordered.take(2).map((task) => task.id), ['a', 'b']);
      expect(ordered.skip(2).map((task) => task.id),
          unorderedEquals(['sin', 'rota']));
      ordered.clear();
      expect(controller.tasks.map((task) => task.id), originalIds);

      if (sort == TodaySort.category) {
        controller.updateCategory(
            controller.categoryById('a')!.copyWith(name: 'Zeta'));
      } else {
        controller
            .updateProject(controller.projectById('a')!.copyWith(name: 'Zeta'));
      }
      expect(controller.tasksForToday().take(2).map((task) => task.id),
          ['b', 'a']);
      expect(controller.tasks.map((task) => task.id), originalIds);
    });
  }
}
