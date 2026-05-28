import '../models.dart';

abstract class TodoStateRepository {
  Future<AppStateSnapshot?> load();
  Future<void> save(AppStateSnapshot snapshot);
  Future<String?> loadCalendarSession();
  Future<void> saveCalendarSession(String encodedSession);
  Future<void> clearCalendarSession();
  Future<LocalSyncMetadata> loadSyncMetadata();
  Future<void> saveSyncMetadata(LocalSyncMetadata metadata);
}
