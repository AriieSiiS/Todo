import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

abstract class SteamSecretStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class _SteamSecureStore implements SteamSecretStore {
  static const _key = 'todo.steam.connection.v1';
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class SteamService {
  SteamService({SteamSecretStore? store, http.Client? client})
      : _store = store ?? _SteamSecureStore(),
        _client = client ?? http.Client();

  final SteamSecretStore _store;
  final http.Client _client;
  static const _ttl = Duration(minutes: 10);
  final _cache = <String, (DateTime, dynamic)>{};
  int _revision = 0;

  Future<Map<String, dynamic>?> _configuration() async {
    try {
      final raw = await _store.read();
      return raw == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      throw const FormatException(
          'No se pudo leer la conexión de Steam del almacenamiento seguro.');
    }
  }

  Future<String?> profile() async =>
      (await _configuration())?['steamid'] as String?;

  static String normalizeProfile(String value) {
    var id = value.trim();
    if (!RegExp(r'^\d{17}$').hasMatch(id)) {
      final uri = Uri.tryParse(id);
      final segments =
          uri?.pathSegments.where((part) => part.isNotEmpty).toList();
      if (uri?.scheme == 'https' &&
          uri?.host == 'steamcommunity.com' &&
          segments?.length == 2 &&
          segments![0] == 'profiles') {
        id = segments[1];
      }
    }
    if (!RegExp(r'^7656119\d{10}$').hasMatch(id)) {
      throw const FormatException(
          'Introduce el SteamID de 17 cifras o el enlace del perfil con /profiles/.');
    }
    return id;
  }

  Future<List<Map<String, dynamic>>> connect(String profile, String key) async {
    final id = normalizeProfile(profile);
    final old = await _configuration();
    final apiKey =
        key.trim().isEmpty ? (old?['key'] as String? ?? '') : key.trim();
    if (!RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(apiKey)) {
      throw const FormatException(
          'La clave de Steam debe contener 32 caracteres hexadecimales.');
    }
    final revision = ++_revision;
    _cache.clear();
    final config = <String, dynamic>{
      'steamid': id,
      'key': apiKey,
      'links': old?['steamid'] == id ? (old?['links'] ?? {}) : {},
      'linkedGames': old?['steamid'] == id ? (old?['linkedGames'] ?? {}) : {},
    };
    final games = await _fetchGames(config);
    _checkRevision(revision);
    try {
      await _store.write(jsonEncode(config));
    } catch (_) {
      throw const FormatException(
          'Steam respondió, pero no se pudo guardar la clave en el almacenamiento seguro.');
    }
    _cache['games'] = (DateTime.now(), games);
    return games;
  }

  Future<void> disconnect() async {
    ++_revision;
    _cache.clear();
    try {
      await _store.delete();
    } catch (_) {
      throw const FormatException(
          'No se pudo eliminar la conexión del almacenamiento seguro.');
    }
  }

  Future<Map<String, dynamic>> _requiredConfiguration() async {
    final config = await _configuration();
    if (config == null) {
      throw const FormatException(
          'Conecta Steam en Ajustes → Steam antes de consultar tus juegos.');
    }
    return config;
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, String> query,
      Map<String, dynamic> config) async {
    try {
      final request =
          http.Request('GET', Uri.https('api.steampowered.com', path, query))
            ..followRedirects = false
            ..headers['x-webapi-key'] = config['key'] as String;
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const FormatException(
            'Steam rechazó la consulta. Revisa la clave y la privacidad de los detalles de juegos.');
      }
      if (response.statusCode == 429) {
        throw const FormatException(
            'Steam ha limitado las consultas. Espera un poco antes de actualizar.');
      }
      if (response.statusCode != 200) {
        throw const FormatException(
            'Steam no pudo atender la consulta. Vuelve a intentarlo más tarde.');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) throw const FormatException();
      return data;
    } on FormatException catch (error) {
      if (error.message.startsWith('Steam ')) rethrow;
      throw const FormatException(
          'Steam devolvió una respuesta que no se pudo interpretar.');
    } catch (_) {
      throw const FormatException(
          'No se pudo conectar con Steam. Comprueba la conexión y vuelve a intentarlo.');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchGames(
      Map<String, dynamic> config) async {
    final data = await _get(
        '/IPlayerService/GetOwnedGames/v1/',
        {
          'steamid': config['steamid'] as String,
          'include_appinfo': 'true',
          'include_played_free_games': 'true',
        },
        config);
    final response = data['response'];
    if (response is! Map ||
        response['game_count'] is! num ||
        (response['game_count'] != 0 && response['games'] is! List)) {
      throw const FormatException(
          'Steam no permite consultar la biblioteca. Revisa la privacidad del perfil y de los detalles de juegos.');
    }
    final queriedAt = DateTime.now().toUtc().toIso8601String();
    return [
      for (final game in response['games'] as List? ?? [])
        {
          'appid': game['appid'],
          'name': game['name'],
          'playtime_minutes': game['playtime_forever'],
          'recent_minutes': game['playtime_2weeks'],
          'last_played': game['rtime_last_played'],
          'from_owned_games': true,
          'queried_at': queriedAt,
        },
      for (final game in (config['linkedGames'] as Map? ?? {}).values)
        if (!(response['games'] as List? ?? [])
            .any((owned) => owned['appid'] == game['appid']))
          {
            'appid': game['appid'],
            'name': game['name'],
            'playtime_minutes': null,
            'recent_minutes': null,
            'last_played': null,
            'from_owned_games': false,
            'queried_at': queriedAt,
          },
    ]..sort((a, b) => (a['name'] as String? ?? '')
        .toLowerCase()
        .compareTo((b['name'] as String? ?? '').toLowerCase()));
  }

  dynamic _cached(String key, bool refresh) {
    final entry = _cache[key];
    return !refresh &&
            entry != null &&
            DateTime.now().difference(entry.$1) < _ttl
        ? entry.$2
        : null;
  }

  void _checkRevision(int revision) {
    if (_revision != revision) {
      throw const FormatException(
          'La conexión de Steam ha cambiado. Repite la consulta.');
    }
  }

  Future<List<Map<String, dynamic>>> games({bool refresh = false}) async {
    final revision = _revision;
    final config = await _requiredConfiguration();
    final cached = _cached('games', refresh);
    if (cached != null) return cached as List<Map<String, dynamic>>;
    final result = await _fetchGames(config);
    _checkRevision(revision);
    _cache['games'] = (DateTime.now(), result);
    return result;
  }

  Future<Map<String, dynamic>> achievements(int appId,
      {bool refresh = false}) async {
    if (appId < 1) {
      throw const FormatException('El identificador del juego no es válido.');
    }
    final revision = _revision;
    final config = await _requiredConfiguration();
    final cached = _cached('app:$appId', refresh);
    if (cached != null) return cached as Map<String, dynamic>;
    final ownedGame =
        (await games()).where((game) => game['appid'] == appId).firstOrNull;
    // Las tres consultas comparten un límite de seis segundos por petición.
    final responses = await Future.wait([
      _get('/ISteamUserStats/GetSchemaForGame/v2/',
          {'appid': '$appId', 'l': 'spanish'}, config),
      _get(
              '/ISteamUserStats/GetPlayerAchievements/v1/',
              {
                'appid': '$appId',
                'steamid': config['steamid'] as String,
                'l': 'spanish',
              },
              config)
          .then<Map<String, dynamic>>((value) => value,
              onError: (Object error) => {'failure': error}),
      _get('/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v2/',
              {'gameid': '$appId'}, config)
          .then<Map<String, dynamic>>((value) => value,
              onError: (Object _) => <String, dynamic>{}),
    ]);
    final schema = responses[0]['game'];
    if (schema is! Map || schema['gameName'] is! String) {
      throw const FormatException(
          'Steam no ofrece información de logros para este juego.');
    }
    final definitions =
        (schema['availableGameStats'] as Map?)?['achievements'] as List? ?? [];
    final player = responses[1]['playerstats'];
    if (definitions.isNotEmpty &&
        (player is! Map ||
            player['success'] != true ||
            player['achievements'] is! List)) {
      throw const FormatException(
          'No se pudieron consultar tus logros. Revisa la privacidad de los detalles de juegos y vuelve a intentarlo.');
    }
    final states = <String, Map>{
      for (final item
          in (player is Map ? player['achievements'] as List? : null) ?? [])
        item['apiname'] as String: item as Map,
    };
    final percentages = <String, dynamic>{
      for (final item in (responses[2]['achievementpercentages']
              as Map?)?['achievements'] as List? ??
          [])
        item['name'] as String: item['percent'],
    };
    // La API oculta la descripción de los logros secretos; la página pública
    // de logros del juego sí la muestra, así que se usa como complemento.
    final needsPublic = definitions.isNotEmpty;
    final publicPage =
        needsPublic ? await _publicAchievements(appId) : const {};
    final achievements = <Map<String, dynamic>>[
      for (final item in definitions)
        {
          'id': item['name'],
          'name': item['displayName'] ?? item['name'],
          'description': '${item['description'] ?? ''}'.trim().isNotEmpty
              ? item['description']
              : publicPage[item['name']]?['description'] ?? '',
          'hidden': item['hidden'] == 1,
          'unlocked': states[item['name']]?['achieved'] is num
              ? states[item['name']]!['achieved'] == 1
              : null,
          'unlock_time': states[item['name']]?['unlocktime'],
          'global_percent': _percentage(percentages[item['name']]),
          'icon_url': publicPage[item['name']]?['icon_achieved'] ??
              _iconUrl(appId, item['icon']),
          'icon_gray_url': publicPage[item['name']]?['icon_unachieved'] ??
              _iconUrl(appId, item['icongray']),
        },
    ];
    await _saveIcons(appId, achievements);
    final unlocked =
        achievements.where((item) => item['unlocked'] == true).length;
    final known = achievements.every((item) => item['unlocked'] != null);
    final result = <String, dynamic>{
      'appid': appId,
      'name': ownedGame?['name'] ?? schema['gameName'],
      'total': achievements.length,
      'unlocked': unlocked,
      'completion_percent': achievements.isNotEmpty && known
          ? unlocked * 100 / achievements.length
          : null,
      'achievements': achievements,
      'queried_at': DateTime.now().toUtc().toIso8601String(),
    };
    _checkRevision(revision);
    _cache['app:$appId'] = (DateTime.now(), result);
    await _saveResult(appId, result);
    return result;
  }

  /// Algunos juegos devuelven solo el nombre del archivo del icono en lugar de
  /// la dirección completa.
  static String? _iconUrl(int appId, Object? raw) {
    final value = raw is String ? raw.trim() : '';
    if (value.isEmpty) return null;
    if (value.contains('://')) return value;
    if (!RegExp(r'^[\w.\-]+$').hasMatch(value)) return null;
    return 'https://shared.fastly.steamstatic.com/community_assets/images/apps/'
        '$appId/${value.contains('.') ? value : '$value.jpg'}';
  }

  /// Lee la página pública de logros del juego (descripciones de los logros
  /// ocultos e iconos). Un fallo devuelve un mapa vacío.
  Future<Map<String, Map<String, String>>> _publicAchievements(
      int appId) async {
    try {
      final response = await _client.get(
        Uri.https('steamcommunity.com', '/stats/$appId/achievements'),
        headers: {
          'Accept-Language': 'es-ES,es;q=0.9',
          'Cookie': 'Steam_Language=spanish',
        },
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const {};
      final page = utf8.decode(response.bodyBytes, allowMalformed: true);
      final text = page.replaceAll(r'\"', '"');
      final entry = RegExp(r'"api_name":"((?:[^"\\]|\\.)*)","name":"'
          r'((?:[^"\\]|\\.)*)","description":"((?:[^"\\]|\\.)*)"'
          r'(?:(?!"api_name").)*?"icon_achieved":"([^"]*)","icon_unachieved":'
          r'"([^"]*)"', dotAll: true);
      String decode(String value) {
        try {
          return jsonDecode('"$value"') as String;
        } catch (_) {
          return value;
        }
      }

      return {
        for (final match in entry.allMatches(text))
          decode(match.group(1)!): {
            'description': decode(match.group(3)!).trim(),
            'icon_achieved': match.group(4)!,
            'icon_unachieved': match.group(5)!,
          },
      };
    } catch (_) {
      return const {};
    }
  }

  static File _resultFile(int appId) => File(
      '${_iconsDirectory(appId).path}${Platform.pathSeparator}logros.json');

  Future<void> _saveResult(int appId, Map<String, dynamic> result) async {
    try {
      final file = _resultFile(appId);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(result));
    } catch (_) {}
  }

  /// Últimos logros guardados en disco del juego enlazado, para mostrarlos al
  /// instante mientras se consulta Steam. No usa la red.
  Future<Map<String, dynamic>?> savedAchievements(String itemId) async {
    try {
      final appId = ((await _configuration())?['links'] as Map?)?[itemId];
      if (appId is! int) return null;
      final file = _resultFile(appId);
      if (!file.existsSync()) return null;
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, dynamic> && data['achievements'] is List
          ? data
          : null;
    } catch (_) {
      return null;
    }
  }

  static final _iconHosts = RegExp(
      r'(^|\.)(steamstatic\.com|akamaihd\.net|steamcommunity\.com|steampowered\.com)$');

  /// Carpeta local donde se conservan los iconos de los logros de cada juego.
  static Directory _iconsDirectory(int appId) {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final documents = Directory('$home${Platform.pathSeparator}Documents');
    final base = documents.existsSync()
        ? '${documents.path}${Platform.pathSeparator}Todo'
        : home;
    return Directory(
        '$base${Platform.pathSeparator}steam_icons${Platform.pathSeparator}$appId');
  }

  /// Descarga una sola vez los iconos y añade sus rutas locales a cada logro.
  /// Un fallo al descargar nunca impide mostrar los logros.
  Future<void> _saveIcons(
      int appId, List<Map<String, dynamic>> achievements) async {
    try {
      final directory = _iconsDirectory(appId);
      final tasks = <Future<void> Function()>[];
      for (final item in achievements) {
        for (final (urlKey, pathKey) in const [
          ('icon_url', 'icon_path'),
          ('icon_gray_url', 'icon_gray_path'),
        ]) {
          final raw = item.remove(urlKey);
          var uri = raw is String ? Uri.tryParse(raw) : null;
          // Algunos juegos devuelven solo el nombre del archivo, y otros aún
          // usan http: se completa la dirección y se fuerza https.
          if (raw is String &&
              RegExp(r'^[0-9a-f]{20,}(\.\w+)?$').hasMatch(raw)) {
            uri = Uri.https('shared.fastly.steamstatic.com',
                '/community_assets/images/apps/$appId/${raw.contains('.') ? raw : '$raw.jpg'}');
          } else if (uri != null && uri.scheme == 'http') {
            uri = uri.replace(scheme: 'https');
          }
          if (uri == null ||
              uri.scheme != 'https' ||
              !_iconHosts.hasMatch(uri.host)) {
            continue;
          }
          final address = uri;
          final name =
              uri.pathSegments.last.replaceAll(RegExp(r'[^\w.\-]'), '');
          if (name.isEmpty) continue;
          final file = File('${directory.path}${Platform.pathSeparator}$name');
          if (file.existsSync() && file.lengthSync() > 0) {
            item[pathKey] = file.path;
            continue;
          }
          tasks.add(() async {
            try {
              final response = await _client
                  .get(address)
                  .timeout(const Duration(seconds: 6));
              if (response.statusCode != 200 ||
                  response.bodyBytes.isEmpty ||
                  response.bodyBytes.length > 1024 * 1024) {
                return;
              }
              await directory.create(recursive: true);
              await file.writeAsBytes(response.bodyBytes);
              item[pathKey] = file.path;
            } catch (_) {}
          });
        }
      }
      for (var i = 0; i < tasks.length; i += 8) {
        await Future.wait(tasks.skip(i).take(8).map((task) => task()));
      }
    } catch (_) {}
  }

  static String _titleKey(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

  static num? _percentage(Object? value) {
    final percent =
        value is num ? value : num.tryParse(value?.toString() ?? '');
    return percent != null && percent.isFinite && percent >= 0 && percent <= 100
        ? percent
        : null;
  }

  Future<int?> linkedApp(
      String itemId, String title, List<Map<String, dynamic>> games) async {
    final config = await _configuration();
    final linked = (config?['links'] as Map?)?[itemId];
    if (linked is int && games.any((game) => game['appid'] == linked)) {
      return linked;
    }
    final matches = games
        .where((game) =>
            _titleKey(game['name'] as String? ?? '') == _titleKey(title))
        .toList();
    return matches.length == 1 ? matches.single['appid'] as int : null;
  }

  Map<String, dynamic> _binding(Map<String, dynamic> config, String itemId) {
    final appId = (config['links'] as Map?)?[itemId];
    final name = (config['linkedGames'] as Map?)?[appId?.toString()]?['name'];
    final binding = <String, dynamic>{
      'item_id': itemId,
      'appid': appId,
      'name': name
    };
    return {
      ...binding,
      'link_version': sha256
          .convert(utf8.encode(jsonEncode({
            'steamid': config['steamid'],
            ...binding,
          })))
          .toString()
    };
  }

  Future<Map<String, dynamic>> binding(String itemId) async =>
      _binding(await _requiredConfiguration(), itemId);

  Future<void> link(String itemId, int appId,
      {String? title, String? expectedVersion}) async {
    final revision = _revision;
    final config = await _requiredConfiguration();
    if (expectedVersion != null &&
        expectedVersion != _binding(config, itemId)['link_version']) {
      throw const FormatException(
          'El vínculo de Steam cambió desde la consulta. Vuelve a consultarlo.');
    }
    final game =
        (await games()).where((game) => game['appid'] == appId).firstOrNull;
    final stats = game == null ? await achievements(appId) : null;
    if (game == null &&
        (stats!['total'] == 0 ||
            !(stats['achievements'] as List)
                .any((achievement) => achievement['unlocked'] != null))) {
      throw const FormatException(
          'Steam no permite verificar tus logros para enlazar este juego.');
    }
    final links = Map<String, dynamic>.from(config['links'] as Map? ?? {});
    final linkedGames =
        Map<String, dynamic>.from(config['linkedGames'] as Map? ?? {});
    links[itemId] = appId;
    linkedGames['$appId'] = {
      'appid': appId,
      'name': title?.trim().isNotEmpty == true
          ? title!.trim()
          : game?['name'] ?? stats!['name']
    };
    _checkRevision(revision);
    await _store.write(
        jsonEncode({...config, 'links': links, 'linkedGames': linkedGames}));
    _cache.remove('games');
    _cache.remove('app:$appId');
  }

  Future<Map<String, dynamic>> agentQuery(
      String name, Map<String, dynamic> arguments) async {
    final fields = name == 'get_steam_games'
        ? {'query', 'offset', 'limit', 'refresh'}
        : {'appid', 'refresh'};
    if (!{'get_steam_games', 'get_steam_achievements'}.contains(name) ||
        arguments.keys.any((key) => !fields.contains(key)) ||
        (arguments.containsKey('refresh') && arguments['refresh'] is! bool)) {
      throw const FormatException(
          'Los argumentos de la consulta de Steam no son válidos.');
    }
    final refresh = arguments['refresh'] == true;
    if (name == 'get_steam_achievements') {
      final appId = arguments['appid'];
      if (appId is! int || appId < 1 || appId > 4294967295) {
        throw const FormatException('El identificador del juego no es válido.');
      }
      return {
        ...await achievements(appId, refresh: refresh),
        'source': 'steam'
      };
    }
    final offset = arguments['offset'] ?? 0;
    final limit = arguments['limit'] ?? 50;
    final query = arguments['query'] ?? '';
    if (offset is! int ||
        offset < 0 ||
        limit is! int ||
        limit < 1 ||
        limit > 100 ||
        query is! String) {
      throw const FormatException(
          'La búsqueda o la página de juegos no es válida.');
    }
    final selected = (await games(refresh: refresh))
        .where((game) => (game['name'] as String? ?? '')
            .toLowerCase()
            .contains(query.trim().toLowerCase()))
        .toList();
    final page = selected.skip(offset).take(limit).toList();
    return {
      'games': page,
      'total': selected.length,
      'next_offset':
          offset + page.length < selected.length ? offset + page.length : null,
      'source': 'steam',
      'queried_at': (_cache['games']!.$1).toUtc().toIso8601String(),
    };
  }

  void dispose() => _client.close();
}
