import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

typedef AgentCommandHandler = Future<Map<String, dynamic>> Function(
    String name, Map<String, dynamic> arguments);

class AgentBridgeService {
  AgentBridgeService(this._handler, {Directory? runtimeDirectory})
      : _runtimeDirectory = runtimeDirectory;

  final AgentCommandHandler _handler;
  final Directory? _runtimeDirectory;
  HttpServer? _server;
  File? _sessionFile;
  String? _token;
  RandomAccessFile? _sessionLock;

  Future<void> start() async {
    if (_server != null || (!Platform.isWindows && _runtimeDirectory == null)) {
      return;
    }
    final home = Platform.environment['USERPROFILE'] ?? Directory.current.path;
    final documents = Directory('$home/Documents');
    final directory = _runtimeDirectory ??
        Directory(documents.existsSync()
            ? '$home/Documents/Todo/runtime'
            : '$home/runtime');
    await directory.create(recursive: true);
    final session = File('${directory.path}/agent_bridge_session.json');
    final lock = await File('${session.path}.lock').open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive, 0, 1);
    } catch (_) {
      await lock.close();
      throw StateError('Otro Todo ya utiliza el puente local.');
    }
    _sessionLock = lock;
    // Un segundo Todo no debe sustituir la conexión del escritor activo.
    if (await _hasActiveSession(session)) {
      await lock.close();
      _sessionLock = null;
      throw StateError('Ya existe un puente local activo de Todo.');
    }
    final random = Random.secure();
    final token =
        base64UrlEncode(List.generate(32, (_) => random.nextInt(256)));
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    } catch (_) {
      await lock.close();
      _sessionLock = null;
      rethrow;
    }
    _server = server;
    _token = token;
    _sessionFile = session;
    server.listen(_respond);
    try {
      await session.writeAsString(
          jsonEncode({
            'version': 1,
            'port': server.port,
            'token': token,
            'pid': pid,
          }),
          flush: true);
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  Future<bool> _hasActiveSession(File session) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    try {
      final data = jsonDecode(await session.readAsString()) as Map;
      final port = data['port'];
      final token = data['token'];
      if (port is! int || token is! String || port < 1 || port > 65535) {
        return false;
      }
      final request =
          await client.getUrl(Uri.parse('http://127.0.0.1:$port/health'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response =
          await request.close().timeout(const Duration(seconds: 1));
      await response.drain<void>();
      return response.statusCode == HttpStatus.ok;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _respond(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;
    response.headers.set('Cache-Control', 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    try {
      // No se permite utilizar este puente desde una página web ni desde la LAN.
      if (request.headers.value('origin') != null ||
          request.headers.value(HttpHeaders.authorizationHeader) !=
              'Bearer $_token') {
        response.statusCode = HttpStatus.unauthorized;
        response.write(
            jsonEncode({'error': 'La conexión local no está autorizada.'}));
      } else if (request.method == 'GET' && request.uri.path == '/health') {
        response.write(jsonEncode({'ready': true, 'version': 1}));
      } else if (request.method != 'POST' || request.uri.path != '/command') {
        response.statusCode = HttpStatus.notFound;
        response.write(jsonEncode({'error': 'La operación local no existe.'}));
      } else {
        if (request.headers.contentType?.mimeType != 'application/json') {
          throw const FormatException('Se requiere una petición JSON.');
        }
        final bytes = <int>[];
        await for (final chunk in request.timeout(const Duration(seconds: 5))) {
          bytes.addAll(chunk);
          if (bytes.length > 1048576) {
            throw const FormatException(
                'La petición supera el tamaño permitido.');
          }
        }
        final data = jsonDecode(utf8.decode(bytes));
        if (bytes.length > 65536 && (data is! Map || data['name'] != 'sync_kindle_book')) {
          throw const FormatException('La petición supera el tamaño permitido.');
        }
        if (data is! Map<String, dynamic> ||
            data.keys.any((key) => !{'name', 'arguments'}.contains(key)) ||
            data['name'] is! String ||
            data['arguments'] is! Map<String, dynamic>) {
          throw const FormatException(
              'La petición local no tiene un formato válido.');
        }
        response.write(jsonEncode(await _handler(data['name'] as String,
            data['arguments'] as Map<String, dynamic>)));
      }
    } on FormatException catch (error) {
      response.statusCode = HttpStatus.badRequest;
      response.write(jsonEncode({'error': error.message}));
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
      response.write(jsonEncode({
        'error':
            'No se pudo guardar la operación. Reintenta con el mismo request_id.'
      }));
    } finally {
      await response.close();
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
    try {
      final file = _sessionFile;
      if (file != null && await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map;
        if (data['token'] == _token) await file.delete();
      }
    } catch (_) {
      // Una sesión caducada se comprueba al volver a iniciar el puente.
    } finally {
      await _sessionLock?.close();
      _sessionLock = null;
    }
  }
}
