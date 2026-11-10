import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'los paneles de Hoy conservan el tamaño de texto al faltar altura',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot.fromJson({
        'notes': [
          for (var i = 0; i < 12; i++)
            QuickNote(
                    id: 'nota-$i',
                    content: 'Nota de prueba $i\nContenido de la nota.',
                    createdAt: DateTime(2026, 10, 30))
                .toJson(),
        ]
      }),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(brightness: Brightness.dark),
      home: Scaffold(body: TodayPage(controller: controller)),
    ));
    await tester.pumpAndSettle();
    final cabecera = tester.renderObject<RenderBox>(find.text('Semana activa'));
    final escala = (cabecera.localToGlobal(const Offset(100, 0)) -
                cabecera.localToGlobal(Offset.zero))
            .distance /
        100;
    expect(escala, greaterThanOrEqualTo(.95),
        reason:
            'La columna auxiliar debe desplazarse sin encoger su tipografía.');
    expect(tester.takeException(), isNull);
  });

  for (final brillo in Brightness.values) {
    testWidgets('los contadores de la semana tienen contraste en $brillo',
        (tester) async {
      tester.view.physicalSize = const Size(2048, 1104);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      final tema = buildTodoTheme(brightness: brillo);
      final panel = tema.extension<TodoVisuals>()!.panel;
      await tester.pumpWidget(MaterialApp(
        theme: tema,
        home: Scaffold(body: TodayPage(controller: controller)),
      ));
      await tester.pumpAndSettle();
      final semana = find
          .ancestor(
              of: find.text('Semana activa'), matching: find.byType(Column))
          .first;
      final contadores = find.descendant(of: semana, matching: find.text('0'));
      expect(contadores, findsNWidgets(7));
      for (final elemento in contadores.evaluate()) {
        final finder = find.byElementPredicate((e) => identical(e, elemento));
        final contenedor = tester.widget<Container>(find
            .ancestor(
              of: finder,
              matching: find.byWidgetPredicate((widget) =>
                  widget is Container &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration! as BoxDecoration).color != null),
            )
            .first);
        final fondo = Color.alphaBlend(
            (contenedor.decoration! as BoxDecoration).color!, panel);
        final texto = elemento.widget as Text;
        final color =
            DefaultTextStyle.of(elemento).style.merge(texto.style).color!;
        final luzTexto = Color.alphaBlend(color, fondo).computeLuminance();
        final luzFondo = fondo.computeLuminance();
        final contraste = luzTexto > luzFondo
            ? (luzTexto + .05) / (luzFondo + .05)
            : (luzFondo + .05) / (luzTexto + .05);
        expect(contraste, greaterThanOrEqualTo(4.5));
      }
    });
  }
}
