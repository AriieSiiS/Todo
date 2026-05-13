import 'package:flutter_test/flutter_test.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';

void main() {
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
    expect(reopenedGoal.linkedLibraryItemId, isNull);
    expect(
      controller.libraryItems.where((item) => item.linkedGoalId == goal.id),
      isEmpty,
    );
  });

  test('deleting a goal deletes its linked completed item', () {
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
    expect(controller.libraryItems, isEmpty);
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
}
