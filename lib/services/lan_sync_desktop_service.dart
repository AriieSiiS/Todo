import 'dart:convert';
import 'dart:io';

class LanSyncDesktopStatus {
  const LanSyncDesktopStatus({
    required this.running,
    required this.serverId,
    required this.endpoint,
    required this.fingerprint,
    required this.qrPayload,
    required this.pairingExpiresAt,
    required this.addresses,
    required this.devices,
    this.error = '',
  });

  const LanSyncDesktopStatus.unavailable([this.error = ''])
      : running = false,
        serverId = '',
        endpoint = '',
        fingerprint = '',
        qrPayload = '',
        pairingExpiresAt = null,
        addresses = const <String>[],
        devices = const <LanSyncPairedDevice>[];

  final bool running;
  final String serverId;
  final String endpoint;
  final String fingerprint;
  final String qrPayload;
  final DateTime? pairingExpiresAt;
  final List<String> addresses;
  final List<LanSyncPairedDevice> devices;
  final String error;

  bool get pairingAvailable =>
      running &&
      qrPayload.isNotEmpty &&
      pairingExpiresAt != null &&
      pairingExpiresAt!.isAfter(DateTime.now());
}

class LanSyncPairedDevice {
  const LanSyncPairedDevice({
    required this.id,
    required this.name,
    required this.pairedAt,
  });

  final String id;
  final String name;
  final DateTime? pairedAt;
}

class LanSyncDesktopService {
  LanSyncDesktopService({Directory? configDirectory})
      : configDirectory = configDirectory ?? _defaultConfigDirectory();

  final Directory configDirectory;

  File get _statusFile => File(
        '${configDirectory.path}${Platform.pathSeparator}status.json',
      );
  File get _devicesFile => File(
        '${configDirectory.path}${Platform.pathSeparator}paired_devices.json',
      );

  static Directory _defaultConfigDirectory() {
    final base = Platform.environment['LOCALAPPDATA'] ?? Directory.current.path;
    return Directory(
      '$base${Platform.pathSeparator}Todo${Platform.pathSeparator}lan_sync',
    );
  }

  Future<LanSyncDesktopStatus> loadStatus({bool launchIfNeeded = true}) async {
    if (!Platform.isWindows) {
      return const LanSyncDesktopStatus.unavailable(
        'La conexión Android solo se sirve desde Windows.',
      );
    }
    try {
      var decoded = await _readStatus();
      final updatedAt = decoded == null
          ? null
          : DateTime.tryParse(decoded['updatedAt'] as String? ?? '')?.toLocal();
      final stale = updatedAt == null ||
          DateTime.now().difference(updatedAt) > const Duration(minutes: 3);
      if ((decoded == null || stale) && launchIfNeeded) {
        await _launchAgent();
        for (var attempt = 0; attempt < 20; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          decoded = await _readStatus();
          if (decoded != null) break;
        }
      }
      if (decoded == null) {
        return const LanSyncDesktopStatus.unavailable(
          'El agente local todavía no está disponible.',
        );
      }
      final devices = await _readDevices();
      return LanSyncDesktopStatus(
        running: true,
        serverId: decoded['serverId'] as String? ?? '',
        endpoint: decoded['endpoint'] as String? ?? '',
        fingerprint: decoded['certificateFingerprint'] as String? ?? '',
        qrPayload: decoded['qrPayload'] as String? ?? '',
        pairingExpiresAt:
            DateTime.tryParse(decoded['pairingExpiresAt'] as String? ?? '')
                ?.toLocal(),
        addresses: (decoded['addresses'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
        devices: devices,
      );
    } catch (error) {
      return LanSyncDesktopStatus.unavailable(
        'No se pudo consultar el agente local: $error',
      );
    }
  }

  Future<void> revokeDevice(String deviceId) async {
    final decoded = await _readJson(_devicesFile) ?? <String, dynamic>{};
    final devices = (decoded['devices'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => value.cast<String, dynamic>())
        .where((value) => value['id'] != deviceId)
        .toList();
    await _writeJsonAtomically(_devicesFile, {'devices': devices});
  }

  Future<Map<String, dynamic>?> _readStatus() => _readJson(_statusFile);

  Future<List<LanSyncPairedDevice>> _readDevices() async {
    final decoded = await _readJson(_devicesFile);
    return (decoded?['devices'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) => LanSyncPairedDevice(
            id: value['id'] as String? ?? '',
            name: value['name'] as String? ?? 'Android',
            pairedAt: DateTime.tryParse(value['pairedAt'] as String? ?? '')
                ?.toLocal(),
          ),
        )
        .where((value) => value.id.isNotEmpty)
        .toList();
  }

  Future<void> _launchAgent() async {
    final executableDirectory = File(Platform.resolvedExecutable).parent;
    final candidates = <File>[
      File(
        '${executableDirectory.path}${Platform.pathSeparator}todo_lan_agent.exe',
      ),
      File(
        '${Directory.current.path}${Platform.pathSeparator}build${Platform.pathSeparator}windows${Platform.pathSeparator}x64${Platform.pathSeparator}runner${Platform.pathSeparator}Release${Platform.pathSeparator}todo_lan_agent.exe',
      ),
    ];
    final executable = candidates.cast<File?>().firstWhere(
          (candidate) => candidate?.existsSync() ?? false,
          orElse: () => null,
        );
    if (executable == null) {
      throw StateError(
        'No se encuentra todo_lan_agent.exe. Vuelve a instalar Todo.',
      );
    }
    await Process.start(
      executable.path,
      const <String>[],
      mode: ProcessStartMode.detached,
    );
  }

  Future<Map<String, dynamic>?> _readJson(File file) async {
    if (!await file.exists()) return null;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        return (decoded as Map).cast<String, dynamic>();
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    }
    return null;
  }

  Future<void> _writeJsonAtomically(File file, Object value) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(value),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }
}
