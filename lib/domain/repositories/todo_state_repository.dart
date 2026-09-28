import '../models.dart';

abstract class TodoStateRepository {
  Future<AppStateSnapshot?> load();
  // Devuelve null si no hay estado o no cambió desde la última consulta periódica.
  Future<AppStateSnapshot?> loadIfChanged();
  Future<void> save(AppStateSnapshot snapshot);
  Future<String?> loadCalendarSession();
  Future<void> saveCalendarSession(String encodedSession);
  Future<void> clearCalendarSession();
  Future<LocalSyncMetadata> loadSyncMetadata();
  Future<void> saveSyncMetadata(LocalSyncMetadata metadata);
}
