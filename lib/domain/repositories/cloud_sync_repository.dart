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
  String get currentDeviceId;

  Future<void> initialize();
  Future<bool> signInWithGoogle();
  Future<void> signOut();
  Future<CloudSnapshotEnvelope?> fetchEnvelope();
  Future<CloudPushResult> pushEnvelope({
    required AppStateSnapshot snapshot,
    required int expectedRevision,
  });
}
