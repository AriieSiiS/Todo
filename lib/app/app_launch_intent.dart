import '../domain/models.dart';

enum LaunchEditorTarget { none, task, project, category }

class AppLaunchIntent {
  const AppLaunchIntent({
    this.section = AppSection.today,
    this.editorTarget = LaunchEditorTarget.none,
  });

  final AppSection section;
  final LaunchEditorTarget editorTarget;

  bool get opensEditor => editorTarget != LaunchEditorTarget.none;

  static AppLaunchIntent fromArgs(List<String> args) {
    var section = AppSection.today;
    var editorTarget = LaunchEditorTarget.none;

    for (final arg in args) {
      if (arg == '--section=today') {
        section = AppSection.today;
      } else if (arg == '--section=projects') {
        section = AppSection.projects;
      } else if (arg == '--section=categories') {
        section = AppSection.categories;
      } else if (arg == '--section=calendar') {
        section = AppSection.calendar;
      } else if (arg == '--section=inbox') {
        section = AppSection.inbox;
      } else if (arg == '--section=completed') {
        section = AppSection.completed;
      } else if (arg == '--section=settings') {
        section = AppSection.settings;
      } else if (arg == '--new-task') {
        section = AppSection.today;
        editorTarget = LaunchEditorTarget.task;
      } else if (arg == '--new-project') {
        section = AppSection.projects;
        editorTarget = LaunchEditorTarget.project;
      } else if (arg == '--new-category') {
        section = AppSection.categories;
        editorTarget = LaunchEditorTarget.category;
      }
    }

    return AppLaunchIntent(section: section, editorTarget: editorTarget);
  }
}
