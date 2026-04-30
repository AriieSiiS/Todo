import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../app/todo_theme.dart';
import '../../domain/models.dart';
import '../../application/state/todo_workspace.dart';

part 'task_editor.dart';
part 'project_editor.dart';
part 'category_editor.dart';
part 'editor_components.dart';
part 'editor_pickers.dart';

Future<void> showTaskEditor(
  BuildContext context,
  TodoWorkspace controller, {
  TaskModel? initialTask,
  String? parentTaskId,
  DateTime? initialDateOverride,
  String? initialTitle,
  String? initialDescription,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (context) => _TaskEditorDialog(
      controller: controller,
      initialTask: initialTask,
      parentTaskId: parentTaskId,
      initialDateOverride: initialDateOverride,
      initialTitle: initialTitle,
      initialDescription: initialDescription,
    ),
  );
}

Future<void> showProjectEditor(
  BuildContext context,
  TodoWorkspace controller, {
  ProjectModel? initialProject,
  String? initialName,
  String? initialDescription,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (context) => _ProjectEditorDialog(
      controller: controller,
      initialProject: initialProject,
      initialName: initialName,
      initialDescription: initialDescription,
    ),
  );
}

Future<void> showCategoryEditor(
  BuildContext context,
  TodoWorkspace controller, {
  CategoryModel? initialCategory,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CategoryEditorDialog(
      controller: controller,
      initialCategory: initialCategory,
    ),
  );
}
