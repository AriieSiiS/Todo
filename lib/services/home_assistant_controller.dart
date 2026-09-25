import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'home_twin_service.dart';

abstract class HomeAssistantTokenStore {
  Future<String?> read();
  Future<void> write(String token);
}

class _WindowsHomeAssistantTokenStore implements HomeAssistantTokenStore {
  static const _key = 'todo.home_assistant.token.v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
}

class HomeAssistantLight {
  const HomeAssistantLight({
    required this.entityId,
    required this.name,
    required this.state,
    required this.brightness,
    required this.rgb,
    required this.temperature,
    required this.minTemperature,
    required this.maxTemperature,
    required this.colorMode,
    required this.colorModes,
  });

  final String entityId;
  final String name;
  final String state;
  final int brightness;
  final List<int>? rgb;
  final int? temperature;
  final int minTemperature;
  final int maxTemperature;
  final String? colorMode;
  final Set<String> colorModes;

  bool get available => state == 'on' || state == 'off';
  bool get isOn => state == 'on';
  bool get supportsBrightness => colorModes.any((mode) => const {
        'brightness',
        'color_temp',
        'hs',
        'rgb',
        'rgbw',
        'rgbww',
        'xy'
      }.contains(mode));
  bool get supportsColor => colorModes
      .any((mode) => const {'hs', 'rgb', 'rgbw', 'rgbww', 'xy'}.contains(mode));
  bool get supportsTemperature => colorModes.contains('color_temp');

  factory HomeAssistantLight.fromState(Map<String, dynamic> value) {
    final attributes = (value['attributes'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final rawRgb = attributes['rgb_color'];
    return HomeAssistantLight(
      entityId: value['entity_id'] as String? ?? '',
      name: attributes['friendly_name'] as String? ??
          value['entity_id'] as String? ??
          'Luz',
      state: value['state'] as String? ?? 'unavailable',
      brightness:
          ((attributes['brightness'] as num?)?.toInt() ?? 255).clamp(1, 255),
      rgb: rawRgb is List && rawRgb.length >= 3
          ? rawRgb.take(3).map((v) => (v as num).toInt().clamp(0, 255)).toList()
          : null,
      temperature: (attributes['color_temp_kelvin'] as num?)?.toInt(),
      minTemperature:
          (attributes['min_color_temp_kelvin'] as num?)?.toInt() ?? 2500,
      maxTemperature:
          (attributes['max_color_temp_kelvin'] as num?)?.toInt() ?? 6500,
      colorMode: attributes['color_mode'] as String?,
      colorModes: ((attributes['supported_color_modes'] as List?) ?? const [])
          .whereType<String>()
          .toSet(),
    );
  }

  Map<String, dynamic> toVisualState() => {
        'roomId': 'dormitorio',
        'objectId': 'luz_techo',
        'available': available,
        'on': isOn,
        'brightness': brightness,
        'rgb': colorMode == 'color_temp' ? null : rgb,
        'temperature': temperature,
      };
}

class HomeAssistantController extends ChangeNotifier {
  HomeAssistantController({
    HomeTwinService? twin,
    HomeAssistantTokenStore? tokenStore,
  })  : _twin = twin ?? HomeTwinService(),
        _tokenStore = tokenStore ?? _WindowsHomeAssistantTokenStore();

  final HomeTwinService _twin;
  final HomeAssistantTokenStore _tokenStore;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  final Map<String, HomeAssistantLight> _lights = {};
  WebSocket? _socket;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Completer<void>? _authenticated;
  int _nextId = 1;
  int _retry = 0;
  bool _disposed = false;
  bool _connecting = false;
  bool _commandPending = false;
  String endpoint = '';
  String entityId = '';
  String? error;
  bool connected = false;
  bool hasToken = false;

  bool get connecting => _connecting;
  bool get commandPending => _commandPending;
  List<HomeAssistantLight> get lights =>
      _lights.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  HomeAssistantLight? get selectedLight => _lights[entityId];

  Future<File> _configFile() async {
    final root = await _twin.root();
    return File('${root.path}${Platform.pathSeparator}home_assistant.json');
  }

  Future<void> initialize() async {
    if (!Platform.isWindows) return;
    try {
      final file = await _configFile();
      if (await file.exists()) {
        final json = (jsonDecode(await file.readAsString()) as Map)
            .cast<String, dynamic>();
        endpoint = json['endpoint'] as String? ?? '';
        final bindings = (json['bindings'] as Map?)?.cast<String, dynamic>();
        entityId = bindings?['dormitorio/luz_techo'] as String? ?? '';
      }
      hasToken = (await _tokenStore.read())?.isNotEmpty == true;
      notifyListeners();
      if (endpoint.isNotEmpty && hasToken) unawaited(connect());
    } catch (_) {
      error = 'No se pudo leer la configuración de Home Assistant.';
      notifyListeners();
    }
  }

  Future<void> configure({
    required String url,
    required String newToken,
    required String selectedEntityId,
  }) async {
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null ||
        !{'http', 'https'}.contains(parsed.scheme) ||
        parsed.host.isEmpty ||
        !_isLocalAddress(parsed.host) ||
        parsed.userInfo.isNotEmpty ||
        parsed.path != '' && parsed.path != '/' ||
        parsed.hasQuery ||
        parsed.hasFragment) {
      throw const FormatException(
          'Escribe una dirección local válida, por ejemplo http://192.168.1.50:8123.');
    }
    if (newToken.trim().isEmpty && !hasToken) {
      throw const FormatException('Introduce un token de Home Assistant.');
    }
    if (selectedEntityId.isNotEmpty &&
        !RegExp(r'^light\.[a-z0-9_]+$').hasMatch(selectedEntityId)) {
      throw const FormatException('La entidad de la bombilla no es válida.');
    }
    await disconnect();
    if (newToken.trim().isNotEmpty) {
      await _tokenStore.write(newToken.trim());
      hasToken = true;
    }
    endpoint = parsed.toString().replaceFirst(RegExp(r'/$'), '');
    entityId = selectedEntityId;
    final file = await _configFile();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'endpoint': endpoint,
          'bindings': {'dormitorio/luz_techo': entityId},
        }),
        flush: true);
    await temporary.rename(file.path);
    notifyListeners();
    await connect();
  }

  static bool _isLocalAddress(String host) {
    if (host == 'localhost' ||
        host == 'homeassistant' ||
        host.endsWith('.local')) {
      return true;
    }
    final address = InternetAddress.tryParse(host);
    if (address == null) return false;
    if (address.isLoopback) return true;
    if (address.type != InternetAddressType.IPv4) return false;
    final bytes = address.rawAddress;
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168);
  }

  Future<void> bindLight(String id) async {
    await configure(url: endpoint, newToken: '', selectedEntityId: id);
  }

  Future<void> connect() async {
    if (_disposed || _connecting || connected || endpoint.isEmpty) return;
    _reconnectTimer?.cancel();
    _connecting = true;
    error = null;
    notifyListeners();
    try {
      final token = await _tokenStore.read();
      if (token == null || token.isEmpty) {
        throw const FormatException('Falta el token de Home Assistant.');
      }
      final base = Uri.parse(endpoint);
      final uri = base.replace(
          scheme: base.scheme == 'https' ? 'wss' : 'ws',
          path: '/api/websocket');
      final socket = await WebSocket.connect(uri.toString())
          .timeout(const Duration(seconds: 8));
      if (_disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      socket.pingInterval = const Duration(seconds: 20);
      _authenticated = Completer<void>();
      _subscription = socket.listen(
        (data) => _handleMessage(data, token),
        onDone: _lostConnection,
        onError: (_) => _lostConnection(),
        cancelOnError: true,
      );
      await _authenticated!.future.timeout(const Duration(seconds: 8));
      final response = await _request({'type': 'get_states'});
      _readStates(response['result']);
      await _request(
          {'type': 'subscribe_events', 'event_type': 'state_changed'});
      connected = true;
      _retry = 0;
      error = null;
      notifyListeners();
    } catch (failure) {
      error = failure is FormatException
          ? failure.message
          : 'No se pudo conectar con Home Assistant. Comprueba la dirección, el token y la red.';
      _lostConnection();
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  void _handleMessage(dynamic data, String token) {
    if (data is! String) return;
    final message = (jsonDecode(data) as Map).cast<String, dynamic>();
    switch (message['type']) {
      case 'auth_required':
        _socket?.add(jsonEncode({'type': 'auth', 'access_token': token}));
      case 'auth_ok':
        if (!(_authenticated?.isCompleted ?? true)) _authenticated!.complete();
      case 'auth_invalid':
        error = 'El token de Home Assistant no es válido.';
        if (!(_authenticated?.isCompleted ?? true)) {
          _authenticated!.completeError(const FormatException(
              'El token de Home Assistant no es válido.'));
        }
      case 'result':
        final id = message['id'];
        if (id is int) _pending.remove(id)?.complete(message);
      case 'event':
        final event = message['event'];
        if (event is! Map) return;
        final values = event['data'];
        if (values is! Map) return;
        final id = values['entity_id'];
        if (id is! String || !id.startsWith('light.')) return;
        final state = values['new_state'];
        if (state is Map) {
          _lights[id] =
              HomeAssistantLight.fromState(state.cast<String, dynamic>());
        } else {
          _lights.remove(id);
        }
        notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _request(Map<String, dynamic> message) async {
    final socket = _socket;
    if (socket == null) throw const SocketException('Sin conexión.');
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    socket.add(jsonEncode({...message, 'id': id}));
    try {
      final result =
          await completer.future.timeout(const Duration(seconds: 10));
      if (result['success'] != true) {
        throw const FormatException('Home Assistant rechazó la operación.');
      }
      return result;
    } finally {
      _pending.remove(id);
    }
  }

  void _readStates(dynamic result) {
    if (result is! List) return;
    _lights.clear();
    for (final value in result) {
      if (value is! Map || value['entity_id'] is! String) continue;
      if (!(value['entity_id'] as String).startsWith('light.')) continue;
      final light = HomeAssistantLight.fromState(value.cast<String, dynamic>());
      _lights[light.entityId] = light;
    }
    notifyListeners();
  }

  Future<void> setLight({
    required bool on,
    int? brightness,
    List<int>? rgb,
    int? temperature,
  }) async {
    final light = selectedLight;
    if (!connected || light == null || !light.available || _commandPending) {
      throw const FormatException('La bombilla no está disponible.');
    }
    _commandPending = true;
    error = null;
    notifyListeners();
    try {
      final data = <String, dynamic>{'entity_id': entityId};
      if (on) {
        if (brightness != null) data['brightness'] = brightness.clamp(1, 255);
        if (rgb != null) data['rgb_color'] = rgb;
        if (temperature != null) data['color_temp_kelvin'] = temperature;
      }
      await _request({
        'type': 'call_service',
        'domain': 'light',
        'service': on ? 'turn_on' : 'turn_off',
        'service_data': data,
      });
      final states = await _request({'type': 'get_states'});
      _readStates(states['result']);
    } catch (_) {
      error = 'No se pudo confirmar el cambio de la bombilla.';
      notifyListeners();
      rethrow;
    } finally {
      _commandPending = false;
      notifyListeners();
    }
  }

  void _lostConnection() {
    if (_disposed) return;
    connected = false;
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(const SocketException('Conexión interrumpida.'));
      }
    }
    _pending.clear();
    if (!(_authenticated?.isCompleted ?? true)) {
      _authenticated!
          .completeError(const SocketException('Conexión interrumpida.'));
    }
    _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _socket = null;
    notifyListeners();
    if (endpoint.isNotEmpty && hasToken) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(
        Duration(seconds: [2, 4, 8, 16, 30][_retry.clamp(0, 4)]),
        connect,
      );
      if (_retry < 4) _retry++;
    }
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    connected = false;
    final socket = _socket;
    _socket = null;
    await _subscription?.cancel();
    _subscription = null;
    await socket?.close();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    unawaited(_socket?.close() ?? Future<void>.value());
    super.dispose();
  }
}
