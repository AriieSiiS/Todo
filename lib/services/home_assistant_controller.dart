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

class HomeLightPreset {
  const HomeLightPreset({
    required this.id,
    required this.name,
    required this.entityId,
    required this.on,
    required this.brightness,
    required this.rgb,
    required this.temperature,
    required this.colorMode,
  });

  final String id;
  final String name;
  final String entityId;
  final bool on;
  final int brightness;
  final List<int>? rgb;
  final int? temperature;
  final String? colorMode;

  factory HomeLightPreset.fromLight(
    HomeAssistantLight light, {
    required String id,
    required String name,
  }) =>
      HomeLightPreset(
        id: id,
        name: name,
        entityId: light.entityId,
        on: light.isOn,
        brightness: light.brightness,
        rgb: light.rgb == null ? null : List<int>.of(light.rgb!),
        temperature: light.temperature,
        colorMode: light.colorMode,
      );

  factory HomeLightPreset.fromJson(Map<String, dynamic> json) {
    final rawRgb = json['rgb'];
    return HomeLightPreset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      entityId: json['entityId'] as String? ?? '',
      on: json['on'] as bool? ?? true,
      brightness: ((json['brightness'] as num?)?.toInt() ?? 255).clamp(1, 255),
      rgb: rawRgb is List && rawRgb.length >= 3
          ? rawRgb
              .take(3)
              .map((value) => (value as num).toInt().clamp(0, 255))
              .toList()
          : null,
      temperature: (json['temperature'] as num?)?.toInt(),
      colorMode: json['colorMode'] as String?,
    );
  }

  HomeLightPreset withName(String value) => HomeLightPreset(
        id: id,
        name: value,
        entityId: entityId,
        on: on,
        brightness: brightness,
        rgb: rgb,
        temperature: temperature,
        colorMode: colorMode,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'entityId': entityId,
        'on': on,
        'brightness': brightness,
        'rgb': rgb,
        'temperature': temperature,
        'colorMode': colorMode,
      };
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
    required this.supportedFeatures,
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
  final int supportedFeatures;

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
  bool get supportsTransition => (supportedFeatures & 32) != 0;

  HomeAssistantLight withSetting(HomeLightPreset setting) => HomeAssistantLight(
        entityId: entityId,
        name: name,
        state: state,
        brightness: setting.brightness,
        rgb: setting.rgb,
        temperature: setting.temperature,
        minTemperature: minTemperature,
        maxTemperature: maxTemperature,
        colorMode: setting.colorMode,
        colorModes: colorModes,
        supportedFeatures: supportedFeatures,
      );

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
      supportedFeatures:
          (attributes['supported_features'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toVisualState({
    String roomId = 'dormitorio',
    String objectId = 'luz_techo',
  }) =>
      {
        'roomId': roomId,
        'objectId': objectId,
        'available': available,
        'on': isOn,
        'brightness': brightness,
        'rgb': colorMode == 'color_temp' ? null : rgb,
        'temperature': temperature,
      };
}

class HomeAssistantWeather {
  const HomeAssistantWeather({
    required this.entityId,
    required this.name,
    required this.condition,
    required this.temperatureC,
    required this.updatedAt,
  });

  final String entityId;
  final String name;
  final String condition;
  final double? temperatureC;
  final DateTime updatedAt;

  bool get available => condition != 'unknown' && condition != 'unavailable';

  factory HomeAssistantWeather.fromState(Map<String, dynamic> value) {
    final attributes = (value['attributes'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final temperature = (attributes['temperature'] as num?)?.toDouble();
    final unit = attributes['temperature_unit'] as String? ?? '°C';
    return HomeAssistantWeather(
      entityId: value['entity_id'] as String? ?? '',
      name: attributes['friendly_name'] as String? ??
          value['entity_id'] as String? ??
          'Tiempo',
      condition: value['state'] as String? ?? 'unavailable',
      temperatureC: temperature == null
          ? null
          : unit == '°F'
              ? (temperature - 32) * 5 / 9
              : temperature,
      updatedAt: DateTime.tryParse(value['last_updated'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class HomeAssistantEchoEntity {
  const HomeAssistantEchoEntity({
    required this.entityId,
    required this.name,
    required this.state,
    required this.attributes,
  });

  final String entityId;
  final String name;
  final String state;
  final Map<String, dynamic> attributes;

  bool get available => state != 'unavailable' && state != 'unknown';
  int get supportedFeatures =>
      (attributes['supported_features'] as num?)?.toInt() ?? 0;
  bool supports(int feature) => (supportedFeatures & feature) != 0;
  double? get volume => (attributes['volume_level'] as num?)?.toDouble();
  bool? get muted => attributes['is_volume_muted'] as bool?;
  String? get mediaTitle => attributes['media_title'] as String?;
  String? get mediaArtist => attributes['media_artist'] as String?;
  List<String> get options => ((attributes['options'] as List?) ?? const [])
      .whereType<String>()
      .toList();

  factory HomeAssistantEchoEntity.fromState(Map<String, dynamic> value) {
    final id = value['entity_id'] as String? ?? '';
    final attributes = (value['attributes'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return HomeAssistantEchoEntity(
      entityId: id,
      name: attributes['friendly_name'] as String? ?? id,
      state: value['state'] as String? ?? 'unavailable',
      attributes: attributes,
    );
  }
}

class _IndependentLightState {
  HomeAssistantLight? preview;
  HomeLightPreset? lastOn;
  bool held = false;
  int desiredRevision = 0;
  int sentRevision = 0;
  double transition = 0;
  Timer? sendTimer;
  Timer? confirmationTimer;
  Future<void>? sending;

  void clear() {
    sendTimer?.cancel();
    confirmationTimer?.cancel();
    preview = null;
    held = false;
    transition = 0;
    sentRevision = desiredRevision;
  }
}

class HomeAssistantController extends ChangeNotifier {
  static const double powerFadeSeconds = 2;

  HomeAssistantController({
    HomeTwinService? twin,
    HomeAssistantTokenStore? tokenStore,
  })  : _twin = twin ?? HomeTwinService(),
        _tokenStore = tokenStore ?? _WindowsHomeAssistantTokenStore();

  final HomeTwinService _twin;
  final HomeAssistantTokenStore _tokenStore;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  final Map<String, HomeAssistantLight> _lights = {};
  final Map<String, HomeAssistantWeather> _weathers = {};
  final Map<String, HomeAssistantWeather> _lastAvailableWeather = {};
  final Map<String, HomeAssistantEchoEntity> _echoEntities = {};
  final Map<String, String> _echoDeviceByEntity = {};
  final Map<String, String> _echoPlatformByEntity = {};
  bool? _sunAboveHorizon;
  double? _sunElevation;
  HomeAssistantLight? _previewLight;
  bool _previewHeld = false;
  WebSocket? _socket;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _sendTimer;
  Timer? _confirmationTimer;
  Timer? _configurationTimer;
  Future<void>? _sendFuture;
  Future<void> _configurationWrites = Future<void>.value();
  final List<HomeLightPreset> _presets = [];
  final Map<String, bool> _gradualOnByEntity = {};
  final Map<String, _IndependentLightState> _independentLights = {};
  HomeLightPreset? _lastOnLight;
  double _desiredTransition = 0;
  Completer<void>? _authenticated;
  int _nextId = 1;
  int _retry = 0;
  int _desiredRevision = 0;
  int _sentRevision = 0;
  bool _disposed = false;
  bool _connecting = false;
  String endpoint = '';
  String entityId = '';
  String hallwayEntityId = '';
  String secondRoomEntityId = '';
  String weatherEntityId = '';
  String echoEntityId = '';
  String? error;
  bool connected = false;
  bool hasToken = false;
  bool get gradualOnEnabled => _gradualOnByEntity[entityId] ?? true;

  String entityIdForRoom(String roomId) => switch (roomId) {
        'pasillo' => hallwayEntityId,
        'habitacion_vacia' => secondRoomEntityId,
        _ => entityId,
      };

  bool gradualOnEnabledForRoom(String roomId) =>
      _gradualOnByEntity[entityIdForRoom(roomId)] ?? true;

  bool commandPendingForRoom(String roomId) => roomId == 'dormitorio'
      ? commandPending
      : _independentLights[entityIdForRoom(roomId)]?.preview != null;

  List<HomeLightPreset> presetsForRoom(String roomId) => List.unmodifiable(
        _presets.where((preset) => preset.entityId == entityIdForRoom(roomId)),
      );

  bool get connecting => _connecting;
  bool get commandPending => _previewLight != null;
  List<HomeAssistantLight> get lights =>
      _lights.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  List<HomeAssistantWeather> get weathers =>
      _weathers.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  List<HomeAssistantEchoEntity> get echoPlayers => _echoEntities.values
      .where((entity) =>
          entity.entityId.startsWith('media_player.') &&
          _echoPlatformByEntity[entity.entityId] == 'alexa_devices')
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  HomeAssistantEchoEntity? get selectedEcho => _echoEntities[echoEntityId];
  String? get echoDeviceId => _echoDeviceByEntity[echoEntityId];
  List<HomeAssistantEchoEntity> echoEntities(String domain) {
    final deviceId = echoDeviceId;
    if (deviceId == null || deviceId.isEmpty) return const [];
    return _echoEntities.values
        .where((entity) =>
            entity.entityId.startsWith('$domain.') &&
            _echoDeviceByEntity[entity.entityId] == deviceId)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  HomeAssistantWeather? get selectedWeather {
    final current = _weathers[weatherEntityId];
    return current?.available == true
        ? current
        : _lastAvailableWeather[weatherEntityId] ?? current;
  }

  Map<String, dynamic> get weatherVisualState {
    final weather = selectedWeather;
    return {
      'condition': weather?.condition ?? 'unknown',
      'temperatureC': weather?.temperatureC,
      'sunAboveHorizon': _sunAboveHorizon,
      'sunElevation': _sunElevation,
      'updatedAt': weather?.updatedAt.toIso8601String(),
      'stale': !connected ||
          weather == null ||
          _weathers[weatherEntityId]?.available != true ||
          DateTime.now().difference(weather.updatedAt) >
              const Duration(hours: 2),
    };
  }

  List<HomeLightPreset> get presets => presetsForRoom('dormitorio');
  HomeAssistantLight? get selectedLight {
    final preview = _previewLight;
    if (preview != null) {
      final prepared = _lastOnLight;
      return !preview.isOn && prepared != null && prepared.entityId == entityId
          ? preview.withSetting(prepared)
          : preview;
    }
    final light = _lights[entityId];
    final previous = _lastOnLight;
    if (light != null &&
        !light.isOn &&
        previous != null &&
        previous.entityId == entityId) {
      return light.withSetting(previous);
    }
    return light;
  }

  HomeAssistantLight? lightForRoom(String roomId) {
    if (roomId == 'dormitorio') return selectedLight;
    final id = entityIdForRoom(roomId);
    if (id.isEmpty) return null;
    final channel = _independentLights[id];
    final preview = channel?.preview;
    if (preview != null) {
      return !preview.isOn && channel?.lastOn != null
          ? preview.withSetting(channel!.lastOn!)
          : preview;
    }
    final light = _lights[id];
    if (light != null && !light.isOn && channel?.lastOn != null) {
      return light.withSetting(channel!.lastOn!);
    }
    return light;
  }

  HomeAssistantLight? get hallwayLight => lightForRoom('pasillo');
  HomeAssistantLight? get secondRoomLight => lightForRoom('habitacion_vacia');

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
        hallwayEntityId = bindings?['pasillo/luz_pasillo'] as String? ?? '';
        secondRoomEntityId =
            bindings?['habitacion_vacia/luz_techo'] as String? ?? '';
        weatherEntityId =
            bindings?['dormitorio/ventana_clima'] as String? ?? '';
        echoEntityId = bindings?['dormitorio/echo_dot'] as String? ?? '';
        final gradualOn = json['gradualOnByEntity'];
        if (gradualOn is Map) {
          for (final entry in gradualOn.entries) {
            if (entry.key is String && entry.value is bool) {
              _gradualOnByEntity[entry.key as String] = entry.value as bool;
            }
          }
        } else if (entityId.isNotEmpty) {
          // Se conserva la elección anterior de encendido instantáneo.
          _gradualOnByEntity[entityId] =
              (json['powerTransitionSeconds'] as num?) != 0;
        }
        for (final value in (json['presets'] as List?) ?? const []) {
          if (value is! Map) continue;
          try {
            final preset =
                HomeLightPreset.fromJson(value.cast<String, dynamic>());
            if (preset.id.isNotEmpty && preset.name.isNotEmpty) {
              _presets.add(preset);
            }
          } catch (_) {
            // Se omite únicamente el ajuste guardado que no sea válido.
          }
        }
        final lastOn = json['lastOnLight'];
        if (lastOn is Map) {
          try {
            _lastOnLight =
                HomeLightPreset.fromJson(lastOn.cast<String, dynamic>());
          } catch (_) {
            // Un último ajuste dañado no impide cargar la conexión.
          }
        }
        final lastOnLights = json['lastOnLights'];
        if (lastOnLights is Map) {
          for (final entry in lastOnLights.entries) {
            if (entry.key is! String || entry.value is! Map) continue;
            try {
              _independentLights
                  .putIfAbsent(entry.key as String, _IndependentLightState.new)
                  .lastOn = HomeLightPreset.fromJson(
                (entry.value as Map).cast<String, dynamic>(),
              );
            } catch (_) {
              // Un ajuste dañado no impide cargar los demás.
            }
          }
        }
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
    await _saveConfiguration();
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

  Future<void> bindHallwayLight(String id) async {
    if (!RegExp(r'^light\.[a-z0-9_]+$').hasMatch(id)) {
      throw const FormatException('La entidad de la bombilla no es válida.');
    }
    if (id == entityId || id == secondRoomEntityId) {
      throw const FormatException(
          'Cada habitación debe tener una bombilla distinta.');
    }
    hallwayEntityId = id;
    await _saveConfiguration();
    notifyListeners();
  }

  Future<void> bindSecondRoomLight(String id) async {
    if (!RegExp(r'^light\.[a-z0-9_]+$').hasMatch(id)) {
      throw const FormatException('La entidad de la bombilla no es válida.');
    }
    if (id == entityId || id == hallwayEntityId) {
      throw const FormatException(
          'Cada habitación debe tener una bombilla distinta.');
    }
    secondRoomEntityId = id;
    await _saveConfiguration();
    notifyListeners();
  }

  Future<void> bindWeather(String id) async {
    if (!RegExp(r'^weather\.[a-z0-9_]+$').hasMatch(id)) {
      throw const FormatException('La entidad meteorológica no es válida.');
    }
    weatherEntityId = id;
    await _saveConfiguration();
    notifyListeners();
  }

  Future<void> bindEcho(String id) async {
    if (_echoPlatformByEntity[id] != 'alexa_devices' ||
        !id.startsWith('media_player.') ||
        !_echoEntities.containsKey(id)) {
      throw const FormatException(
          'Selecciona un Echo de la integración Alexa Devices.');
    }
    echoEntityId = id;
    await _saveConfiguration();
    notifyListeners();
  }

  Future<void> _saveConfiguration() {
    final contents = jsonEncode({
      'schemaVersion': 1,
      'endpoint': endpoint,
      'bindings': {
        'dormitorio/luz_techo': entityId,
        'pasillo/luz_pasillo': hallwayEntityId,
        'habitacion_vacia/luz_techo': secondRoomEntityId,
        'dormitorio/ventana_clima': weatherEntityId,
        'dormitorio/echo_dot': echoEntityId,
      },
      'presets': _presets.map((preset) => preset.toJson()).toList(),
      'lastOnLight': _lastOnLight?.toJson(),
      'lastOnLights': {
        for (final entry in _independentLights.entries)
          if (entry.value.lastOn != null)
            entry.key: entry.value.lastOn!.toJson(),
      },
      'gradualOnByEntity': _gradualOnByEntity,
    });
    _configurationWrites = _configurationWrites.catchError((Object _) {}).then(
      (_) async {
        final file = await _configFile();
        await file.parent.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(contents, flush: true);
        await temporary.rename(file.path);
      },
    );
    return _configurationWrites;
  }

  void _rememberLastOn(HomeAssistantLight light) {
    if (!light.isOn || light.entityId != entityId) return;
    final updated = HomeLightPreset.fromLight(
      light,
      id: 'ultimo',
      name: 'Último ajuste',
    );
    if (jsonEncode(updated.toJson()) == jsonEncode(_lastOnLight?.toJson())) {
      return;
    }
    _lastOnLight = updated;
    _configurationTimer?.cancel();
    _configurationTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_saveConfiguration().catchError((Object _) {}));
    });
  }

  void _rememberIndependentLastOn(HomeAssistantLight light) {
    if (!light.isOn ||
        light.entityId != hallwayEntityId &&
            light.entityId != secondRoomEntityId) {
      return;
    }
    final channel = _independentLights.putIfAbsent(
      light.entityId,
      _IndependentLightState.new,
    );
    final updated = HomeLightPreset.fromLight(
      light,
      id: 'ultimo',
      name: 'Último ajuste',
    );
    if (jsonEncode(updated.toJson()) == jsonEncode(channel.lastOn?.toJson())) {
      return;
    }
    channel.lastOn = updated;
    _configurationTimer?.cancel();
    _configurationTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_saveConfiguration().catchError((Object _) {}));
    });
  }

  bool _hasSettingChange(int? brightness, List<int>? rgb, int? temperature) =>
      brightness != null || rgb != null || temperature != null;

  void _prepareLightForRoom(
    String roomId, {
    int? brightness,
    List<int>? rgb,
    int? temperature,
  }) {
    final base = lightForRoom(roomId);
    if (!connected || base == null || !base.available || base.isOn) return;
    final prepared = HomeLightPreset(
      id: 'ultimo',
      name: 'Último ajuste',
      entityId: base.entityId,
      on: true,
      brightness: (brightness ?? base.brightness).clamp(1, 255),
      rgb: rgb ?? (temperature == null ? base.rgb : null),
      temperature: temperature ?? (rgb == null ? base.temperature : null),
      colorMode: rgb != null
          ? 'rgb'
          : temperature != null
              ? 'color_temp'
              : base.colorMode,
    );
    if (roomId == 'dormitorio') {
      _lastOnLight = prepared;
    } else {
      _independentLights
          .putIfAbsent(base.entityId, _IndependentLightState.new)
          .lastOn = prepared;
    }
    _configurationTimer?.cancel();
    _configurationTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_saveConfiguration().catchError((Object _) {}));
    });
    error = null;
    notifyListeners();
  }

  Future<void> savePreset(String name) => savePresetForRoom('dormitorio', name);

  Future<void> savePresetForRoom(String roomId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 50) {
      throw const FormatException('Ponle un nombre de hasta 50 caracteres.');
    }
    final light = lightForRoom(roomId);
    if (light == null || entityIdForRoom(roomId).isEmpty) {
      throw const FormatException('No hay una bombilla asociada.');
    }
    _presets.add(HomeLightPreset.fromLight(
      light,
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmed,
    ));
    await _saveConfiguration();
    notifyListeners();
  }

  Future<void> renamePreset(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 50) {
      throw const FormatException('Ponle un nombre de hasta 50 caracteres.');
    }
    final index = _presets.indexWhere((preset) => preset.id == id);
    if (index < 0) return;
    _presets[index] = _presets[index].withName(trimmed);
    await _saveConfiguration();
    notifyListeners();
  }

  Future<void> deletePreset(String id) async {
    _presets.removeWhere((preset) => preset.id == id);
    await _saveConfiguration();
    notifyListeners();
  }

  Future<void> applyPreset(HomeLightPreset preset) => setLight(
        on: selectedLight?.isOn ?? false,
        brightness: preset.brightness,
        rgb: preset.colorMode == 'color_temp' ? null : preset.rgb,
        temperature:
            preset.colorMode == 'color_temp' ? preset.temperature : null,
      );

  Future<void> applyPresetForRoom(String roomId, HomeLightPreset preset) =>
      setLightForRoom(
        roomId,
        on: lightForRoom(roomId)?.isOn ?? false,
        brightness: preset.brightness,
        rgb: preset.colorMode == 'color_temp' ? null : preset.rgb,
        temperature:
            preset.colorMode == 'color_temp' ? preset.temperature : null,
      );

  Future<void> setGradualOnEnabled(bool enabled) =>
      setGradualOnEnabledForRoom('dormitorio', enabled);

  Future<void> setGradualOnEnabledForRoom(String roomId, bool enabled) async {
    final id = entityIdForRoom(roomId);
    if (id.isEmpty) return;
    _gradualOnByEntity[id] = enabled;
    await _saveConfiguration();
    notifyListeners();
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
      try {
        final registry =
            await _request({'type': 'config/entity_registry/list_for_display'});
        _readEchoRegistry(registry['result']);
      } catch (_) {
        // La conexión y las luces siguen disponibles si falla el registro.
      }
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
        if (id is! String) return;
        final state = values['new_state'];
        if (_echoDomains.any((domain) => id.startsWith('$domain.'))) {
          if (state is Map) {
            _echoEntities[id] = HomeAssistantEchoEntity.fromState(
                state.cast<String, dynamic>());
          } else {
            _echoEntities.remove(id);
          }
          notifyListeners();
          return;
        }
        if (id.startsWith('weather.')) {
          if (state is Map) {
            final weather =
                HomeAssistantWeather.fromState(state.cast<String, dynamic>());
            _weathers[id] = weather;
            if (weather.available) _lastAvailableWeather[id] = weather;
          } else {
            _weathers.remove(id);
          }
          notifyListeners();
          return;
        }
        if (id == 'sun.sun') {
          _readSun(state);
          notifyListeners();
          return;
        }
        if (!id.startsWith('light.')) return;
        if (state is Map) {
          _lights[id] =
              HomeAssistantLight.fromState(state.cast<String, dynamic>());
          if (_previewLight == null) _rememberLastOn(_lights[id]!);
          if (_independentLights[id]?.preview == null) {
            _rememberIndependentLastOn(_lights[id]!);
          }
        } else {
          _lights.remove(id);
        }
        _reconcilePreview();
        _reconcileIndependentPreviews();
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
    _weathers.clear();
    _echoEntities.clear();
    for (final value in result) {
      if (value is! Map || value['entity_id'] is! String) continue;
      final id = value['entity_id'] as String;
      if (_echoDomains.any((domain) => id.startsWith('$domain.'))) {
        _echoEntities[id] =
            HomeAssistantEchoEntity.fromState(value.cast<String, dynamic>());
        continue;
      }
      if (id.startsWith('weather.')) {
        final weather =
            HomeAssistantWeather.fromState(value.cast<String, dynamic>());
        _weathers[id] = weather;
        if (weather.available) _lastAvailableWeather[id] = weather;
        continue;
      }
      if (id == 'sun.sun') {
        _readSun(value);
        continue;
      }
      if (!id.startsWith('light.')) continue;
      final light = HomeAssistantLight.fromState(value.cast<String, dynamic>());
      _lights[light.entityId] = light;
      if (_previewLight == null) _rememberLastOn(light);
      if (_independentLights[id]?.preview == null) {
        _rememberIndependentLastOn(light);
      }
    }
    if (weatherEntityId.isEmpty && _weathers.length == 1) {
      weatherEntityId = _weathers.keys.single;
      unawaited(_saveConfiguration().catchError((Object _) {}));
    }
    _reconcilePreview();
    _reconcileIndependentPreviews();
    notifyListeners();
  }

  static const _echoDomains = {
    'media_player',
    'notify',
    'switch',
    'select',
    'sensor',
    'binary_sensor',
    'button',
    'event',
    'todo',
  };

  void _readEchoRegistry(dynamic result) {
    if (result is! Map || result['entities'] is! List) return;
    _echoDeviceByEntity.clear();
    _echoPlatformByEntity.clear();
    for (final entry in result['entities'] as List) {
      if (entry is! Map) continue;
      final id = entry['ei'];
      if (id is! String) continue;
      final device = entry['di'];
      final platform = entry['pl'];
      if (device is String) _echoDeviceByEntity[id] = device;
      if (platform is String) _echoPlatformByEntity[id] = platform;
      if (platform == 'alexa_devices' &&
          id.startsWith('notify.') &&
          !_echoEntities.containsKey(id)) {
        _echoEntities[id] = HomeAssistantEchoEntity(
          entityId: id,
          name: entry['en'] as String? ?? id,
          state: 'on',
          attributes: const {},
        );
      }
    }
    notifyListeners();
  }

  Future<void> callEcho(
    String domain,
    String service, {
    String? entityId,
    Map<String, dynamic> data = const {},
  }) async {
    if (!connected || selectedEcho == null || echoDeviceId == null) {
      throw const FormatException(
          'El Echo no está conectado en Home Assistant.');
    }
    const allowed = <String, Set<String>>{
      'media_player': {
        'media_play',
        'media_pause',
        'media_stop',
        'media_next_track',
        'media_previous_track',
        'volume_set',
        'volume_mute',
        'select_source',
      },
      'notify': {'send_message'},
      'switch': {'turn_on', 'turn_off'},
      'select': {'select_option'},
      'button': {'press'},
      'alexa_devices': {'send_text_command'},
    };
    if (allowed[domain]?.contains(service) != true) {
      throw const FormatException('La función solicitada no está disponible.');
    }
    if (domain != 'alexa_devices' &&
        (entityId == null ||
            !echoEntities(domain)
                .any((entity) => entity.entityId == entityId))) {
      throw const FormatException('La entidad no pertenece al Echo asociado.');
    }
    final serviceData = <String, dynamic>{
      ...data,
      if (domain == 'alexa_devices') 'device_id': echoDeviceId,
      if (entityId != null && domain != 'notify') 'entity_id': entityId,
    };
    await _request({
      'type': 'call_service',
      'domain': domain,
      'service': service,
      'service_data': serviceData,
      if (domain == 'notify') 'target': {'entity_id': entityId},
    });
  }

  void _readSun(dynamic value) {
    if (value is! Map) return;
    if (value['state'] == 'above_horizon') _sunAboveHorizon = true;
    if (value['state'] == 'below_horizon') _sunAboveHorizon = false;
    final attributes = value['attributes'];
    if (attributes is Map && attributes['elevation'] is num) {
      _sunElevation = (attributes['elevation'] as num).toDouble();
    }
  }

  void previewLight({
    required bool on,
    int? brightness,
    List<int>? rgb,
    int? temperature,
    bool editing = true,
    double transitionSeconds = 0,
  }) {
    final base = selectedLight;
    if (!connected || base == null || !base.available) return;
    if (!base.isOn && _hasSettingChange(brightness, rgb, temperature)) {
      _prepareLightForRoom(
        'dormitorio',
        brightness: brightness,
        rgb: rgb,
        temperature: temperature,
      );
      return;
    }
    if (!on && base.isOn) _rememberLastOn(base);
    _previewLight = HomeAssistantLight(
      entityId: base.entityId,
      name: base.name,
      state: on ? 'on' : 'off',
      brightness: (brightness ?? base.brightness).clamp(1, 255),
      rgb: rgb ?? (temperature == null ? base.rgb : null),
      temperature: temperature ?? (rgb == null ? base.temperature : null),
      minTemperature: base.minTemperature,
      maxTemperature: base.maxTemperature,
      colorMode: rgb != null
          ? 'rgb'
          : temperature != null
              ? 'color_temp'
              : base.colorMode,
      colorModes: base.colorModes,
      supportedFeatures: base.supportedFeatures,
    );
    if (on) _rememberLastOn(_previewLight!);
    _previewHeld = editing;
    _desiredTransition = transitionSeconds;
    _desiredRevision++;
    error = null;
    notifyListeners();
    _sendTimer?.cancel();
    _sendTimer = Timer(const Duration(milliseconds: 220), () {
      unawaited(_flushLight().catchError((Object _) {}));
    });
  }

  Future<void> setLight({
    required bool on,
    int? brightness,
    List<int>? rgb,
    int? temperature,
  }) async {
    final light = selectedLight;
    if (!connected || light == null || !light.available) {
      throw const FormatException('La bombilla no está disponible.');
    }
    if (!light.isOn && _hasSettingChange(brightness, rgb, temperature)) {
      _prepareLightForRoom(
        'dormitorio',
        brightness: brightness,
        rgb: rgb,
        temperature: temperature,
      );
      _configurationTimer?.cancel();
      await _saveConfiguration();
      return;
    }
    previewLight(
      on: on,
      brightness: brightness,
      rgb: rgb,
      temperature: temperature,
      editing: false,
      transitionSeconds: 0,
    );
    await _flushLight();
  }

  Future<void> setHallwayLight({required bool on}) =>
      setLightForRoom('pasillo', on: on);

  Future<void> setSecondRoomLight({required bool on}) =>
      setLightForRoom('habitacion_vacia', on: on);

  void previewLightForRoom(
    String roomId, {
    required bool on,
    int? brightness,
    List<int>? rgb,
    int? temperature,
    bool editing = true,
    double transitionSeconds = 0,
  }) {
    if (roomId == 'dormitorio') {
      previewLight(
        on: on,
        brightness: brightness,
        rgb: rgb,
        temperature: temperature,
        editing: editing,
        transitionSeconds: transitionSeconds,
      );
      return;
    }
    final base = lightForRoom(roomId);
    if (!connected || base == null || !base.available) return;
    if (!base.isOn && _hasSettingChange(brightness, rgb, temperature)) {
      _prepareLightForRoom(
        roomId,
        brightness: brightness,
        rgb: rgb,
        temperature: temperature,
      );
      return;
    }
    final channel = _independentLights.putIfAbsent(
      base.entityId,
      _IndependentLightState.new,
    );
    if (!on && base.isOn) _rememberIndependentLastOn(base);
    channel.preview = HomeAssistantLight(
      entityId: base.entityId,
      name: base.name,
      state: on ? 'on' : 'off',
      brightness: (brightness ?? base.brightness).clamp(1, 255),
      rgb: rgb ?? (temperature == null ? base.rgb : null),
      temperature: temperature ?? (rgb == null ? base.temperature : null),
      minTemperature: base.minTemperature,
      maxTemperature: base.maxTemperature,
      colorMode: rgb != null
          ? 'rgb'
          : temperature != null
              ? 'color_temp'
              : base.colorMode,
      colorModes: base.colorModes,
      supportedFeatures: base.supportedFeatures,
    );
    if (on) _rememberIndependentLastOn(channel.preview!);
    channel.held = editing;
    channel.transition = transitionSeconds;
    channel.desiredRevision++;
    error = null;
    notifyListeners();
    channel.sendTimer?.cancel();
    channel.sendTimer = Timer(const Duration(milliseconds: 220), () {
      unawaited(
          _flushIndependentLight(base.entityId).catchError((Object _) {}));
    });
  }

  Future<void> setLightForRoom(
    String roomId, {
    required bool on,
    int? brightness,
    List<int>? rgb,
    int? temperature,
  }) async {
    if (roomId == 'dormitorio') {
      return setLight(
        on: on,
        brightness: brightness,
        rgb: rgb,
        temperature: temperature,
      );
    }
    final entity = entityIdForRoom(roomId);
    final light = lightForRoom(roomId);
    if (!connected || light == null || !light.available) {
      throw const FormatException('La bombilla no está disponible.');
    }
    if (!light.isOn && _hasSettingChange(brightness, rgb, temperature)) {
      _prepareLightForRoom(
        roomId,
        brightness: brightness,
        rgb: rgb,
        temperature: temperature,
      );
      _configurationTimer?.cancel();
      await _saveConfiguration();
      return;
    }
    previewLightForRoom(
      roomId,
      on: on,
      brightness: brightness,
      rgb: rgb,
      temperature: temperature,
      editing: false,
      transitionSeconds: 0,
    );
    await _flushIndependentLight(entity);
  }

  Future<void> _flushIndependentLight(String entity) {
    final channel = _independentLights[entity];
    if (channel == null) return Future<void>.value();
    channel.sendTimer?.cancel();
    if (channel.sending != null) return channel.sending!;
    final sending = _drainIndependentLight(entity, channel);
    channel.sending = sending;
    return sending.whenComplete(() {
      channel.sending = null;
      if (connected && channel.desiredRevision > channel.sentRevision) {
        unawaited(_flushIndependentLight(entity).catchError((Object _) {}));
      }
    });
  }

  Future<void> _drainIndependentLight(
    String entity,
    _IndependentLightState channel,
  ) async {
    try {
      while (connected && channel.sentRevision < channel.desiredRevision) {
        final revision = channel.desiredRevision;
        final desired = channel.preview;
        if (desired == null) return;
        channel.sentRevision = revision;
        final data = <String, dynamic>{'entity_id': entity};
        final gradualOn = desired.isOn && channel.transition > 0;
        if (!gradualOn &&
            desired.supportsTransition &&
            channel.transition > 0) {
          data['transition'] = channel.transition;
        }
        if (desired.isOn) {
          data['brightness'] = desired.brightness;
          if (desired.colorMode == 'color_temp' &&
              desired.temperature != null) {
            data['color_temp_kelvin'] = desired.temperature;
          } else if (desired.rgb != null) {
            data['rgb_color'] = desired.rgb;
          }
        }
        try {
          if (gradualOn) {
            final target = desired.brightness;
            final steps = target <= 5 ? 1 : 8;
            for (var step = 0; step < steps; step++) {
              if (!connected || revision != channel.desiredRevision) break;
              if (step > 0) {
                await Future<void>.delayed(Duration(
                  milliseconds: (powerFadeSeconds * 1000 / (steps - 1)).round(),
                ));
                if (!connected || revision != channel.desiredRevision) break;
              }
              final level = steps == 1
                  ? target
                  : 5 + ((target - 5) * step / (steps - 1)).round();
              await _request({
                'type': 'call_service',
                'domain': 'light',
                'service': 'turn_on',
                'service_data': {...data, 'brightness': level},
              });
            }
          } else {
            await _request({
              'type': 'call_service',
              'domain': 'light',
              'service': desired.isOn ? 'turn_on' : 'turn_off',
              'service_data': data,
            });
          }
        } catch (_) {
          if (!connected || revision == channel.desiredRevision) rethrow;
        }
      }
      _scheduleIndependentConfirmation(entity, channel);
    } catch (_) {
      channel.preview = null;
      channel.held = false;
      error = 'No se pudo enviar el cambio a la bombilla.';
      notifyListeners();
      rethrow;
    }
  }

  void _scheduleIndependentConfirmation(
    String entity,
    _IndependentLightState channel,
  ) {
    channel.confirmationTimer?.cancel();
    if (channel.preview == null || channel.held) return;
    channel.confirmationTimer =
        Timer(const Duration(milliseconds: 1500), () async {
      if (!connected || channel.preview == null || channel.held) return;
      try {
        final states = await _request({'type': 'get_states'});
        _readStates(states['result']);
      } catch (_) {
        // La suscripción seguirá recibiendo cambios cuando vuelva la conexión.
      }
      if (channel.preview == null || !connected || channel.held) return;
      channel.confirmationTimer = Timer(const Duration(seconds: 7), () {
        if (channel.preview == null || channel.held) return;
        channel.preview = null;
        error = 'La bombilla no confirmó el último ajuste.';
        notifyListeners();
      });
    });
  }

  Future<void> _flushLight() {
    _sendTimer?.cancel();
    if (_sendFuture != null) return _sendFuture!;
    final sending = _drainLightCommands();
    _sendFuture = sending;
    return sending.whenComplete(() {
      _sendFuture = null;
      if (connected && _desiredRevision > _sentRevision) {
        unawaited(_flushLight().catchError((Object _) {}));
      }
    });
  }

  Future<void> _drainLightCommands() async {
    try {
      while (connected && _sentRevision < _desiredRevision) {
        final revision = _desiredRevision;
        final desired = _previewLight;
        if (desired == null) return;
        _sentRevision = revision;
        final data = <String, dynamic>{'entity_id': entityId};
        final gradualOn = desired.isOn && _desiredTransition > 0;
        if (!gradualOn &&
            desired.supportsTransition &&
            _desiredTransition > 0) {
          data['transition'] = _desiredTransition;
        }
        if (desired.isOn) {
          data['brightness'] = desired.brightness;
          if (desired.colorMode == 'color_temp' &&
              desired.temperature != null) {
            data['color_temp_kelvin'] = desired.temperature;
          } else if (desired.rgb != null) {
            data['rgb_color'] = desired.rgb;
          }
        }
        try {
          if (gradualOn) {
            // La L530 ignora la transición al encender desde el estado apagado.
            // Se enciende muy tenue y se aumenta el brillo desde Todo.
            final target = desired.brightness;
            final steps = target <= 5 ? 1 : 8;
            for (var step = 0; step < steps; step++) {
              if (!connected || revision != _desiredRevision) break;
              if (step > 0) {
                await Future<void>.delayed(Duration(
                  milliseconds: (powerFadeSeconds * 1000 / (steps - 1)).round(),
                ));
                if (!connected || revision != _desiredRevision) break;
              }
              final brightness = steps == 1
                  ? target
                  : 5 + ((target - 5) * step / (steps - 1)).round();
              await _request({
                'type': 'call_service',
                'domain': 'light',
                'service': 'turn_on',
                'service_data': {...data, 'brightness': brightness},
              });
            }
          } else {
            await _request({
              'type': 'call_service',
              'domain': 'light',
              'service': desired.isOn ? 'turn_on' : 'turn_off',
              'service_data': data,
            });
          }
        } catch (_) {
          if (!connected || revision == _desiredRevision) rethrow;
        }
      }
      _scheduleConfirmation();
    } catch (_) {
      _previewLight = null;
      _previewHeld = false;
      error = 'No se pudo enviar el cambio a la bombilla.';
      notifyListeners();
      rethrow;
    }
  }

  void _scheduleConfirmation() {
    _confirmationTimer?.cancel();
    if (_previewLight == null || _previewHeld) return;
    _confirmationTimer = Timer(const Duration(milliseconds: 1500), () async {
      if (!connected || _previewLight == null || _previewHeld) return;
      try {
        final states = await _request({'type': 'get_states'});
        _readStates(states['result']);
      } catch (_) {
        // La suscripción sigue recibiendo cambios cuando vuelve la conexión.
      }
      if (_previewLight == null || !connected || _previewHeld) return;
      _confirmationTimer = Timer(const Duration(seconds: 7), () {
        if (_previewLight == null || _previewHeld) return;
        _previewLight = null;
        _previewHeld = false;
        error = 'La bombilla no confirmó el último ajuste.';
        notifyListeners();
      });
    });
  }

  void _reconcilePreview() {
    final desired = _previewLight;
    final current = _lights[entityId];
    if (_previewHeld ||
        desired == null ||
        current == null ||
        _sentRevision < _desiredRevision ||
        !current.available) {
      return;
    }
    if (current.isOn != desired.isOn) {
      return;
    }
    if (desired.isOn) {
      if ((current.brightness - desired.brightness).abs() > 5) {
        return;
      }
      if (desired.colorMode == 'color_temp') {
        if (current.temperature == null ||
            desired.temperature == null ||
            (current.temperature! - desired.temperature!).abs() > 150) {
          return;
        }
      } else if (desired.rgb != null) {
        if (current.rgb == null ||
            List.generate(3, (index) => index).any((index) =>
                (current.rgb![index] - desired.rgb![index]).abs() > 35)) {
          return;
        }
      }
    }
    _confirmationTimer?.cancel();
    _previewLight = null;
    _previewHeld = false;
  }

  void _reconcileIndependentPreviews() {
    for (final entry in _independentLights.entries) {
      final channel = entry.value;
      final desired = channel.preview;
      final current = _lights[entry.key];
      if (channel.held ||
          desired == null ||
          current == null ||
          channel.sentRevision < channel.desiredRevision ||
          !current.available ||
          current.isOn != desired.isOn) {
        continue;
      }
      if (desired.isOn) {
        if ((current.brightness - desired.brightness).abs() > 5) continue;
        if (desired.colorMode == 'color_temp') {
          if (current.temperature == null ||
              desired.temperature == null ||
              (current.temperature! - desired.temperature!).abs() > 150) {
            continue;
          }
        } else if (desired.rgb != null) {
          if (current.rgb == null ||
              List.generate(3, (index) => index).any((index) =>
                  (current.rgb![index] - desired.rgb![index]).abs() > 35)) {
            continue;
          }
        }
      }
      channel.confirmationTimer?.cancel();
      channel.preview = null;
      channel.held = false;
      _rememberIndependentLastOn(current);
    }
  }

  void _lostConnection() {
    if (_disposed) return;
    connected = false;
    _sendTimer?.cancel();
    _confirmationTimer?.cancel();
    _previewLight = null;
    _previewHeld = false;
    _desiredTransition = 0;
    _sentRevision = _desiredRevision;
    for (final channel in _independentLights.values) {
      channel.clear();
    }
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
    _sendTimer?.cancel();
    _confirmationTimer?.cancel();
    _previewLight = null;
    _previewHeld = false;
    _desiredTransition = 0;
    _sentRevision = _desiredRevision;
    for (final channel in _independentLights.values) {
      channel.clear();
    }
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
    _sendTimer?.cancel();
    _confirmationTimer?.cancel();
    for (final channel in _independentLights.values) {
      channel.clear();
    }
    final hasPendingConfiguration = _configurationTimer?.isActive == true;
    _configurationTimer?.cancel();
    if (hasPendingConfiguration && endpoint.isNotEmpty) {
      unawaited(_saveConfiguration().catchError((Object _) {}));
    }
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    unawaited(_socket?.close() ?? Future<void>.value());
    super.dispose();
  }
}
