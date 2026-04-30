import '../../domain/models.dart';
import '../../domain/repositories/cloud_sync_repository.dart';
import '../../services/supabase_cloud_service.dart';

class SupabaseCloudSyncRepository implements CloudSyncRepository {
  SupabaseCloudSyncRepository(this._service);

  final SupabaseCloudService _service;

  @override
  bool get isConfigured => _service.isConfigured;

  @override
  bool get isInitialized => _service.isInitialized;

  @override
  bool get isAuthenticated => _service.isAuthenticated;

  @override
  String get currentEmail => _service.currentEmail;

  @override
  String get lastError => _service.lastError;

  @override
  String get url => _service.url;

  @override
  String get allowedEmail => _service.allowedEmail;

  @override
  String get redirectUrl => _service.redirectUrl;

  @override
  Future<void> initialize() => _service.initialize();

  @override
  Future<bool> signInWithGoogle() => _service.signInWithGoogle();

  @override
  Future<void> signOut() => _service.signOut();

  @override
  Future<AppStateSnapshot?> fetchSnapshot() => _service.fetchSnapshot();

  @override
  Future<void> pushSnapshot(AppStateSnapshot snapshot) =>
      _service.pushSnapshot(snapshot);
}
