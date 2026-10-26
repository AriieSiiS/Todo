import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mobile_task_snapshot.dart';

class LanConnectionConfig {
  const LanConnectionConfig({
    required this.serverId,
    required this.deviceId,
    required this.endpoint,
    required this.certificateFingerprint,
    required this.revision,
    required this.lastSyncAt,
  });

  final String serverId;
  final String deviceId;
  final String endpoint;
  final String certificateFingerprint;
  final String revision;
  final DateTime? lastSyncAt;

  LanConnectionConfig copyWith({
    String? endpoint,
    String? revision,
    DateTime? lastSyncAt,
  }) =>
      LanConnectionConfig(
        serverId: serverId,
        deviceId: deviceId,
        endpoint: endpoint ?? this.endpoint,
        certificateFingerprint: certificateFingerprint,
        revision: revision ?? this.revision,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      );
}

class MobileLanStore {
  static const _tokenKey = 'todo.lan.token.v1';
  static const _configKey = 'todo.lan.config.v1';
  static const _cacheFileName = 'task_snapshot_v1.json';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  Future<LanConnectionConfig?> loadConfig() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_configKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return LanConnectionConfig(
        serverId: json['serverId'] as String? ?? '',
        deviceId: json['deviceId'] as String? ?? '',
        endpoint: json['endpoint'] as String? ?? '',
        certificateFingerprint: json['certificateFingerprint'] as String? ?? '',
        revision: json['revision'] as String? ?? '',
        lastSyncAt:
            DateTime.tryParse(json['lastSyncAt'] as String? ?? '')?.toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConfig(LanConnectionConfig config) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _configKey,
      jsonEncode({
        'serverId': config.serverId,
        'deviceId': config.deviceId,
        'endpoint': config.endpoint,
        'certificateFingerprint': config.certificateFingerprint,
        'revision': config.revision,
        'lastSyncAt': config.lastSyncAt?.toUtc().toIso8601String(),
      }),
    );
  }

  Future<String?> loadToken() => _secureStorage.read(key: _tokenKey);

  Future<void> saveToken(String token) =>
      _secureStorage.write(key: _tokenKey, value: token);

  Future<MobileTaskSnapshot?> loadSnapshot() async {
    final file = await _cacheFile();
    if (!await file.exists()) return null;
    try {
      final decoded = (jsonDecode(await file.readAsString()) as Map)
          .cast<String, dynamic>();
      return MobileTaskSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSnapshot(Map<String, dynamic> snapshot) async {
    final file = await _cacheFile();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_configKey);
    await _secureStorage.delete(key: _tokenKey);
    await clearSnapshot();
  }

  Future<void> clearSnapshot() async {
    final file = await _cacheFile();
    if (await file.exists()) await file.delete();
  }

  Future<File> _cacheFile() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}Todo${Platform.pathSeparator}lan_sync',
    );
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$_cacheFileName');
  }
}
