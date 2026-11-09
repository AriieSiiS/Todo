import 'dart:io';

import 'package:flutter/services.dart';

/// Servidor local mínimo que entrega el visor 3D de miniaturas al WebView.
class MiniatureViewerServer {
  MiniatureViewerServer._();

  static final MiniatureViewerServer instance = MiniatureViewerServer._();

  HttpServer? _server;
  Future<String>? _arranque;

  Future<String> start() => _arranque ??= _iniciar();

  Future<String> _iniciar() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_responder);
    return 'http://127.0.0.1:${server.port}/';
  }

  Future<void> _responder(HttpRequest request) async {
    final response = request.response;
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('Cache-Control', 'no-store');
    try {
      final ruta = request.uri.path;
      if (request.method != 'GET') {
        response.statusCode = HttpStatus.methodNotAllowed;
      } else if (ruta == '/' || ruta == '/index.html') {
        await _recurso(response, 'index.html', 'text/html; charset=utf-8');
      } else if (ruta == '/visor.js') {
        await _recurso(
            response, 'visor.js', 'text/javascript; charset=utf-8');
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  }

  Future<void> _recurso(
    HttpResponse response,
    String nombre,
    String tipo,
  ) async {
    response.headers.contentType = ContentType.parse(tipo);
    final datos = await rootBundle.load('assets/miniature_web/$nombre');
    response.add(
        datos.buffer.asUint8List(datos.offsetInBytes, datos.lengthInBytes));
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _arranque = null;
  }
}
