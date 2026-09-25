import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'home_twin_service.dart';

class HomeTwinWebServer {
  HomeTwinWebServer(this._home);

  final HomeTwinService _home;
  HttpServer? _server;

  String? get url =>
      _server == null ? null : 'http://127.0.0.1:${_server!.port}/';

  Future<String> start() async {
    if (_server != null) return url!;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_respond);
    return url!;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _respond(HttpRequest request) async {
    final response = request.response;
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('Cache-Control', 'no-store');
    response.headers.set(
      'Content-Security-Policy',
      "default-src 'none'; script-src 'self'; style-src 'unsafe-inline'; "
          "connect-src 'self'; img-src 'self' data: blob:",
    );
    try {
      if (request.method != 'GET') {
        response.statusCode = HttpStatus.methodNotAllowed;
      } else if (request.uri.path == '/') {
        await _asset(response, 'index.html', 'text/html; charset=utf-8');
      } else if (request.uri.path == '/scene.js') {
        await _asset(response, 'scene.js', 'text/javascript; charset=utf-8');
      } else if (request.uri.path == '/api/house') {
        final scene = await _home.load();
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode(scene.toJson()));
      } else if (request.uri.path.startsWith('/models/')) {
        final path = request.uri.path.substring(1);
        final file = await _home.modelFile(path);
        if (file == null) {
          response.statusCode = HttpStatus.notFound;
        } else {
          response.headers.contentType = ContentType.parse('model/gltf-binary');
          await response.addStream(file.openRead());
        }
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
      response.headers.contentType = ContentType.text;
      response.write('No se pudo cargar el gemelo de la casa.');
    } finally {
      await response.close();
    }
  }

  Future<void> _asset(
    HttpResponse response,
    String name,
    String contentType,
  ) async {
    response.headers.contentType = ContentType.parse(contentType);
    final asset = await rootBundle.load('assets/home_twin_web/$name');
    response.add(asset.buffer.asUint8List());
  }
}
