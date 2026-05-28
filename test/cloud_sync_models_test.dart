import 'package:flutter_test/flutter_test.dart';
import 'package:todo/domain/models.dart';

void main() {
  test('local sync metadata roundtrips through json', () {
    const metadata = LocalSyncMetadata(
      deviceId: 'device-1',
      lastSeenCloudRevision: 7,
      pendingLocalChanges: true,
      lastCloudHash: 'hash-1',
    );

    final decoded = LocalSyncMetadata.fromJson(metadata.toJson());

    expect(decoded.deviceId, 'device-1');
    expect(decoded.lastSeenCloudRevision, 7);
    expect(decoded.pendingLocalChanges, isTrue);
    expect(decoded.lastCloudHash, 'hash-1');
  });

  test('cloud push result exposes conflict state', () {
    final snapshot = AppStateSnapshot(
      tasks: const [],
      categories: const [],
      projects: const [],
      notes: const [],
      daySettings: const DaySettings(),
      notificationSettings: const DeviceNotificationSettings(),
      calendarSettings: const CalendarIntegrationSettings(),
      section: AppSection.today,
      todaySort: TodaySort.manual,
      updatedAt: DateTime.utc(2026, 5, 13, 8),
    );
    final remote = CloudSnapshotEnvelope(
      snapshot: snapshot,
      revision: 3,
      updatedAt: DateTime.utc(2026, 5, 13, 9),
      updatedByDevice: 'android',
      updatedByPlatform: 'android',
      stateHash: 'remote-hash',
    );
    final result = CloudPushResult(
      status: CloudPushStatus.conflict,
      envelope: remote,
      conflict: SyncConflict(
        local: snapshot,
        remote: remote,
        expectedRevision: 2,
      ),
    );

    expect(result.hasConflict, isTrue);
    expect(result.pushed, isFalse);
    expect(result.conflict?.expectedRevision, 2);
    expect(result.envelope?.revision, 3);
  });
}
