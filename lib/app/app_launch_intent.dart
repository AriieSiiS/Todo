import '../domain/models.dart';

enum LaunchEditorTarget { none, task, project, category }

class AppLaunchIntent {
  const AppLaunchIntent({
    this.section,
    this.editorTarget = LaunchEditorTarget.none,
    this.testNotification = false,
    this.importantAlarmId,
  });

  final AppSection? section;
  final LaunchEditorTarget editorTarget;
  final bool testNotification;
  final String? importantAlarmId;

  bool get opensEditor => editorTarget != LaunchEditorTarget.none;

  static AppLaunchIntent fromArgs(List<String> args) {
    AppSection? section;
    var editorTarget = LaunchEditorTarget.none;
    var testNotification = false;
    String? importantAlarmId;

    for (final arg in args) {
      if (arg == '--section=today') {
        section = AppSection.today;
      } else if (arg == '--section=projects') {
        section = AppSection.projects;
      } else if (arg == '--section=categories') {
        section = AppSection.categories;
      } else if (arg == '--section=expenses') {
        section = AppSection.expenses;
      } else if (arg == '--section=calendar') {
        section = AppSection.calendar;
      } else if (arg == '--section=library') {
        section = AppSection.library;
      } else if (arg == '--section=inbox') {
        section = AppSection.inbox;
      } else if (arg == '--section=completed') {
        section = AppSection.completed;
      } else if (arg == '--section=settings') {
        section = AppSection.settings;
      } else if (arg == '--section=wardrobe') {
        section = AppSection.wardrobe;
      } else if (arg == '--section=household') {
        section = AppSection.household;
      } else if (arg == '--section=plants') {
        section = AppSection.plants;
      } else if (arg == '--section=recipes') {
        section = AppSection.recipes;
      } else if (arg == '--new-task') {
        section = AppSection.today;
        editorTarget = LaunchEditorTarget.task;
      } else if (arg == '--new-project') {
        section = AppSection.projects;
        editorTarget = LaunchEditorTarget.project;
      } else if (arg == '--new-category') {
        section = AppSection.categories;
        editorTarget = LaunchEditorTarget.category;
      } else if (arg == '--test-notification') {
        testNotification = true;
      } else if (arg.startsWith('--important-alarm=')) {
        importantAlarmId = arg.substring('--important-alarm='.length).trim();
      }
    }

    return AppLaunchIntent(
      section: section,
      editorTarget: editorTarget,
      testNotification: testNotification,
      importantAlarmId:
          importantAlarmId?.isEmpty ?? true ? null : importantAlarmId,
    );
  }
}
