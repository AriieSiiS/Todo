import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';
import 'package:todo/services/steam_service.dart';

/// Devuelve logros guardados sin leer disco ni red.
class _SteamConLogros extends SteamService {
  _SteamConLogros(this.logros);

  final Map<String, (int, int)> logros;

  @override
  Future<Map<String, dynamic>?> savedAchievements(String itemId) async {
    final valor = logros[itemId];
    if (valor == null) return null;
    return {
      'achievements': [
        for (var i = 0; i < valor.$2; i++) {'unlocked': i < valor.$1},
      ],
    };
  }
}

void main() {
  testWidgets('Juegos filtra y ordena por logros guardados en local',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final ahora = DateTime(2026, 10, 24);
    LibraryItem juego(String id) => LibraryItem(
          id: id,
          type: LibraryItemType.game,
          title: 'Juego $id',
          status: LibraryItemStatus.completed,
          completedDate: ahora,
          createdAt: ahora,
          updatedAt: ahora,
        );
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot.fromJson({
        'libraryItems': [
          juego('uno').toJson(),
          juego('dos').toJson(),
          juego('tres').toJson(),
        ],
      }),
      steamService: _SteamConLogros({
        'uno': (10, 40),
        'dos': (20, 20),
      }),
    );
    addTearDown(controller.dispose);
    controller.setLibraryTypeView(LibraryItemType.game);
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: LibraryPage(controller: controller))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todo'));
    await tester.pumpAndSettle();

    Finder tarjeta(String id) =>
        find.byKey(ValueKey('library-cover-card-$id'));
    expect(tarjeta('uno'), findsOneWidget);
    expect(tarjeta('dos'), findsOneWidget);
    expect(tarjeta('tres'), findsOneWidget);
    expect(find.byKey(const ValueKey('library-all-achievements')),
        findsOneWidget);

    await tester.tap(find.byTooltip('Filtrar por logros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('100 % de logros').last);
    await tester.pumpAndSettle();
    expect(tarjeta('dos'), findsOneWidget);
    expect(tarjeta('uno'), findsNothing);
    expect(tarjeta('tres'), findsNothing);

    await tester.tap(find.byTooltip('Filtrar por logros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logros').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ordenar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('% de logros').last);
    await tester.pumpAndSettle();
    final orden = [
      for (final id in ['uno', 'dos', 'tres'])
        tester.getTopLeft(tarjeta(id)).dx,
    ];
    // De mayor a menor: dos (100 %), uno (25 %), tres (sin datos).
    expect(orden[1], lessThan(orden[0]));
    expect(orden[0], lessThan(orden[2]));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
  });
}
