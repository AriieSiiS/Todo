import 'package:flutter_test/flutter_test.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';

void main() {
  test('library defaults to completed when no view was saved', () {
    final controller = TodoWorkspace.createForTest();

    expect(controller.libraryStatusView, LibraryItemStatus.completed);
  });

  test('completed library goals and library items stay linked', () {
    final controller = TodoWorkspace.createForTest();
    final year = DateTime.now().year;

    final goal = controller.createLibraryGoal(
      type: LibraryItemType.movieSeries,
      title: 'Kill Bill: Vol. 1',
      targetYear: year,
      creatorOrDirector: 'Quentin Tarantino',
      genre: 'Accion',
    );

    final existingItem = controller.createLibraryItem(
      type: LibraryItemType.movieSeries,
      title: 'Kill Bill: Vol 1',
      completedDate: DateTime(year, 5, 7),
      mediaType: LibraryMediaType.movie,
    );

    final item = controller.libraryItems.singleWhere(
      (item) => item.id == existingItem.id,
    );
    expect(controller.libraryItems.length, 1);

    final linkedGoal = controller.libraryGoals.singleWhere(
      (goal) => goal.id == item.linkedGoalId,
    );

    expect(linkedGoal.isCompleted, isTrue);
    expect(linkedGoal.linkedLibraryItemId, item.id);

    controller.updateLibraryItem(
      item.copyWith(
        title: 'Kill Bill: Vol. 1 editada',
        creatorOrDirector: 'Q. Tarantino',
        genre: 'Accion, thriller',
      ),
    );

    final goalAfterItemEdit = controller.libraryGoals.singleWhere(
      (goal) => goal.id == linkedGoal.id,
    );
    expect(goalAfterItemEdit.title, 'Kill Bill: Vol. 1 editada');
    expect(goalAfterItemEdit.creatorOrDirector, 'Q. Tarantino');
    expect(goalAfterItemEdit.genre, 'Accion, thriller');

    controller.updateLibraryGoal(
      goalAfterItemEdit.copyWith(
        title: 'Kill Bill: Vol. 1 final',
        country: 'Estados Unidos',
      ),
    );

    final itemAfterGoalEdit = controller.libraryItems.singleWhere(
      (item) => item.id == goalAfterItemEdit.linkedLibraryItemId,
    );
    expect(itemAfterGoalEdit.title, 'Kill Bill: Vol. 1 final');
    expect(itemAfterGoalEdit.country, 'Estados Unidos');
    expect(itemAfterGoalEdit.linkedGoalId, goalAfterItemEdit.id);

    controller.toggleLibraryGoalCompleted(goalAfterItemEdit.id);

    final reopenedGoal = controller.libraryGoals.singleWhere(
      (goal) => goal.id == goalAfterItemEdit.id,
    );
    expect(reopenedGoal.isCompleted, isFalse);
    final reopenedItem = controller.libraryItems.singleWhere(
      (item) => item.linkedGoalId == goal.id,
    );
    expect(reopenedGoal.linkedLibraryItemId, reopenedItem.id);
    expect(reopenedItem.status, LibraryItemStatus.pending);
    expect(reopenedItem.completedDate, isNull);
  });

  test('deleting a goal keeps its linked library item', () {
    final controller = TodoWorkspace.createForTest();
    final year = DateTime.now().year;

    final goal = controller.createLibraryGoal(
      type: LibraryItemType.movieSeries,
      title: 'Reservoir Dogs',
      targetYear: year,
    );

    controller.toggleLibraryGoalCompleted(goal.id);

    expect(controller.libraryItems, hasLength(1));

    controller.deleteLibraryGoal(goal.id);

    expect(controller.libraryGoals, isEmpty);
    expect(controller.libraryItems, hasLength(1));
    expect(controller.libraryItems.single.linkedGoalId, isNull);
  });

  test('creating a completed item completes a matching pending goal', () {
    final controller = TodoWorkspace.createForTest();
    final year = DateTime.now().year;

    final goal = controller.createLibraryGoal(
      type: LibraryItemType.game,
      title: 'Prey',
      targetYear: year,
      platform: 'PC',
    );

    final item = controller.createLibraryItem(
      type: LibraryItemType.game,
      title: 'Prey',
      completedDate: DateTime(year, 5, 6),
      platform: 'PC',
      genre: 'Shooter',
    );

    final linkedGoal = controller.libraryGoals.singleWhere(
      (goal) => goal.id == item.linkedGoalId,
    );
    final linkedItem = controller.libraryItems.singleWhere(
      (item) => item.id == linkedGoal.linkedLibraryItemId,
    );

    expect(linkedGoal.id, goal.id);
    expect(linkedGoal.isCompleted, isTrue);
    expect(linkedGoal.genre, 'Shooter');
    expect(linkedItem.linkedGoalId, goal.id);
  });

  test('library status transitions normalize the completed date', () {
    final controller = TodoWorkspace.createForTest();
    final item = controller.createLibraryItem(
      type: LibraryItemType.book,
      title: 'Piranesi',
      status: LibraryItemStatus.pending,
    );

    expect(item.completedDate, isNull);
    controller.updateLibraryItemStatus(
      item.id,
      LibraryItemStatus.inProgress,
    );
    expect(controller.libraryItems.single.status, LibraryItemStatus.inProgress);

    controller.updateLibraryItemStatus(
      item.id,
      LibraryItemStatus.completed,
      completedDate: DateTime(2026, 7, 22),
    );
    expect(controller.libraryItems.single.status, LibraryItemStatus.completed);
    expect(controller.libraryItems.single.completedDate, DateTime(2026, 7, 22));

    controller.updateLibraryItemStatus(item.id, LibraryItemStatus.pending);
    expect(controller.libraryItems.single.completedDate, isNull);
  });

  test('deleting a linked item recreates it pending and preserves the goal',
      () {
    final controller = TodoWorkspace.createForTest();
    final goal = controller.createLibraryGoal(
      type: LibraryItemType.game,
      title: 'Control',
      targetYear: 2026,
    );
    final original = controller.libraryItems.single;

    controller.deleteLibraryItem(original.id);

    final keptGoal = controller.libraryGoals.single;
    final replacement = controller.libraryItems.single;
    expect(keptGoal.id, goal.id);
    expect(keptGoal.isCompleted, isFalse);
    expect(keptGoal.linkedLibraryItemId, replacement.id);
    expect(replacement.id, isNot(original.id));
    expect(replacement.status, LibraryItemStatus.pending);
    expect(replacement.linkedGoalId, goal.id);
  });

  test('legacy library items default to completed', () {
    final item = LibraryItem.fromJson(<String, dynamic>{
      'id': 'legacy',
      'type': 'book',
      'title': 'Circe',
      'completedDate': '2026-05-09T00:00:00.000',
      'createdAt': '2026-05-09T00:00:00.000',
      'updatedAt': '2026-05-09T00:00:00.000',
    });

    expect(item.status, LibraryItemStatus.completed);
    expect(item.yearGroup, 2026);
  });

  test('schema 2 migration links pending goals once without losing history',
      () {
    final completed = LibraryItem.fromJson(<String, dynamic>{
      'id': 'completed-circe',
      'type': 'book',
      'title': 'Circe',
      'completedDate': '2026-05-09T00:00:00.000',
      'createdAt': '2026-05-09T00:00:00.000',
      'updatedAt': '2026-05-09T00:00:00.000',
    });
    final pendingGoal = LibraryGoal(
      id: 'goal-piranesi',
      type: LibraryItemType.book,
      title: 'Piranesi',
      targetYear: 2026,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final migrated = TodoWorkspace.createForTest(
      snapshot: _snapshot(
        schemaVersion: 2,
        items: [completed],
        goals: [pendingGoal],
      ),
    );

    expect(migrated.libraryItems, hasLength(2));
    expect(
      migrated.libraryItems
          .where((item) => item.status == LibraryItemStatus.completed),
      hasLength(1),
    );
    final pending = migrated.libraryItems.singleWhere(
      (item) => item.status == LibraryItemStatus.pending,
    );
    expect(migrated.libraryGoals.single.linkedLibraryItemId, pending.id);

    final reloaded = TodoWorkspace.createForTest(
      snapshot: _snapshot(
        schemaVersion: 3,
        items: migrated.libraryItems,
        goals: migrated.libraryGoals,
      ),
    );
    expect(reloaded.libraryItems, hasLength(2));
    expect(reloaded.libraryGoals.single.linkedLibraryItemId, pending.id);
  });
}

AppStateSnapshot _snapshot({
  required int schemaVersion,
  required List<LibraryItem> items,
  required List<LibraryGoal> goals,
}) {
  return AppStateSnapshot(
    tasks: const [],
    categories: const [],
    projects: const [],
    notes: const [],
    libraryItems: items,
    libraryGoals: goals,
    daySettings: const DaySettings(),
    notificationSettings: const DeviceNotificationSettings(),
    calendarSettings: const CalendarIntegrationSettings(),
    section: AppSection.library,
    todaySort: TodaySort.manual,
    schemaVersion: schemaVersion,
  );
}
