import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';

const _contenido = 'Este contenido debe poder leerse con claridad.';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final brillo in Brightness.values) {
    testWidgets('el contenido de una nota conserva contraste en $brillo',
        (tester) async {
      tester.view.physicalSize = const Size(2048, 1104);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TodoWorkspace.createForTest(
        snapshot: AppStateSnapshot.fromJson({
          'notes': [
            QuickNote(
                    id: 'nota-legible',
                    content: 'Nota de contraste\n$_contenido',
                    createdAt: DateTime(2026, 10, 30))
                .toJson(),
          ]
        }),
      );
      addTearDown(controller.dispose);
      final tema = buildTodoTheme(brightness: brillo);
      await tester.pumpWidget(MaterialApp(
        theme: tema,
        home: Scaffold(body: InboxPage(controller: controller)),
      ));
      await tester.pumpAndSettle();
      final parrafo = tester.widget<RichText>(find
          .descendant(
              of: find.byKey(const ValueKey('contenidoNotaDirecto')),
              matching: find.byWidgetPredicate((widget) =>
                  widget is RichText &&
                  widget.text.toPlainText().contains(_contenido)))
          .first);
      final color = _colorContenido(parrafo.text, const TextStyle())!;
      final fondo = tema.extension<TodoVisuals>()!.panel;
      final luzTexto = Color.alphaBlend(color, fondo).computeLuminance();
      final luzFondo = fondo.computeLuminance();
      final contraste = luzTexto > luzFondo
          ? (luzTexto + .05) / (luzFondo + .05)
          : (luzFondo + .05) / (luzTexto + .05);
      expect(contraste, greaterThanOrEqualTo(4.5));
      expect(tester.takeException(), isNull);
    });
  }
}

Color? _colorContenido(InlineSpan span, TextStyle heredado) {
  if (span is! TextSpan) return null;
  final estilo = heredado.merge(span.style);
  if (span.text?.contains(_contenido) ?? false) return estilo.color;
  for (final hijo in span.children ?? <InlineSpan>[]) {
    final color = _colorContenido(hijo, estilo);
    if (color != null) return color;
  }
  return null;
}
