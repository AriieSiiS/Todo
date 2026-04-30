import '../../domain/models.dart';
import '../../domain/repositories/todo_state_repository.dart';
import '../local_store.dart';

class LocalTodoStateRepository implements TodoStateRepository {
  LocalTodoStateRepository(this._store);

  final LocalStore _store;

  @override
  Future<AppStateSnapshot?> load() => _store.load();

  @override
  Future<void> save(AppStateSnapshot snapshot) => _store.save(snapshot);

  @override
  Future<String?> loadCalendarSession() => _store.loadCalendarSession();

  @override
  Future<void> saveCalendarSession(String encodedSession) =>
      _store.saveCalendarSession(encodedSession);

  @override
  Future<void> clearCalendarSession() => _store.clearCalendarSession();
}
