import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../domain/models.dart';
import 'desktop_oauth_bridge_stub.dart'
    if (dart.library.io) 'desktop_oauth_bridge_io.dart';

class SupabaseCloudService {
  SupabaseCloudService();

  static bool _sdkInitialized = false;
  static const String _deviceIdKey = 'todo.cloud.device_id.v1';
  String _lastError = '';
  String _deviceId = '';

  String get lastError => _lastError;
  bool get isConfigured => SupabaseConfig.isConfigured;
  bool get isInitialized => _sdkInitialized;
  String get url => SupabaseConfig.url;
  String get allowedEmail => SupabaseConfig.allowedEmail;
  String get redirectUrl => SupabaseConfig.redirectUrl;
  String get currentDeviceId => _deviceId;
  bool get isAuthenticated =>
      _sdkInitialized && Supabase.instance.client.auth.currentSession != null;
  String get currentEmail {
    if (!_sdkInitialized) {
      return '';
    }
    return Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  Future<void> initialize() async {
    await SupabaseConfig.load();
    await _ensureDeviceId();
    if (!isConfigured || _sdkInitialized) {
      return;
    }
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
      );
      _sdkInitialized = true;
      _lastError = '';
      await _enforceAllowedEmail();
    } catch (error) {
      _lastError = 'No se pudo iniciar Supabase. ${_cleanError(error)}';
      rethrow;
    }
  }

  Future<bool> signInWithGoogle() async {
    if (!isConfigured) {
      _lastError = 'Falta la configuración de Supabase.';
      return false;
    }
    try {
      await initialize();
    } catch (_) {
      return false;
    }

    try {
      final launched = await _signInWithGoogleForPlatform();
      if (!launched && _lastError.isEmpty) {
        _lastError = 'No se pudo abrir el acceso de Google.';
      }
      return launched;
    } catch (error) {
      _lastError =
          'No se pudo iniciar el acceso en Windows. ${_cleanError(error)}';
      return false;
    }
  }

  Future<bool> _signInWithGoogleForPlatform() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: SupabaseConfig.hasExplicitRedirectUrl
            ? redirectUrl
            : 'todo://login-callback',
      );
      if (!launched) {
        _lastError = 'No se pudo abrir Google en el móvil.';
      }
      return launched;
    }

    return signInWithDesktopGoogleOAuth(
      redirectUrl:
          redirectUrl.isNotEmpty ? redirectUrl : 'http://localhost:3000/',
      setError: (message) {
        _lastError = message;
      },
    );
  }

  Future<void> signOut() async {
    if (!_sdkInitialized) {
      return;
    }
    try {
      await Supabase.instance.client.auth.signOut();
      _lastError = '';
    } catch (error) {
      _lastError = 'No se pudo cerrar la sesión. ${_cleanError(error)}';
      rethrow;
    }
  }

  Future<CloudSnapshotEnvelope?> fetchEnvelope() async {
    try {
      await initialize();
      await _enforceAllowedEmail();
      if (!isAuthenticated || currentEmail.isEmpty) {
        return null;
      }

      final response = await Supabase.instance.client
          .from('todo_app_states')
          .select(
            'state, revision, updated_at, updated_by_device, updated_by_platform, state_hash',
          )
          .eq('owner_email', currentEmail)
          .maybeSingle();
      if (response == null) {
        _lastError = '';
        return null;
      }

      final rawState = response['state'];
      if (rawState is! Map<String, dynamic>) {
        _lastError = '';
        return null;
      }
      _lastError = '';
      return _envelopeFromRow(response);
    } catch (error) {
      _lastError = 'No se pudo leer la nube. ${_cleanError(error)}';
      rethrow;
    }
  }

  Future<CloudPushResult> pushEnvelope({
    required AppStateSnapshot snapshot,
    required int expectedRevision,
  }) async {
    try {
      await initialize();
      await _enforceAllowedEmail();
      if (!isAuthenticated || currentEmail.isEmpty) {
        return const CloudPushResult(status: CloudPushStatus.skipped);
      }

      final hash = _stateHash(snapshot);
      try {
        final response = await Supabase.instance.client.rpc(
          'todo_push_state',
          params: <String, dynamic>{
            'p_owner_email': currentEmail,
            'p_expected_revision': expectedRevision,
            'p_schema_version': snapshot.schemaVersion,
            'p_state': snapshot.toJson(),
            'p_updated_by_device': _deviceId,
            'p_updated_by_platform': _platformName,
            'p_state_hash': hash,
          },
        );
        final data = _rpcMap(response);
        final status = data['status'] as String? ?? 'pushed';
        final envelope = _envelopeFromRpc(data);
        _lastError = '';
        if (status == 'conflict' && envelope != null) {
          return CloudPushResult(
            status: CloudPushStatus.conflict,
            conflict: SyncConflict(
              local: snapshot,
              remote: envelope,
              expectedRevision: expectedRevision,
            ),
            envelope: envelope,
          );
        }
        return CloudPushResult(
          status: CloudPushStatus.pushed,
          envelope: envelope,
        );
      } on PostgrestException catch (error) {
        if (!_looksLikeMissingRpc(error)) {
          rethrow;
        }
        return _legacyCompareAndSwap(snapshot, expectedRevision);
      }
    } catch (error) {
      _lastError = 'No se pudo guardar en la nube. ${_cleanError(error)}';
      rethrow;
    }
  }

  Future<CloudPushResult> _legacyCompareAndSwap(
    AppStateSnapshot snapshot,
    int expectedRevision,
  ) async {
    final remote = await fetchEnvelope();
    if (remote != null &&
        expectedRevision > 0 &&
        remote.revision != expectedRevision) {
      return CloudPushResult(
        status: CloudPushStatus.conflict,
        envelope: remote,
        conflict: SyncConflict(
          local: snapshot,
          remote: remote,
          expectedRevision: expectedRevision,
        ),
      );
    }
    final nextRevision = (remote?.revision ?? 0) + 1;
    final hash = _stateHash(snapshot);
    await Supabase.instance.client.from('todo_app_states').upsert(
      <String, dynamic>{
        'owner_email': currentEmail,
        'schema_version': snapshot.schemaVersion,
        'state': snapshot.toJson(),
        'updated_at': snapshot.resolvedUpdatedAt.toUtc().toIso8601String(),
        'revision': nextRevision,
        'updated_by_device': _deviceId,
        'updated_by_platform': _platformName,
        'state_hash': hash,
      },
      onConflict: 'owner_email',
    );
    return CloudPushResult(
      status: CloudPushStatus.pushed,
      envelope: CloudSnapshotEnvelope(
        snapshot: snapshot,
        revision: nextRevision,
        updatedAt: snapshot.resolvedUpdatedAt,
        updatedByDevice: _deviceId,
        updatedByPlatform: _platformName,
        stateHash: hash,
      ),
    );
  }

  CloudSnapshotEnvelope? _envelopeFromRpc(Map<String, dynamic> data) {
    final rawState = data['state'];
    if (rawState is! Map) {
      return null;
    }
    return CloudSnapshotEnvelope(
      snapshot: AppStateSnapshot.fromJson(rawState.cast<String, dynamic>()),
      revision: (data['revision'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? '') ??
          DateTime.now(),
      updatedByDevice: data['updated_by_device'] as String? ?? '',
      updatedByPlatform: data['updated_by_platform'] as String? ?? '',
      stateHash: data['state_hash'] as String? ?? '',
    );
  }

  CloudSnapshotEnvelope _envelopeFromRow(Map<String, dynamic> row) {
    final rawState = row['state'] as Map<String, dynamic>;
    return CloudSnapshotEnvelope(
      snapshot: AppStateSnapshot.fromJson(rawState),
      revision: (row['revision'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
          DateTime.now(),
      updatedByDevice: row['updated_by_device'] as String? ?? '',
      updatedByPlatform: row['updated_by_platform'] as String? ?? '',
      stateHash: row['state_hash'] as String? ??
          _stateHash(
            AppStateSnapshot.fromJson(rawState),
          ),
    );
  }

  Map<String, dynamic> _rpcMap(Object? response) {
    if (response is Map<String, dynamic>) {
      return response;
    }
    if (response is Map) {
      return response.cast<String, dynamic>();
    }
    if (response is List && response.isNotEmpty && response.first is Map) {
      return (response.first as Map).cast<String, dynamic>();
    }
    return const <String, dynamic>{};
  }

  bool _looksLikeMissingRpc(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('todo_push_state') ||
        message.contains('function') ||
        message.contains('schema cache');
  }

  String _stateHash(AppStateSnapshot snapshot) {
    return sha256.convert(utf8.encode(snapshot.toEncodedJson())).toString();
  }

  Future<void> _ensureDeviceId() async {
    if (_deviceId.isNotEmpty) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      _deviceId = existing;
      return;
    }
    _deviceId =
        'device-${DateTime.now().microsecondsSinceEpoch}-${Platform.operatingSystem}';
    await preferences.setString(_deviceIdKey, _deviceId);
  }

  String get _platformName {
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isWindows) {
      return 'windows';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    if (Platform.isMacOS) {
      return 'macos';
    }
    if (Platform.isLinux) {
      return 'linux';
    }
    return Platform.operatingSystem;
  }

  String _cleanError(Object error) {
    final text = error.toString().trim();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    return text;
  }

  Future<void> _enforceAllowedEmail() async {
    if (!isConfigured || !_sdkInitialized || !SupabaseConfig.hasAllowedEmail) {
      return;
    }

    final email = currentEmail;
    if (email.isEmpty) {
      return;
    }
    if (email.toLowerCase() == SupabaseConfig.allowedEmail.toLowerCase()) {
      _lastError = '';
      return;
    }

    _lastError = 'La cuenta conectada no coincide con el email permitido.';
    await Supabase.instance.client.auth.signOut();
  }
}
