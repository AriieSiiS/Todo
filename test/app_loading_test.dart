import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/app/app_launch_intent.dart';
import 'package:todo/app/todo_app.dart';
import 'package:todo/application/state/todo_workspace.dart';

void main() {
  testWidgets('un fallo de carga muestra una salida y permite reintentar',
      (tester) async {
    var attempts = 0;
    final retry = Completer<TodoWorkspace>();
    await tester.pumpWidget(TodoApp(
      launchIntent: AppLaunchIntent.fromArgs([]),
      workspaceLoader: () {
        attempts++;
        return attempts == 1
            ? Future<TodoWorkspace>.error(StateError('Lectura fallida'))
            : retry.future;
      },
    ));
    await tester.pump();
    expect(find.text('No se pudo abrir Todo'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Volver a intentar'));
    await tester.pump();
    expect(attempts, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    retry.completeError(StateError('Segundo fallo'));
    await tester.pump();
    expect(find.text('Volver a intentar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
