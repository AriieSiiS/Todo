import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';
import 'package:todo/services/steam_service.dart';

class _SteamPrueba extends SteamService {
  final queried = <int>[];
  final links = <String, int>{};
  final results = <int, Map<String, dynamic>>{};
  Completer<void>? gate;
  final failures = <int>{};
  @override
  Future<List<Map<String, dynamic>>> games({bool refresh = false}) async => [
        {'appid': 1, 'name': 'Bruma'},
        {'appid': 2, 'name': 'Bosque'},
        {'appid': 3, 'name': 'Antiguo'},
      ];
  @override
  Future<int?> linkedApp(String itemId, String title,
          List<Map<String, dynamic>> games) async =>
      links[itemId] ??
      games.where((g) => g['name'] == title).firstOrNull?['appid'] as int?;
  @override
  Future<Map<String, dynamic>> binding(String itemId) async =>
      {'appid': links[itemId]};
  @override
  Future<void> link(String itemId, int appId,
      {String? title, String? expectedVersion}) async {
    links[itemId] = appId;
  }

  @override
  Future<Map<String, dynamic>?> savedAchievements(String itemId) async =>
      results[links[itemId]];
  @override
  Future<Map<String, dynamic>> achievements(int appId,
      {bool refresh = false}) async {
    expect(refresh, true);
    queried.add(appId);
    await gate?.future;
    if (failures.contains(appId)) {
      throw const FormatException('Fallo de prueba');
    }
    final result = results[appId] = {
      'total': 4,
      'unlocked': 2,
      'achievements': List.generate(4, (i) => {'unlocked': i < 2}),
    };
    achievementsRevision.value++;
    return result;
  }
}

void main() {
  late _SteamPrueba steam;
  late TodoWorkspace controller;
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    steam = _SteamPrueba();
    final now = DateTime.now();
    LibraryItem game(String id, String title, LibraryItemStatus status) =>
        LibraryItem(
          id: id,
          type: LibraryItemType.game,
          title: title,
          status: status,
          createdAt: now,
          updatedAt: now,
        );
    controller = TodoWorkspace.createForTest(
      steamService: steam,
      snapshot: AppStateSnapshot.fromJson({
        'libraryItems': [
          game('bruma', 'Bruma', LibraryItemStatus.inProgress).toJson(),
          game('bosque', 'Bosque', LibraryItemStatus.inProgress).toJson(),
          game('antiguo', 'Antiguo', LibraryItemStatus.pending).toJson(),
        ]
      }),
    );
    controller.setLibraryTypeView(LibraryItemType.game);
    controller.setLibraryStatusView(LibraryItemStatus.inProgress);
  });
  tearDown(() => controller.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: LibraryPage(controller: controller))));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  testWidgets('actualiza solo los juegos de la búsqueda y el estado actuales',
      (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, 'Bruma');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Actualizar logros de esta vista'));
    await tester.pumpAndSettle();
    expect(steam.queried, [1]);
    expect(steam.links['bruma'], 1);
    expect(find.textContaining('Actualizados: 1'), findsOneWidget);
    expect(find.text('2 / 4 logros'), findsOneWidget);
    expect(find.text('50 % · En curso'), findsOneWidget);
  });

  testWidgets('la actualización individual refresca portadas y Recientes',
      (tester) async {
    steam.links['bruma'] = 1;
    steam.results[1] = {
      'achievements': [
        {'unlocked': true},
        {'unlocked': false},
        {'unlocked': false},
        {'unlocked': false},
      ]
    };
    await open(tester);
    expect(find.text('1 / 4 logros'), findsOneWidget);
    expect(find.text('25 % · En curso'), findsOneWidget);
    await steam.achievements(1, refresh: true);
    await tester.pumpAndSettle();
    expect(find.text('2 / 4 logros'), findsOneWidget);
    expect(find.text('50 % · En curso'), findsOneWidget);
    expect(find.text('1 / 4 logros'), findsNothing);
    steam.results[1] = {
      'achievements': List.generate(4, (_) => {'unlocked': true})
    };
    steam.achievementsRevision.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        find.byKey(const ValueKey('library-all-achievements')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('library-platinum-shine')), findsOneWidget);
    expect(find.text('100 % · En curso'), findsOneWidget);
    steam.results[1] = {
      'achievements': [
        {'unlocked': true},
        {'unlocked': false}
      ]
    };
    steam.achievementsRevision.value++;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-platinum-shine')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('solo los elementos en curso muestran porcentaje en Recientes',
      (tester) async {
    final now = DateTime.now();
    final reading = LibraryReading(
        progress: .39,
        observedAt: 1,
        page: '39',
        position: '',
        documents: [],
        cursors: {},
        quotes: []);
    for (final status in [
      LibraryItemStatus.pending,
      LibraryItemStatus.inProgress
    ]) {
      final book = controller.createLibraryItem(
          type: LibraryItemType.book,
          title: 'Lectura ${status.name}',
          status: status);
      controller
          .updateLibraryItem(book.copyWith(reading: reading, updatedAt: now));
    }
    final pendingGame =
        controller.libraryItems.firstWhere((i) => i.id == 'antiguo');
    controller.updateLibraryItem(pendingGame.copyWith(updatedAt: now));
    steam.links['antiguo'] = 3;
    steam.results[3] = {
      'achievements': [
        {'unlocked': true}
      ]
    };
    await open(tester);
    expect(find.text('39 % · En curso'), findsOneWidget);
    expect(find.textContaining('39 % · Pendiente'), findsNothing);
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('library-recent-meta-antiguo')))
            .data,
        'Pendiente');
  });

  testWidgets('evita dobles consultas y continúa tras un error',
      (tester) async {
    steam.gate = Completer<void>();
    steam.failures.add(2);
    await open(tester);
    final button = find.byKey(const ValueKey('library-refresh-games'));
    await tester.tap(button);
    await tester.pump();
    expect(tester.widget<IconButton>(button).onPressed, isNull);
    steam.gate!.complete();
    await tester.pumpAndSettle();
    expect(steam.queried.toSet(), {1, 2});
    expect(steam.queried.length, 2);
    expect(find.text('Actualizados: 1 · Con errores: 1'), findsOneWidget);
    expect(tester.widget<IconButton>(button).onPressed, isNotNull);
  });

  testWidgets('el botón aparece solo en Juegos', (tester) async {
    controller.setLibraryTypeView(LibraryItemType.book);
    await open(tester);
    expect(find.byKey(const ValueKey('library-refresh-games')), findsNothing);
  });
}
