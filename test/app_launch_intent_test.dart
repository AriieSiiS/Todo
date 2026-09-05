import 'package:flutter_test/flutter_test.dart';
import 'package:todo/app/app_launch_intent.dart';
import 'package:todo/domain/models.dart';

void main() {
  test('a normal launch does not override the persisted section', () {
    final intent = AppLaunchIntent.fromArgs(const []);

    expect(intent.section, isNull);
    expect(intent.opensEditor, isFalse);
  });

  test('an explicit launch section still overrides navigation', () {
    final intent = AppLaunchIntent.fromArgs(const ['--section=library']);

    expect(intent.section, AppSection.library);
  });

  test('editor shortcuts keep their explicit destination', () {
    final intent = AppLaunchIntent.fromArgs(const ['--new-project']);

    expect(intent.section, AppSection.projects);
    expect(intent.editorTarget, LaunchEditorTarget.project);
  });

  test('notification smoke test can be requested explicitly', () {
    final intent = AppLaunchIntent.fromArgs(const ['--test-notification']);

    expect(intent.testNotification, isTrue);
    expect(intent.section, isNull);
  });
}
