import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  testWidgets('el mes conserva las fechas al cruzar el cambio de hora',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(2048, 1104);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: CalendarPage(controller: controller))));
    await tester.pumpAndSettle();
    final hoy = controller.logicalDate();
    final meses = (2026 - hoy.year) * 12 + 10 - hoy.month;
    for (var paso = 0; paso < meses.abs(); paso++) {
      await tester.tap(find
          .byIcon(meses < 0
              ? Icons.chevron_left_rounded
              : Icons.chevron_right_rounded)
          .first);
      await tester.pumpAndSettle();
    }
    final celdas = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_CalendarMonthCell');
    final dias = celdas
        .evaluate()
        .map((elemento) => (elemento.widget as dynamic).day as DateTime)
        .toList();
    expect(dias, hasLength(42));
    for (var indice = 0; indice < dias.length; indice++) {
      expect(dias[indice], DateTime(2026, 9, 28 + indice));
      expect(dias[indice].weekday, indice % 7 + 1);
    }
  });
}
