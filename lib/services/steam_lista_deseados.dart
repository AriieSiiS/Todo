import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'steam_service.dart';

/// Almacén del token de sesión de Steam. La clave Web API no sirve para el
/// plan familiar ni para modificar la lista de deseados.
abstract class SteamTokenStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class _TokenSeguro implements SteamTokenStore {
  static const _key = 'todo.steam.webtoken.v1';
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// Error de autenticación: el token falta, ha caducado o Steam lo rechaza.
class SteamTokenException implements Exception {
  const SteamTokenException(this.message, {this.falta = false});
  final String message;

  /// Aún no se ha guardado ningún token: no es un error que destacar.
  final bool falta;
  @override
  String toString() => message;
}

/// Juego del plan familiar presente en la lista de deseados.
class JuegoCoincidente {
  const JuegoCoincidente({required this.appId, required this.name});
  final int appId;
  final String name;
  String get url => 'https://store.steampowered.com/app/$appId/';
}

class ResultadoLimpieza {
  const ResultadoLimpieza({
    required this.quitados,
    required this.fallos,
    required this.fecha,
    this.archivo,
  });
  final List<JuegoCoincidente> quitados;
  final List<(JuegoCoincidente, String)> fallos;
  final DateTime fecha;
  final String? archivo;

  int get total => quitados.length + fallos.length;

  /// Texto que se copia y se guarda en el archivo con fecha.
  String get texto {
    final buffer = StringBuffer();
    if (total == 0) {
      buffer.writeln(
          'No había juegos del plan familiar en tu lista de deseados.');
      return buffer.toString();
    }
    buffer.writeln(quitados.isEmpty
        ? 'Había $total juegos del plan familiar en tu lista de deseados; no se pudo quitar ninguno.'
        : fallos.isEmpty
            ? 'Había $total juegos del plan familiar en tu lista de deseados; se han quitado.'
            : 'Había $total juegos del plan familiar en tu lista de deseados; se han quitado ${quitados.length}.');
    if (quitados.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Quitados:');
      for (final juego in quitados) {
        buffer.writeln('- ${juego.name} — ${juego.url}');
      }
    }
    if (fallos.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('No se pudieron quitar:');
      for (final (juego, motivo) in fallos) {
        buffer.writeln('- ${juego.name} — ${juego.url} ($motivo)');
      }
    }
    return buffer.toString();
  }
}

/// Cruza la lista de deseados con el plan familiar y quita los coincidentes.
class SteamListaDeseados {
  SteamListaDeseados({
    required this.steam,
    SteamTokenStore? store,
    http.Client? client,
    this.retardo = const Duration(milliseconds: 600),
    Directory? carpeta,
    DateTime Function()? reloj,
  })  : _store = store ?? _TokenSeguro(),
        _client = client ?? http.Client(),
        _carpeta = carpeta,
        _reloj = reloj ?? DateTime.now;

  final SteamService steam;
  final SteamTokenStore _store;
  final http.Client _client;
  final Duration retardo;
  final Directory? _carpeta;
  final DateTime Function() _reloj;

  static final _jwt = RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+');

  /// Acepta el token o el texto completo de la página que lo muestra.
  static String extraerToken(String texto) {
    final match = _jwt.firstMatch(texto.trim());
    if (match == null) {
      throw const FormatException(
          'No se encontró ningún token en el texto pegado. Copia la página completa o el valor de «webapi_token».');
    }
    return match.group(0)!;
  }

  static Map<String, dynamic> _carga(String token) {
    try {
      final parte = token.split('.')[1];
      final datos = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parte))));
      if (datos is Map<String, dynamic>) return datos;
    } catch (_) {}
    throw const FormatException('El token de Steam no tiene un formato válido.');
  }

  /// Fecha de caducidad del token, si la incluye.
  static DateTime? caducidad(String token) {
    final exp = _carga(token)['exp'];
    return exp is num
        ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000)
        : null;
  }

  /// Comprueba el token pegado y lo guarda. Devuelve su caducidad.
  Future<DateTime?> guardarToken(String texto) async {
    final token = extraerToken(texto);
    final carga = _carga(token);
    final perfil = await steam.profile();
    if (perfil != null && carga['sub'] != null && '${carga['sub']}' != perfil) {
      throw const FormatException(
          'El token pertenece a otra cuenta de Steam distinta del perfil conectado.');
    }
    final fin = caducidad(token);
    if (fin != null && !fin.isAfter(_reloj())) {
      throw const SteamTokenException(
          'Ese token de Steam ya ha caducado. Vuelve a abrir la página y copia uno nuevo.');
    }
    try {
      await _store.write(token);
    } catch (_) {
      throw const FormatException(
          'No se pudo guardar el token en el almacenamiento seguro.');
    }
    return fin;
  }

  /// Token guardado y vigente; si falta o ha caducado lanza
  /// [SteamTokenException].
  Future<String> tokenVigente() async {
    String? token;
    try {
      token = await _store.read();
    } catch (_) {}
    if (token == null || token.isEmpty) {
      throw const SteamTokenException(
          'Falta el token de sesión de Steam. Pega uno nuevo para continuar.',
          falta: true);
    }
    final fin = caducidad(token);
    if (fin != null &&
        !fin.isAfter(_reloj().add(const Duration(minutes: 2)))) {
      throw const SteamTokenException(
          'El token de sesión de Steam ha caducado. Pega uno nuevo para continuar.');
    }
    return token;
  }

  Future<Map<String, dynamic>> _llamar(String metodo, String ruta,
      Map<String, String> datos, String token) async {
    http.Response respuesta;
    try {
      if (metodo == 'GET') {
        respuesta = await _client
            .get(Uri.https('api.steampowered.com', ruta,
                {...datos, 'access_token': token}))
            .timeout(const Duration(seconds: 15));
      } else {
        respuesta = await _client
            .post(
                Uri.https(
                    'api.steampowered.com', ruta, {'access_token': token}),
                body: datos)
            .timeout(const Duration(seconds: 15));
      }
    } catch (_) {
      throw const FormatException(
          'No se pudo conectar con Steam. Comprueba la conexión y vuelve a intentarlo.');
    }
    if (respuesta.statusCode == 401 || respuesta.statusCode == 403) {
      throw const SteamTokenException(
          'Steam ha rechazado el token de sesión; seguramente ha caducado. Pega uno nuevo para continuar.');
    }
    if (respuesta.statusCode == 429) {
      throw const FormatException(
          'Steam ha limitado las consultas. Espera un poco y vuelve a intentarlo.');
    }
    final resultado = respuesta.headers['x-eresult'];
    if (respuesta.statusCode != 200 ||
        (resultado != null && resultado != '1')) {
      throw FormatException(resultado == null
          ? 'Steam respondió con el código ${respuesta.statusCode}.'
          : 'Steam no lo aceptó (resultado $resultado).');
    }
    try {
      final datos = jsonDecode(utf8.decode(respuesta.bodyBytes));
      return datos is Map<String, dynamic>
          ? (datos['response'] as Map?)?.cast<String, dynamic>() ?? {}
          : {};
    } catch (_) {
      throw const FormatException(
          'Steam devolvió una respuesta que no se pudo interpretar.');
    }
  }

  /// Descarga ambas listas y devuelve los juegos del plan familiar que están
  /// en la lista de deseados, ordenados por nombre.
  Future<List<JuegoCoincidente>> coincidencias(String token) async {
    final perfil = await steam.profile();
    if (perfil == null) {
      throw const FormatException(
          'Conecta Steam en Ajustes → Steam antes de limpiar la lista de deseados.');
    }
    final familia = await _llamar('GET',
        '/IFamilyGroupsService/GetFamilyGroupForUser/v1/', {'steamid': perfil},
        token);
    final grupo = familia['family_groupid'];
    if (familia['is_not_member_of_any_group'] == true ||
        grupo == null ||
        '$grupo' == '0') {
      throw const FormatException(
          'Tu cuenta de Steam no pertenece a ningún grupo familiar.');
    }
    final compartidos = await _llamar(
        'GET',
        '/IFamilyGroupsService/GetSharedLibraryApps/v1/',
        {
          'family_groupid': '$grupo',
          'steamid': perfil,
          'include_own': 'false',
          'include_excluded': 'false',
          'include_free': 'false',
          'include_non_games': 'false',
          'language': 'spanish',
        },
        token);
    final apps = compartidos['apps'];
    if (apps is! List) {
      throw const FormatException(
          'Steam no devolvió los juegos del plan familiar.');
    }
    final deseados = await _llamar('GET',
        '/IWishlistService/GetWishlist/v1/', {'steamid': perfil}, token);
    final items = deseados['items'];
    if (items is! List) {
      throw const FormatException(
          'Steam no devolvió la lista de deseados. Revisa su privacidad.');
    }
    final enLista = {
      for (final item in items)
        if (item is Map && item['appid'] is num) (item['appid'] as num).toInt()
    };
    final vistos = <int>{};
    return [
      for (final app in apps)
        if (app is Map &&
            app['appid'] is num &&
            enLista.contains((app['appid'] as num).toInt()) &&
            vistos.add((app['appid'] as num).toInt()))
          JuegoCoincidente(
              appId: (app['appid'] as num).toInt(),
              name: '${app['name'] ?? ''}'.trim().isEmpty
                  ? 'AppID ${app['appid']}'
                  : '${app['name']}'.trim()),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Quita los coincidentes uno a uno con un pequeño retardo, sigue aunque
  /// alguno falle y guarda el resultado en un archivo con fecha.
  Future<ResultadoLimpieza> limpiar(
      {void Function(int hechos, int total)? progreso}) async {
    final token = await tokenVigente();
    final juegos = await coincidencias(token);
    final fecha = _reloj();
    final quitados = <JuegoCoincidente>[];
    final fallos = <(JuegoCoincidente, String)>[];
    for (var i = 0; i < juegos.length; i++) {
      final juego = juegos[i];
      progreso?.call(i, juegos.length);
      if (i > 0 && retardo > Duration.zero) await Future.delayed(retardo);
      try {
        await _llamar('POST', '/IWishlistService/RemoveFromWishlist/v1/',
            {'appid': '${juego.appId}'}, token);
        quitados.add(juego);
      } on SteamTokenException catch (error) {
        // Sin token válido fallarán todos: se anotan sin seguir llamando.
        for (final resto in juegos.skip(i)) {
          fallos.add((resto, error.message));
        }
        break;
      } on FormatException catch (error) {
        fallos.add((juego, error.message));
      }
    }
    progreso?.call(juegos.length, juegos.length);
    var resultado =
        ResultadoLimpieza(quitados: quitados, fallos: fallos, fecha: fecha);
    if (resultado.total > 0) {
      final archivo = await _guardar(resultado);
      resultado = ResultadoLimpieza(
          quitados: quitados, fallos: fallos, fecha: fecha, archivo: archivo);
    }
    return resultado;
  }

  void dispose() => _client.close();

  Directory _carpetaResultados() {
    if (_carpeta != null) return _carpeta;
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final sep = Platform.pathSeparator;
    final documentos = Directory('$home${sep}Documents');
    final base =
        documentos.existsSync() ? '${documentos.path}${sep}Todo' : home;
    return Directory('$base${sep}steam');
  }

  Future<String?> _guardar(ResultadoLimpieza resultado) async {
    try {
      final f = resultado.fecha;
      String dos(int n) => n.toString().padLeft(2, '0');
      final nombre = 'lista_deseados_plan_familiar_${f.year}-${dos(f.month)}-'
          '${dos(f.day)}_${dos(f.hour)}${dos(f.minute)}.txt';
      final carpeta = _carpetaResultados();
      await carpeta.create(recursive: true);
      final archivo = File('${carpeta.path}${Platform.pathSeparator}$nombre');
      await archivo.writeAsString(resultado.texto);
      return archivo.path;
    } catch (_) {
      return null;
    }
  }
}
