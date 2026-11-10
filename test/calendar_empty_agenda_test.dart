import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final brillo in Brightness.values) {
    testWidgets('la agenda vacía se abre sin errores en $brillo',
        (tester) async {
      tester.view.physicalSize = const Size(2048, 1104);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(brightness: brillo),
        home: Scaffold(body: CalendarPage(controller: controller)),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agenda').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('No hay tareas ni eventos programados en la agenda.'),
          findsOneWidget);
    });
  }
}
