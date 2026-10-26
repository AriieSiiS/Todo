import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/domain/repositories/todo_state_repository.dart';

class _FallibleRepository implements TodoStateRepository {
  bool failing = true;
  int saves = 0;

  @override
  Future<void> save(AppStateSnapshot snapshot) async {
    if (failing) throw StateError('disco lleno');
    saves++;
  }

  @override
  Future<AppStateSnapshot?> load() async => null;

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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Un guardado fallido deja un aviso y reintentar lo limpia', () async {
    final repository = _FallibleRepository();
    final controller = TodoWorkspace.createForTest(stateRepository: repository);
    addTearDown(controller.dispose);
    expect(controller.saveError, isEmpty);

    await expectLater(controller.flushPendingChanges(), throwsStateError);
    expect(controller.saveError, contains('disco lleno'));

    repository.failing = false;
    await controller.retrySave();
    expect(controller.saveError, isEmpty);
    expect(repository.saves, 1);
  });
}
