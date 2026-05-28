import 'app_state_snapshot.dart';

enum CloudPushStatus { pushed, conflict, skipped }

class CloudSnapshotEnvelope {
  const CloudSnapshotEnvelope({
    required this.snapshot,
    required this.revision,
    required this.updatedAt,
    required this.updatedByDevice,
    required this.updatedByPlatform,
    required this.stateHash,
  });

  final AppStateSnapshot snapshot;
  final int revision;
  final DateTime updatedAt;
  final String updatedByDevice;
  final String updatedByPlatform;
  final String stateHash;
}

class CloudPushResult {
  const CloudPushResult({
    required this.status,
    this.envelope,
    this.conflict,
  });

  final CloudPushStatus status;
  final CloudSnapshotEnvelope? envelope;
  final SyncConflict? conflict;

  bool get pushed => status == CloudPushStatus.pushed;
  bool get hasConflict => status == CloudPushStatus.conflict;
}

class SyncConflict {
  const SyncConflict({
    required this.local,
    required this.remote,
    required this.expectedRevision,
  });

  final AppStateSnapshot local;
  final CloudSnapshotEnvelope remote;
  final int expectedRevision;
}

class LocalSyncMetadata {
  const LocalSyncMetadata({
    this.deviceId = '',
    this.lastSeenCloudRevision = 0,
    this.pendingLocalChanges = false,
    this.lastCloudHash = '',
  });

  final String deviceId;
  final int lastSeenCloudRevision;
  final bool pendingLocalChanges;
  final String lastCloudHash;

  LocalSyncMetadata copyWith({
    String? deviceId,
    int? lastSeenCloudRevision,
    bool? pendingLocalChanges,
    String? lastCloudHash,
  }) {
    return LocalSyncMetadata(
      deviceId: deviceId ?? this.deviceId,
      lastSeenCloudRevision:
          lastSeenCloudRevision ?? this.lastSeenCloudRevision,
      pendingLocalChanges: pendingLocalChanges ?? this.pendingLocalChanges,
      lastCloudHash: lastCloudHash ?? this.lastCloudHash,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'deviceId': deviceId,
      'lastSeenCloudRevision': lastSeenCloudRevision,
      'pendingLocalChanges': pendingLocalChanges,
      'lastCloudHash': lastCloudHash,
    };
  }

  factory LocalSyncMetadata.fromJson(Map<String, dynamic> json) {
    return LocalSyncMetadata(
      deviceId: json['deviceId'] as String? ?? '',
      lastSeenCloudRevision:
          (json['lastSeenCloudRevision'] as num?)?.toInt() ?? 0,
      pendingLocalChanges: json['pendingLocalChanges'] as bool? ?? false,
      lastCloudHash: json['lastCloudHash'] as String? ?? '',
    );
  }
}
