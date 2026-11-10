import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/knowledge/knowledge_workspace_page.dart';

void main() {
  for (final brillo in Brightness.values) {
    testWidgets('la documentación conserva contraste en $brillo',
        (tester) async {
      tester.view.physicalSize = const Size(2048, 1104);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ahora = DateTime(2026, 10, 30);
      final libro = LibraryItem(
          id: 'libro-contraste',
          type: LibraryItemType.book,
          title: 'Libro de contraste',
          note: 'Un párrafo legible.',
          status: LibraryItemStatus.inProgress,
          createdAt: ahora,
          updatedAt: ahora);
      final controller = TodoWorkspace.createForTest(
          snapshot: AppStateSnapshot.fromJson({
        'libraryItems': [libro.toJson()]
      }));
      await controller.knowledge.ensureLibraryRoots([libro]);
      final tema = buildTodoTheme(brightness: brillo);
      await tester.pumpWidget(MaterialApp(
        theme: tema,
        locale: const Locale('es'),
        localizationsDelegates: const [
          AppFlowyEditorLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        supportedLocales: const [Locale('es')],
        home:
            KnowledgeWorkspacePage(controller: controller, libraryItem: libro),
      ));
      await tester.pumpAndSettle();
      final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
      final fondo = tester
          .widget<Container>(find
              .ancestor(
                  of: find.byType(AppFlowyEditor),
                  matching: find.byType(Container))
              .first)
          .color!;
      final texto = editor.editorStyle.textStyleConfiguration.text.color!;
      final a = texto.computeLuminance() + .05;
      final b = fondo.computeLuminance() + .05;
      expect(a > b ? a / b : b / a, greaterThanOrEqualTo(4.5));
      expect(fondo, tema.extension<TodoVisuals>()!.panel);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      controller.dispose();
    });
  }
}
