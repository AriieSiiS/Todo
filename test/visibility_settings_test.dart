import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';
import 'package:todo/services/full_backup_service.dart';

class _BackupForVisibilityTest extends FullBackupService {
  @override
  Future<FullBackupOverview> loadOverview() async => const FullBackupOverview();
}

void main() {
  testWidgets('Ajustes permite ocultar Lavandería y conservar su acceso',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(
            body: SettingsPage(
                controller: controller,
                backupService: _BackupForVisibilityTest()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personalizar'));
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
            of: find.byType(AlertDialog), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('visible-tabs-wardrobe')), 300,
        scrollable: scrollable);
    await tester.tap(find.byKey(const ValueKey('visible-tabs-wardrobe')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.byKey(const ValueKey('visible-tab-wardrobe-laundry')));
    await tester
        .tap(find.byKey(const ValueKey('visible-tab-wardrobe-laundry')));
    await tester.pumpAndSettle();
    expect(controller.visibilitySettings.visibleTabs(AppSection.wardrobe),
        isNot(contains('laundry')));
    expect(controller.visibleNavOrder, contains(AppSection.settings));
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  test('las preferencias se conservan y siempre hay acceso a Ajustes', () {
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    controller.setSection(AppSection.wardrobe);
    controller.setSectionVisible(AppSection.wardrobe, false);
    controller.setSectionVisible(AppSection.settings, false);
    controller.setTabVisible(AppSection.wardrobe, 'laundry', false);
    expect(controller.section, isNot(AppSection.wardrobe));
    expect(controller.visibleNavOrder, isNot(contains(AppSection.wardrobe)));
    expect(controller.visibleNavOrder, contains(AppSection.settings));
    for (final tab in AppVisibilitySettings.tabs[AppSection.recipes]!.keys) {
      controller.setTabVisible(AppSection.recipes, tab, false);
    }
    expect(controller.visibilitySettings.visibleTabs(AppSection.recipes),
        hasLength(1));
    final snapshot = AppStateSnapshot.fromJson(
        jsonDecode(controller.exportSnapshot().toPrettyJson()));
    final restored = TodoWorkspace.createForTest(snapshot: snapshot);
    addTearDown(restored.dispose);
    expect(restored.visibilitySettings.visibleTabs(AppSection.wardrobe),
        isNot(contains('laundry')));
    expect(restored.visibleNavOrder, isNot(contains(AppSection.wardrobe)));
    final visible = List<AppSection>.of(restored.visibleNavOrder);
    restored.reorderNavigation(0, visible.length);
    expect(restored.visibleNavOrder.last, visible.first);
    restored.setSectionVisible(AppSection.wardrobe, true);
    expect(restored.navOrder.toSet(), hasLength(AppSection.values.length));
    expect(restored.visibleNavOrder, contains(AppSection.wardrobe));
  });

  testWidgets(
      'ocultar Lavandería mantiene las otras pestañas y permite abrir Maletas',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    controller.setTabVisible(AppSection.wardrobe, 'laundry', false);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: WardrobePage(controller: controller))));
    await tester.pumpAndSettle();
    expect(find.text('Lavandería'), findsNothing);
    await tester.tap(find.text('Maletas'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva maleta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ocultar la pestaña activa de Biblioteca abre Propósitos',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    controller.setTabVisible(AppSection.library, 'library', false);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: LibraryPage(controller: controller))));
    await tester.pumpAndSettle();
    expect(find.text('Propósitos'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 300));
  });
}
