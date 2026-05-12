import '../domain/models.dart';
import 'local_store_file_backed.dart';

abstract class LocalStore {
  factory LocalStore() => createLocalStore();

  Future<AppStateSnapshot?> load();
  Future<void> save(AppStateSnapshot snapshot);
  Future<String?> loadCalendarSession();
  Future<void> saveCalendarSession(String encodedSession);
  Future<void> clearCalendarSession();
}
