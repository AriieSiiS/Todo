import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/app_launch_intent.dart';
import 'package:todo/app/todo_app.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/domain/repositories/todo_state_repository.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final brillo in Brightness.values) {
    final nombreTema = brillo == Brightness.dark ? 'oscuro' : 'claro';
    testWidgets('los años y sus contadores son legibles en tema $nombreTema',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final actual = DateTime.now().year;
      final controller = TodoWorkspace.createForTest(
        snapshot: AppStateSnapshot.fromJson({
          'libraryItems': [
            for (final anio in [actual, actual - 1])
              LibraryItem(
                id: 'juego-$anio',
                type: LibraryItemType.game,
                title: 'Juego de $anio',
                status: LibraryItemStatus.completed,
                completedDate: DateTime(anio, 1, 1),
                createdAt: DateTime(anio, 1, 1),
                updatedAt: DateTime(anio, 1, 1),
              ).toJson(),
          ],
        }),
      );
      addTearDown(controller.dispose);
      final tema = buildTodoTheme(brightness: brillo);
      final panel = tema.extension<TodoVisuals>()!.panel;
      await tester.pumpWidget(MaterialApp(
        theme: tema,
        home: Scaffold(body: LibraryPage(controller: controller)),
      ));
      await tester.pumpAndSettle();
      final resumen = find
          .ancestor(
            of: find.text('Explora tu biblioteca por año'),
            matching: find.byType(Column),
          )
          .first;
      for (final anio in [actual, actual - 1]) {
        final etiqueta =
            find.descendant(of: resumen, matching: find.text('$anio'));
        final fila =
            find.ancestor(of: etiqueta, matching: find.byType(Row)).first;
        final contenedor = tester.widget<Container>(
          find.ancestor(of: fila, matching: find.byType(Container)).first,
        );
        final fondo = Color.alphaBlend(
          (contenedor.decoration! as BoxDecoration).color!,
          panel,
        );
        for (final elemento in find
            .descendant(of: fila, matching: find.byType(Text))
            .evaluate()) {
          final texto = elemento.widget as Text;
          final color =
              DefaultTextStyle.of(elemento).style.merge(texto.style).color!;
          final luzTexto = Color.alphaBlend(color, fondo).computeLuminance();
          final luzFondo = fondo.computeLuminance();
          final contraste = luzTexto > luzFondo
              ? (luzTexto + .05) / (luzFondo + .05)
              : (luzFondo + .05) / (luzTexto + .05);
          expect(contraste, greaterThanOrEqualTo(4.5),
              reason:
                  'Contraste de ${texto.data} en el año $anio con tema $nombreTema');
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('el interruptor cambia el tema y conserva la elección al cargar',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TodoWorkspace.createForTest();
    await _abrir(tester, controller);

    expect(_tema(tester).brightness, Brightness.light);
    final interruptor = find.byKey(const ValueKey('sidebar-dark-mode'));
    expect(interruptor, findsOneWidget);
    await tester.tap(interruptor);
    await tester.pumpAndSettle();
    expect(_tema(tester).brightness, Brightness.dark);
    final colores = _tema(tester).extension<TodoVisuals>()!;
    expect(colores.panel.computeLuminance(), lessThan(0.1));
    expect(colores.textStrong.computeLuminance(), greaterThan(0.7));

    final guardado = controller.exportSnapshot().toPrettyJson();
    expect((jsonDecode(guardado) as Map)['darkMode'], isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    final recuperado = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot.fromJson(jsonDecode(guardado)),
    );
    await _abrir(tester, recuperado);
    expect(_tema(tester).brightness, Brightness.dark);

    await tester.tap(interruptor);
    await tester.pumpAndSettle();
    expect(_tema(tester).brightness, Brightness.light);
    expect(
        (jsonDecode(recuperado.exportSnapshot().toPrettyJson())
            as Map)['darkMode'],
        isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'el modo oscuro se puede quitar desde Más en una ventana estrecha',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TodoWorkspace.createForTest();
    await _abrir(tester, controller);
    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Modo oscuro'));
    await tester.tap(find.text('Modo oscuro'));
    await tester.pumpAndSettle();
    expect(_tema(tester).brightness, Brightness.dark);
    await tester.tap(find.text('Modo oscuro'));
    await tester.pumpAndSettle();
    expect(_tema(tester).brightness, Brightness.light);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('los datos sin preferencia de tema mantienen el modo claro', () {
    final snapshot = AppStateSnapshot.fromJson({});
    expect(snapshot.toJson()['darkMode'], isFalse);
  });

  test('el guardado local conserva ambos estados del modo oscuro', () async {
    final repositorio = _RepositorioTema();
    final controller =
        TodoWorkspace.createForTest(stateRepository: repositorio);
    addTearDown(controller.dispose);
    controller.setDarkMode(true);
    await controller.flushPendingChanges();
    final recuperado = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot.fromJson(repositorio.snapshot!.toJson()),
      stateRepository: repositorio,
    );
    addTearDown(recuperado.dispose);
    expect(recuperado.darkMode, isTrue);
    recuperado.setDarkMode(false);
    await recuperado.flushPendingChanges();
    expect(repositorio.snapshot!.darkMode, isFalse);
  });
}

Future<void> _abrir(WidgetTester tester, TodoWorkspace controller) async {
  await tester.pumpWidget(TodoApp(
    key: UniqueKey(),
    launchIntent: AppLaunchIntent.fromArgs([]),
    workspaceLoader: () async => controller,
  ));
  await tester.pumpAndSettle();
}

ThemeData _tema(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first));

class _RepositorioTema implements TodoStateRepository {
  AppStateSnapshot? snapshot;

  @override
  Future<AppStateSnapshot?> load() async => snapshot;

  @override
  Future<void> save(AppStateSnapshot snapshot) async =>
      this.snapshot = snapshot;

  @override
  Future<String?> loadCalendarSession() async => null;

  @override
  Future<void> saveCalendarSession(String encodedSession) async {}

  @override
  Future<void> clearCalendarSession() async {}

  @override
  Future<LocalSyncMetadata> loadSyncMetadata() async =>
      const LocalSyncMetadata();

  @override
  Future<void> saveSyncMetadata(LocalSyncMetadata metadata) async {}
}
