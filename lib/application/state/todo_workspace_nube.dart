part of 'todo_workspace.dart';

extension TodoWorkspaceNube on TodoWorkspace {
  Future<bool> connectCloud() async {
    if (!cloudConfigured) {
      return false;
    }
    _cloudBusy = true;
    _notifyChanged();
    try {
      final launched = await _cloudService.signInWithGoogle();
      if (launched && _cloudService.isAuthenticated) {
        await syncWithCloud();
      }
      return launched;
    } catch (_) {
      return false;
    } finally {
      _cloudBusy = false;
      _notifyChanged();
    }
  }

  Future<void> disconnectCloud() async {
    _cloudBusy = true;
    _notifyChanged();
    try {
      await _cloudService.signOut();
      _lastCloudSyncAt = null;
    } finally {
      _cloudBusy = false;
      _notifyChanged();
    }
  }

  Future<void> syncWithCloud() async {
    if (!cloudConfigured) {
      return;
    }
    _cloudBusy = true;
    _notifyChanged();
    try {
      final local = _buildSnapshot();
      final remote = await _cloudService.fetchEnvelope();
      if (_shouldCreateSyncConflict(remote)) {
        _syncConflict = SyncConflict(
          local: local,
          remote: remote!,
          expectedRevision: _syncMetadata.lastSeenCloudRevision,
        );
      } else if (_shouldPullRemoteEnvelope(local: local, remote: remote)) {
        _applySnapshot(remote!.snapshot);
        await _store.save(remote.snapshot);
        await _markCloudEnvelopeSeen(remote, pendingLocalChanges: false);
        _loadedFromPersistence = true;
      } else {
        final result = await _cloudService.pushEnvelope(
          snapshot: local,
          expectedRevision: _syncMetadata.lastSeenCloudRevision,
        );
        await _handleCloudPushResult(result);
        if (result.hasConflict) {
          return;
        }
      }
      await _knowledgeService.ensureLibraryRoots(_libraryItems);
      if (_cloudService is SupabaseCloudSyncRepository) {
        await _cloudService.syncKnowledgeBackup(_knowledgeService);
      }
      _lastCloudSyncAt = DateTime.now();
    } catch (_) {
      // Keep local state intact when cloud sync fails.
    } finally {
      _cloudBusy = false;
      _notifyChanged();
    }
  }

  bool _shouldCreateSyncConflict(CloudSnapshotEnvelope? remote) {
    if (remote == null) {
      return false;
    }
    if (!_syncMetadata.pendingLocalChanges) {
      return false;
    }
    if (remote.revision <= _syncMetadata.lastSeenCloudRevision) {
      return false;
    }
    return true;
  }

  bool _shouldPullRemoteEnvelope({
    required AppStateSnapshot local,
    required CloudSnapshotEnvelope? remote,
  }) {
    if (remote == null) {
      return false;
    }
    // Un snapshot local pendiente nunca debe sustituirse automáticamente.
    // Si la nube avanzó, el push generará un conflicto revisable y conservará
    // los datos de este dispositivo hasta que el usuario decida.
    if (_syncMetadata.pendingLocalChanges) {
      return false;
    }
    if (remote.revision > _syncMetadata.lastSeenCloudRevision) {
      return true;
    }
    return _shouldPullRemoteSnapshot(local: local, remote: remote.snapshot);
  }

  bool _shouldPullRemoteSnapshot({
    required AppStateSnapshot local,
    required AppStateSnapshot? remote,
  }) {
    if (remote == null) {
      return false;
    }
    if (remote.resolvedUpdatedAt.isAfter(local.resolvedUpdatedAt)) {
      return true;
    }

    final remoteOwner = remote.lastModifiedBy.trim().toLowerCase();
    final localOwner = local.lastModifiedBy.trim().toLowerCase();
    final currentOwner = _cloudService.currentEmail.trim().toLowerCase();
    final localLooksUnsynced =
        localOwner.isEmpty || localOwner == 'local-device';
    final remoteBelongsToSignedUser =
        currentOwner.isNotEmpty && remoteOwner == currentOwner;

    if (localLooksUnsynced && remoteBelongsToSignedUser) {
      return true;
    }

    final remoteHasUserState =
        remoteOwner.isNotEmpty && remoteOwner != 'local-device';
    final localIsSeededDemo =
        local.tasks.any((task) => task.id == 'task-reset') ||
            local.projects.any((project) => project.id == 'project-reset') ||
            local.notes.any((note) => note.id == 'note-1');

    if (localLooksUnsynced && localIsSeededDemo && remoteHasUserState) {
      return true;
    }

    return false;
  }

  Future<void> resolveSyncConflictWithRemote() async {
    final conflict = _syncConflict;
    if (conflict == null) {
      return;
    }
    _applySnapshot(conflict.remote.snapshot);
    await _store.save(conflict.remote.snapshot);
    await _markCloudEnvelopeSeen(conflict.remote, pendingLocalChanges: false);
    _syncConflict = null;
    _lastCloudSyncAt = DateTime.now();
    _notifyChanged();
  }

  Future<void> resolveSyncConflictKeepingLocal() async {
    final conflict = _syncConflict;
    if (conflict == null) {
      return;
    }
    _cloudBusy = true;
    _notifyChanged();
    try {
      final result = await _cloudService.pushEnvelope(
        snapshot: conflict.local,
        expectedRevision: conflict.remote.revision,
      );
      await _handleCloudPushResult(result);
      if (!result.hasConflict) {
        _syncConflict = null;
        _lastCloudSyncAt = DateTime.now();
      }
    } finally {
      _cloudBusy = false;
      _notifyChanged();
    }
  }

  Future<void> _handleCloudPushResult(
    CloudPushResult result,
  ) async {
    if (result.hasConflict && result.conflict != null) {
      _syncConflict = result.conflict;
      await _store.saveSyncMetadata(
        _syncMetadata.copyWith(pendingLocalChanges: true),
      );
      return;
    }
    _syncConflict = null;
    if (result.envelope != null) {
      await _markCloudEnvelopeSeen(
        result.envelope!,
        pendingLocalChanges: false,
      );
      return;
    }
    if (result.pushed) {
      await _store.saveSyncMetadata(
        _syncMetadata.copyWith(pendingLocalChanges: false),
      );
    }
  }

  Future<void> _markCloudEnvelopeSeen(
    CloudSnapshotEnvelope envelope, {
    required bool pendingLocalChanges,
  }) async {
    _syncMetadata = _syncMetadata.copyWith(
      deviceId: _syncMetadata.deviceId.isNotEmpty
          ? _syncMetadata.deviceId
          : _cloudService.currentDeviceId,
      lastSeenCloudRevision: envelope.revision,
      pendingLocalChanges: pendingLocalChanges,
      lastCloudHash: envelope.stateHash,
    );
    await _store.saveSyncMetadata(_syncMetadata);
  }
}
