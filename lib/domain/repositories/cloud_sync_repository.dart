import '../models.dart';

abstract class CloudSyncRepository {
  bool get isConfigured;
  bool get isInitialized;
  bool get isAuthenticated;
  String get currentEmail;
  String get lastError;
  String get url;
  String get allowedEmail;
  String get redirectUrl;

  Future<void> initialize();
  Future<bool> signInWithGoogle();
  Future<void> signOut();
  Future<AppStateSnapshot?> fetchSnapshot();
  Future<void> pushSnapshot(AppStateSnapshot snapshot);
}
