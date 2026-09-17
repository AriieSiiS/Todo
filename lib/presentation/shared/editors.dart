import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  final child = _TaskEditorDialog(
    controller: controller,
    initialTask: initialTask,
    parentTaskId: parentTaskId,
    initialDateOverride: initialDateOverride,
    initialTitle: initialTitle,
    initialDescription: initialDescription,
  );
  if (_useMobileEditor(context)) {
    return _showMobileEditor(context, child);
  }
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (context) => child,
  );
}

Future<void> showProjectEditor(
  BuildContext context,
  TodoWorkspace controller, {
  ProjectModel? initialProject,
  String? initialName,
  String? initialDescription,
}) {
  final child = _ProjectEditorDialog(
    controller: controller,
    initialProject: initialProject,
    initialName: initialName,
    initialDescription: initialDescription,
  );
  if (_useMobileEditor(context)) {
    return _showMobileEditor(context, child);
  }
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (context) => child,
  );
}

Future<void> showCategoryEditor(
  BuildContext context,
  TodoWorkspace controller, {
  CategoryModel? initialCategory,
}) {
  final child = _CategoryEditorDialog(
    controller: controller,
    initialCategory: initialCategory,
  );
  if (_useMobileEditor(context)) {
    return _showMobileEditor(context, child);
  }
  return showDialog<void>(
    context: context,
    builder: (context) => child,
  );
}

bool _useMobileEditor(BuildContext context) {
  return MediaQuery.sizeOf(context).width < 700;
}

Future<void> _showMobileEditor(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.96,
      child: child,
    ),
  );
}
