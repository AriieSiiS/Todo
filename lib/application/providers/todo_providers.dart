import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/state/todo_workspace.dart';
import '../../domain/models.dart';

final todoWorkspaceProvider = ChangeNotifierProvider<TodoWorkspace>((ref) {
  throw StateError('todoWorkspaceProvider must be overridden by TodoApp.');
});

final currentSectionProvider = Provider<AppSection>((ref) {
  return ref.watch(todoWorkspaceProvider).section;
});

final todayTasksProvider = Provider<List<TaskModel>>((ref) {
  return ref.watch(todoWorkspaceProvider).tasksForToday();
});

final completedTasksProvider = Provider<List<TaskModel>>((ref) {
  return ref.watch(todoWorkspaceProvider).completedTasks();
});
