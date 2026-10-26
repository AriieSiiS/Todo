import 'dart:convert';
import 'dart:io';

import 'kindle_background_store.dart';

typedef KindleCommand = Future<Map<String, dynamic>> Function(
    String, Map<String, dynamic>);

class _BridgeCommandError extends FormatException {
  _BridgeCommandError(super.message);
}

class KindleGateway {
  KindleGateway({required this.authorize, required this.command});
  final Future<bool> Function(HttpRequest) authorize;
  final KindleCommand command;

  Future<bool> handle(HttpRequest request) async {
    if (!request.uri.path.startsWith('/v1/kindle/')) return false;
    final response = request.response;
    response.headers.contentType = ContentType.json;
    response.headers.set('Cache-Control', 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    Future<void> reply(int status, Map<String, dynamic> value) async {
      response.statusCode = status;
      response.write(jsonEncode(value));
      await response.close();
    }

    try {
      if (request.headers.value('Origin') != null ||
          !await authorize(request)) {
        await reply(401, {'error': 'La conexión Kindle no está autorizada.'});
      } else if (request.method == 'GET' &&
          request.uri.path == '/v1/kindle/agenda') {
        if (request.uri.queryParametersAll.keys
                .any((key) => key != 'start_date') ||
            request.uri.queryParametersAll.values
                .any((values) => values.length != 1)) {
          throw const FormatException(
              'Los parámetros de la agenda no son válidos.');
        }
        await reply(200,
            await command('get_kindle_agenda', request.uri.queryParameters));
      } else if (request.method == 'GET' &&
          request.uri.path == '/v1/kindle/books' &&
          !request.uri.hasQuery) {
        await reply(200, await command('get_kindle_books', {}));
      } else if (request.method == 'POST' &&
          {'/v1/kindle/completions', '/v1/kindle/reading'}
              .contains(request.uri.path)) {
        final reading = request.uri.path == '/v1/kindle/reading';
        if (request.headers.contentType?.mimeType != 'application/json' ||
            request.uri.hasQuery) {
          throw const FormatException('Se esperaba un grupo de marcas JSON.');
        }
        final bytes = <int>[];
        var oversized = false;
        await for (final chunk in request.timeout(const Duration(seconds: 5))) {
          if (!oversized &&
              bytes.length + chunk.length <= (reading ? 1048576 : 65536)) {
            bytes.addAll(chunk);
          } else {
            oversized = true;
          }
        }
        if (oversized) {
          throw const FormatException('El grupo es demasiado grande.');
        }
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('El grupo no es válido.');
        }
        final result = await command(
            reading ? 'sync_kindle_book' : 'complete_kindle_group', decoded);
        await reply(result['status'] == 'conflict' ? 409 : 200, result);
      } else {
        await reply(404, {'error': 'La operación Kindle no existe.'});
      }
    } on FormatException catch (error) {
      await reply(400, {'error': error.message});
    } catch (_) {
      await reply(503, {
        'error':
            'Todo no está disponible. Conserva la marca y reintenta con el mismo identificador.'
      });
    }
    return true;
  }
}

/// Usa el escritor de la app o una transacción local cuando la interfaz está cerrada.
class KindleBridgeClient {
  KindleBridgeClient(this.runtimeDirectory, {this.allowBackground});
  final Directory runtimeDirectory;
  final Future<bool> Function()? allowBackground;
  Future<void> _pending = Future<void>.value();

  Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> arguments) {
    final result = _pending.then((_) => _call(name, arguments));
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> arguments) async {
    if (!{
      'get_kindle_agenda',
      'complete_kindle_group',
      'get_kindle_books',
      'sync_kindle_book'
    }.contains(name)) {
      throw const FormatException('La operación no está permitida.');
    }
    try {
      return await _callBridge(name, arguments);
    } on _BridgeCommandError {
      rethrow;
    } catch (_) {
      if (allowBackground != null && !await allowBackground!()) rethrow;
      return KindleBackgroundStore(runtimeDirectory).execute(name, arguments);
    }
  }

  Future<Map<String, dynamic>> _callBridge(
      String name, Map<String, dynamic> arguments) async {
    final sessionFile =
        File('${runtimeDirectory.path}/agent_bridge_session.json');
    if (await sessionFile.length() > 4096) {
      throw const FormatException('La sesión no es válida.');
    }
    final session = jsonDecode(await sessionFile.readAsString()) as Map;
    final port = session['port'];
    final token = session['token'];
    if (session['version'] != 1 ||
        port is! int ||
        port < 1 ||
        port > 65535 ||
        token is! String ||
        token.length != 44) {
      throw const FormatException('La sesión local no es válida.');
    }
    final client = HttpClient()
      ..findProxy = ((_) => 'DIRECT')
      ..connectionTimeout = const Duration(seconds: 2);
    try {
      final request =
          await client.postUrl(Uri.parse('http://127.0.0.1:$port/command'));
      request.followRedirects = false;
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'name': name, 'arguments': arguments}));
      final response =
          await request.close().timeout(const Duration(seconds: 15));
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        bytes.addAll(chunk);
        if (bytes.length > 2 * 1024 * 1024) {
          throw const FormatException('La agenda es demasiado grande.');
        }
      }
      final result = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (response.statusCode == 400) {
        throw _BridgeCommandError(result['error'] as String? ?? 'Marca no válida.');
      }
      if (response.statusCode != 200) {
        throw const HttpException('El puente no está disponible.');
      }
      return result;
    } finally {
      client.close(force: true);
    }
  }
}
