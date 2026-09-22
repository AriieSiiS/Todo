import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const int protocolVersion = 1;
const int defaultPort = 47832;
const String serviceType = '_todo-sync._tcp.local';

Future<void> main(List<String> arguments) async {
  final agent = TodoLanAgent();
  await agent.start();
}

class TodoLanAgent {
  TodoLanAgent({Directory? dataDirectory, Directory? stateDirectory})
      : dataDirectory = dataDirectory ?? _defaultDataDirectory(),
        stateDirectory = stateDirectory ?? _defaultStateDirectory();

  final Directory dataDirectory;
  final Directory stateDirectory;
  final Random _random = Random.secure();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  HttpServer? _server;
  MdnsAdvertiser? _mdns;
  Map<String, dynamic>? _projection;
  String _revision = '';
  String _pairingSecret = '';
  DateTime _pairingExpiresAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _pairingTimer;
  Timer? _snapshotDebounce;
  late String _serverId;
  late Map<String, dynamic> _certificateConfig;

  static Directory _defaultDataDirectory() {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    final base = localAppData == null || localAppData.isEmpty
        ? Directory.current.path
        : localAppData;
    return Directory(
        '$base${Platform.pathSeparator}Todo${Platform.pathSeparator}lan_sync');
  }

  static Directory _defaultStateDirectory() {
    final profile = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return Directory(
      '$profile${Platform.pathSeparator}Documents${Platform.pathSeparator}Todo${Platform.pathSeparator}runtime',
    );
  }

  File get _stateFile => File(
        '${stateDirectory.path}${Platform.pathSeparator}todo_state.json',
      );
  File get _identityFile => File(
        '${dataDirectory.path}${Platform.pathSeparator}identity.json',
      );
  File get _certificateFile => File(
        '${dataDirectory.path}${Platform.pathSeparator}certificate.json',
      );
  File get _devicesFile => File(
        '${dataDirectory.path}${Platform.pathSeparator}paired_devices.json',
      );
  File get _statusFile => File(
        '${dataDirectory.path}${Platform.pathSeparator}status.json',
      );

  Future<void> start() async {
    await dataDirectory.create(recursive: true);
    _serverId = await _loadOrCreateServerId();
    _certificateConfig = await _ensureCertificate();
    await _refreshSnapshot();
    _rotatePairingSecret();

    final context = SecurityContext()
      ..useCertificateChain(
        _certificateConfig['pfxPath'] as String,
        password: _certificateConfig['pfxPassword'] as String,
      )
      ..usePrivateKey(
        _certificateConfig['pfxPath'] as String,
        password: _certificateConfig['pfxPassword'] as String,
      );
    _server = await HttpServer.bindSecure(
      InternetAddress.anyIPv4,
      defaultPort,
      context,
      shared: true,
    );
    _subscriptions.add(_server!.listen(_handleRequest));

    if (await stateDirectory.exists()) {
      _subscriptions.add(
        stateDirectory.watch().listen((event) {
          if (event.path.toLowerCase().endsWith('todo_state.json')) {
            _snapshotDebounce?.cancel();
            _snapshotDebounce = Timer(
              const Duration(milliseconds: 250),
              _refreshSnapshot,
            );
          }
        }),
      );
    }

    final addresses = await privateIpv4Addresses();
    if (addresses.isNotEmpty) {
      _mdns = MdnsAdvertiser(
        serverId: _serverId,
        address: addresses.first,
        port: defaultPort,
      );
      await _mdns!.start();
    }
    await _writeStatus();

    _pairingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (DateTime.now().isAfter(_pairingExpiresAt)) {
        _rotatePairingSecret();
      }
      unawaited(_writeStatus());
    });

    final signals = Platform.isWindows
        ? <ProcessSignal>[ProcessSignal.sigint]
        : <ProcessSignal>[ProcessSignal.sigint, ProcessSignal.sigterm];
    for (final signal in signals) {
      try {
        signal.watch().listen((_) => stop());
      } catch (_) {
        // Algunas señales POSIX no están disponibles en Windows.
      }
    }
  }

  Future<void> stop() async {
    _pairingTimer?.cancel();
    _snapshotDebounce?.cancel();
    await _mdns?.close();
    await _server?.close(force: true);
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    exit(0);
  }

  Future<String> _loadOrCreateServerId() async {
    if (await _identityFile.exists()) {
      final decoded = jsonDecode(await _identityFile.readAsString());
      final id = decoded is Map ? decoded['serverId'] as String? : null;
      if (id != null && id.isNotEmpty) return id;
    }
    final id = _randomToken(12).replaceAll(RegExp('[^A-Za-z0-9]'), '');
    await _writeJsonAtomically(_identityFile, {'serverId': id});
    return id;
  }

  Future<Map<String, dynamic>> _ensureCertificate() async {
    if (await _certificateFile.exists()) {
      final decoded = jsonDecode(await _certificateFile.readAsString());
      if (decoded is Map<String, dynamic> &&
          File(decoded['pfxPath'] as String? ?? '').existsSync()) {
        return decoded;
      }
      if (decoded is Map) {
        final cast = decoded.cast<String, dynamic>();
        if (File(cast['pfxPath'] as String? ?? '').existsSync()) return cast;
      }
    }

    final executableDirectory = File(Platform.resolvedExecutable).parent;
    final candidates = <File>[
      File(
          '${executableDirectory.path}${Platform.pathSeparator}provision_lan_sync_certificate.ps1'),
      File(
          '${Directory.current.path}${Platform.pathSeparator}tooling${Platform.pathSeparator}provision_lan_sync_certificate.ps1'),
      File(
          '${Directory.current.parent.path}${Platform.pathSeparator}tooling${Platform.pathSeparator}provision_lan_sync_certificate.ps1'),
    ];
    final script = candidates.firstWhere(
      (candidate) => candidate.existsSync(),
      orElse: () => throw StateError(
        'No se encuentra provision_lan_sync_certificate.ps1.',
      ),
    );
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script.path,
        '-ConfigDirectory',
        dataDirectory.path,
        '-ServerId',
        _serverId,
      ],
    );
    if (result.exitCode != 0 || !await _certificateFile.exists()) {
      throw StateError(
        'No se pudo crear el certificado local: ${result.stderr}',
      );
    }
    return (jsonDecode(await _certificateFile.readAsString()) as Map)
        .cast<String, dynamic>();
  }

  void _rotatePairingSecret() {
    _pairingSecret = _randomToken(32);
    _pairingExpiresAt = DateTime.now().add(const Duration(minutes: 5));
  }

  Future<void> _refreshSnapshot() async {
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        if (!await _stateFile.exists()) return;
        final decoded = jsonDecode(await _stateFile.readAsString());
        if (decoded is! Map) return;
        final projected = projectTaskSnapshot(
          decoded.cast<String, dynamic>(),
          serverId: _serverId,
        );
        final encoded = jsonEncode(projected);
        _revision = sha256.convert(utf8.encode(encoded)).toString();
        _projection = {
          ...projected,
          'revision': _revision,
          'generatedAt': DateTime.now().toUtc().toIso8601String(),
          'desktopUtcOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
          'desktopTimeZoneName': DateTime.now().timeZoneName,
        };
        if (_server != null) unawaited(_writeStatus());
        return;
      } catch (_) {
        await Future<void>.delayed(Duration(milliseconds: 80 * (attempt + 1)));
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final remote = request.connectionInfo?.remoteAddress;
      if (remote == null || !isPrivateAddress(remote)) {
        return _json(request.response, 403, {'error': 'red_no_permitida'});
      }
      request.response.headers
        ..set('X-Content-Type-Options', 'nosniff')
        ..set('Cache-Control', 'no-store');

      if (request.method == 'GET' && request.uri.path == '/v1/health') {
        return _json(request.response, 200, {
          'protocolVersion': protocolVersion,
          'serverId': _serverId,
          'service': 'Todo',
        });
      }
      if (request.method == 'POST' && request.uri.path == '/v1/pair') {
        return _pair(request);
      }
      if (request.method == 'GET' && request.uri.path == '/v1/task-snapshot') {
        if (!await _isAuthorized(request)) {
          return _json(request.response, 401, {'error': 'no_autorizado'});
        }
        if (_projection == null) await _refreshSnapshot();
        if (_projection == null) {
          return _json(
              request.response, 503, {'error': 'snapshot_no_disponible'});
        }
        final etag = '"$_revision"';
        if (request.headers.value(HttpHeaders.ifNoneMatchHeader) == etag) {
          request.response.statusCode = HttpStatus.notModified;
          request.response.headers.set(HttpHeaders.etagHeader, etag);
          return request.response.close();
        }
        request.response.headers.set(HttpHeaders.etagHeader, etag);
        return _json(request.response, 200, _projection!);
      }
      _json(request.response, 404, {'error': 'ruta_no_encontrada'});
    } catch (_) {
      try {
        _json(request.response, 500, {'error': 'error_interno'});
      } catch (_) {
        await request.response.close();
      }
    }
  }

  Future<void> _pair(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return _json(request.response, 400, {'error': 'solicitud_invalida'});
    }
    final secret = decoded['secret'] as String? ?? '';
    final deviceName = (decoded['deviceName'] as String? ?? 'Android').trim();
    if (DateTime.now().isAfter(_pairingExpiresAt) ||
        !_constantTimeEquals(secret, _pairingSecret)) {
      return _json(request.response, 401, {'error': 'codigo_caducado'});
    }

    final token = _randomToken(32);
    final deviceId = _randomToken(12).replaceAll(RegExp('[^A-Za-z0-9]'), '');
    final devices = await _loadDevices();
    devices.add({
      'id': deviceId,
      'name': deviceName.isEmpty ? 'Android' : deviceName,
      'tokenHash': sha256.convert(utf8.encode(token)).toString(),
      'pairedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await _writeJsonAtomically(_devicesFile, {'devices': devices});
    _rotatePairingSecret();
    await _writeStatus();
    return _json(request.response, 200, {
      'protocolVersion': protocolVersion,
      'serverId': _serverId,
      'deviceId': deviceId,
      'token': token,
    });
  }

  Future<bool> _isAuthorized(HttpRequest request) async {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (header == null || !header.startsWith('Bearer ')) return false;
    final actual = sha256.convert(utf8.encode(header.substring(7))).toString();
    final devices = await _loadDevices();
    return devices.any(
      (device) => _constantTimeEquals(
        device['tokenHash'] as String? ?? '',
        actual,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadDevices() async {
    try {
      if (!await _devicesFile.exists()) return [];
      final decoded = jsonDecode(await _devicesFile.readAsString());
      final values = decoded is Map ? decoded['devices'] as List? : null;
      return (values ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeStatus() async {
    final addresses = await privateIpv4Addresses();
    final endpoint = addresses.isEmpty
        ? ''
        : 'https://${addresses.first.address}:$defaultPort';
    await _writeJsonAtomically(_statusFile, {
      'running': true,
      'protocolVersion': protocolVersion,
      'serverId': _serverId,
      'serviceType': serviceType,
      'port': defaultPort,
      'addresses': addresses.map((value) => value.address).toList(),
      'endpoint': endpoint,
      'certificateFingerprint': _certificateConfig['fingerprintSha256'],
      'pairingSecret': _pairingSecret,
      'pairingExpiresAt': _pairingExpiresAt.toUtc().toIso8601String(),
      'revision': _revision,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'qrPayload': jsonEncode({
        'type': 'todo-lan-pairing',
        'protocolVersion': protocolVersion,
        'serverId': _serverId,
        'serviceType': serviceType,
        'endpoint': endpoint,
        'certificateFingerprint': _certificateConfig['fingerprintSha256'],
        'secret': _pairingSecret,
        'expiresAt': _pairingExpiresAt.toUtc().toIso8601String(),
      }),
    });
  }

  String _randomToken(int bytes) {
    final values = List<int>.generate(bytes, (_) => _random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }
}

Map<String, dynamic> projectTaskSnapshot(
  Map<String, dynamic> source, {
  required String serverId,
}) {
  final allTasks = (source['tasks'] as List? ?? const [])
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList();
  final includedIds = <String>{
    for (final task in allTasks)
      if (task['status'] == 'active' && task['parentTaskId'] == null)
        task['id'] as String? ?? '',
  }..remove('');
  var changed = true;
  while (changed) {
    changed = false;
    for (final task in allTasks) {
      final id = task['id'] as String? ?? '';
      final parentId = task['parentTaskId'] as String?;
      if (id.isNotEmpty &&
          parentId != null &&
          includedIds.contains(parentId) &&
          includedIds.add(id)) {
        changed = true;
      }
    }
  }
  final tasks = allTasks
      .where((task) => includedIds.contains(task['id']))
      .map(_projectTask)
      .toList();
  final categoryIds = <String>{
    for (final task in tasks)
      for (final id in (task['categoryIds'] as List? ?? const []))
        id.toString(),
  };
  final projectIds = <String>{
    for (final task in tasks)
      for (final id in (task['projectIds'] as List? ?? const [])) id.toString(),
  };
  final categories = (source['categories'] as List? ?? const [])
      .whereType<Map>()
      .where((item) => categoryIds.contains(item['id']))
      .map((item) => _allow(item, const [
            'id',
            'name',
            'description',
            'colorValue',
            'iconCodePoint',
            'active',
          ]))
      .toList();
  final projects = (source['projects'] as List? ?? const [])
      .whereType<Map>()
      .where((item) => projectIds.contains(item['id']))
      .map((item) => _allow(item, const [
            'id',
            'name',
            'description',
            'colorValue',
            'iconCodePoint',
            'status',
            'categoryIds',
          ]))
      .toList();
  final daySettings = source['daySettings'] is Map
      ? _allow(source['daySettings'] as Map, const [
          'dayEndsAtHour',
          'nextDayVisibleAtHour',
        ])
      : <String, dynamic>{
          'dayEndsAtHour': 5,
          'nextDayVisibleAtHour': 10,
        };
  return {
    'protocolVersion': protocolVersion,
    'serverId': serverId,
    'tasks': tasks,
    'categories': categories,
    'projects': projects,
    'daySettings': daySettings,
  };
}

Map<String, dynamic> _projectTask(Map<String, dynamic> task) => _allow(
      task,
      const [
        'id',
        'title',
        'description',
        'categoryIds',
        'projectIds',
        'scheduledAt',
        'priority',
        'status',
        'recurrence',
        'subtaskIds',
        'checklist',
        'materials',
        'origin',
        'manualOrder',
        'parentTaskId',
        'collapsed',
        'reminderRules',
        'completedAt',
        'recurrenceCompletions',
      ],
    );

Map<String, dynamic> _allow(Map source, List<String> keys) => {
      for (final key in keys)
        if (source.containsKey(key)) key: source[key],
    };

bool isPrivateAddress(InternetAddress address) {
  if (address.isLoopback) return true;
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4 && bytes.length == 4) {
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168) ||
        (bytes[0] == 169 && bytes[1] == 254);
  }
  return address.type == InternetAddressType.IPv6 &&
      bytes.isNotEmpty &&
      (bytes[0] & 0xfe) == 0xfc;
}

Future<List<InternetAddress>> privateIpv4Addresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );
  return [
    for (final interface in interfaces)
      for (final address in interface.addresses)
        if (isPrivateAddress(address) && !address.isLoopback) address,
  ];
}

bool _constantTimeEquals(String left, String right) {
  final a = utf8.encode(left);
  final b = utf8.encode(right);
  var difference = a.length ^ b.length;
  final length = max(a.length, b.length);
  for (var index = 0; index < length; index++) {
    difference |=
        (index < a.length ? a[index] : 0) ^ (index < b.length ? b[index] : 0);
  }
  return difference == 0;
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

void _json(HttpResponse response, int statusCode, Object value) {
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(value));
  response.close();
}

class MdnsAdvertiser {
  MdnsAdvertiser({
    required this.serverId,
    required this.address,
    required this.port,
  });

  final String serverId;
  final InternetAddress address;
  final int port;
  RawDatagramSocket? _socket;
  Timer? _timer;

  String get _instance => 'Todo-$serverId.$serviceType';
  String get _host => 'todo-$serverId.local';

  Future<void> start() async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        5353,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
        ttl: 255,
      );
      _socket!.joinMulticast(InternetAddress('224.0.0.251'));
      _socket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _socket!.receive();
        if (datagram != null && _isRelevantQuery(datagram.data)) {
          _announce();
        }
      });
      _announce();
      _timer = Timer.periodic(const Duration(seconds: 60), (_) => _announce());
    } catch (_) {
      await close();
    }
  }

  bool _isRelevantQuery(Uint8List packet) {
    if (packet.length < 12) return false;
    final count = (packet[4] << 8) | packet[5];
    var offset = 12;
    for (var index = 0; index < count && offset < packet.length; index++) {
      final decoded = _decodeDnsName(packet, offset);
      offset = decoded.$2 + 4;
      final name = decoded.$1.toLowerCase();
      if (name == serviceType ||
          name == _instance.toLowerCase() ||
          name == _host.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  void _announce() {
    final socket = _socket;
    if (socket == null) return;
    final builder = BytesBuilder();
    builder.add([0, 0, 0x84, 0, 0, 0, 0, 4, 0, 0, 0, 0]);
    _record(builder, serviceType, 12, _dnsName(_instance), cacheFlush: false);
    final srv = BytesBuilder()
      ..add([0, 0, 0, 0, port >> 8, port & 0xff])
      ..add(_dnsName(_host));
    _record(builder, _instance, 33, srv.toBytes());
    final txt = utf8.encode('id=$serverId');
    final version = utf8.encode('v=$protocolVersion');
    _record(
        builder,
        _instance,
        16,
        Uint8List.fromList([
          txt.length,
          ...txt,
          version.length,
          ...version,
        ]));
    _record(builder, _host, 1, address.rawAddress);
    socket.send(
      builder.toBytes(),
      InternetAddress('224.0.0.251'),
      5353,
    );
  }

  void _record(
    BytesBuilder builder,
    String name,
    int type,
    List<int> data, {
    bool cacheFlush = true,
  }) {
    builder
      ..add(_dnsName(name))
      ..add([
        type >> 8,
        type & 0xff,
        cacheFlush ? 0x80 : 0,
        1,
        0,
        0,
        0,
        120,
        data.length >> 8,
        data.length & 0xff,
      ])
      ..add(data);
  }

  Future<void> close() async {
    _timer?.cancel();
    _socket?.close();
    _socket = null;
  }
}

Uint8List _dnsName(String name) {
  final builder = BytesBuilder();
  for (final label in name.split('.').where((value) => value.isNotEmpty)) {
    final bytes = utf8.encode(label);
    builder.addByte(bytes.length);
    builder.add(bytes);
  }
  builder.addByte(0);
  return builder.toBytes();
}

(String, int) _decodeDnsName(Uint8List packet, int start) {
  final labels = <String>[];
  var offset = start;
  var returnOffset = start;
  var jumped = false;
  var guard = 0;
  while (offset < packet.length && guard++ < 32) {
    final length = packet[offset];
    if (length == 0) {
      if (!jumped) returnOffset = offset + 1;
      break;
    }
    if ((length & 0xc0) == 0xc0 && offset + 1 < packet.length) {
      if (!jumped) returnOffset = offset + 2;
      offset = ((length & 0x3f) << 8) | packet[offset + 1];
      jumped = true;
      continue;
    }
    offset++;
    if (offset + length > packet.length) break;
    labels.add(utf8.decode(packet.sublist(offset, offset + length),
        allowMalformed: true));
    offset += length;
    if (!jumped) returnOffset = offset;
  }
  return (labels.join('.'), returnOffset);
}
