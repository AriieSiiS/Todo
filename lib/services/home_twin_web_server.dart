import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'home_twin_service.dart';

class HomeTwinWebServer {
  HomeTwinWebServer(this._home, {Directory? assetDirectory})
      : _assetDirectory = assetDirectory ??
            Directory(
              '${File(Platform.resolvedExecutable).parent.path}/data/flutter_assets/assets/home_twin_web',
            );

  final HomeTwinService _home;
  final Directory _assetDirectory;
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
          "connect-src 'self'; img-src 'self' data: blob:; media-src 'self'",
    );
    try {
      if (request.method != 'GET') {
        response.statusCode = HttpStatus.methodNotAllowed;
      } else if (request.uri.path == '/') {
        await _asset(response, 'index.html', 'text/html; charset=utf-8');
      } else if (request.uri.path == '/scene.js') {
        await _viewerScript(response);
      } else if (request.uri.path == '/audio/catalogo.json') {
        await _asset(
            response, 'audio/catalogo.json', 'application/json; charset=utf-8');
      } else if (_audioPath(request.uri.path)) {
        await _media(request, request.uri.pathSegments.join('/'), 'audio/ogg');
      } else if (const {
        '/wallpapers/monitor_derecho_dia.png',
        '/wallpapers/monitor_derecho_atardecer.png',
        '/wallpapers/monitor_derecho_noche.png',
        '/wallpapers/monitor_izquierdo.png',
        '/weather/despejado.png',
        '/weather/nublado.png',
        '/weather/lluvia.png',
        '/weather/tormenta.png',
        '/weather/noche.png',
        '/weather/panorama_despejado.png',
        '/weather/panorama_nublado.png',
        '/weather/panorama_tormenta.png',
        '/weather/panorama_noche.png',
        '/weather/panorama_madrugada.png',
        '/weather/panorama_atardecer.png',
        '/weather/panorama_tarde_noche.png',
      }.contains(request.uri.path)) {
        await _asset(response, request.uri.path.substring(1), 'image/png');
      } else if (const {
        '/wallpapers/monitor_izquierdo.mp4',
        '/wallpapers/monitor_derecho.mp4',
      }.contains(request.uri.path)) {
        await _media(request, request.uri.path.substring(1), 'video/mp4');
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
    final file = File('${_assetDirectory.path}/$name');
    if (await file.exists()) {
      response.contentLength = await file.length();
      await response.addStream(file.openRead());
      return;
    }
    final asset = await rootBundle.load('assets/home_twin_web/$name');
    response.add(
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes));
  }

  Future<void> _viewerScript(HttpResponse response) async {
    response.headers.contentType =
        ContentType.parse('text/javascript; charset=utf-8');
    final file = File('${_assetDirectory.path}/scene.js');
    if (await file.exists()) {
      await response.addStream(file.openRead());
    } else {
      final asset = await rootBundle.load('assets/home_twin_web/scene.js');
      response.add(asset.buffer.asUint8List());
    }
  }

  bool _audioPath(String path) {
    final parts = Uri.parse(path).pathSegments;
    if (parts.length == 3 && parts[0] == 'audio' && parts[1] == 'sonidos') {
      return RegExp(r'^[A-Za-z0-9_. -]+\.ogg$').hasMatch(parts[2]);
    }
    if (parts.length == 4 &&
        parts[0] == 'audio' &&
        parts[1] == 'musica' &&
        const {'base', 'dlc', 'dreemeDLC'}.contains(parts[2])) {
      return RegExp(r'^[A-Za-z0-9_. -]+\.ogg$').hasMatch(parts[3]);
    }
    return false;
  }

  Future<void> _media(
      HttpRequest request, String assetPath, String contentType) async {
    final response = request.response;
    final file = File('${_assetDirectory.path}/$assetPath');
    final onDisk = await file.exists();
    Uint8List? bytes;
    final int length;
    if (onDisk) {
      length = await file.length();
    } else {
      final asset = await rootBundle.load('assets/home_twin_web/$assetPath');
      bytes =
          asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes);
      length = bytes.length;
    }
    final range = request.headers.value(HttpHeaders.rangeHeader);
    response.headers.contentType = ContentType.parse(contentType);
    response.headers.set('Accept-Ranges', 'bytes');
    if (range == null) {
      response.headers.contentLength = length;
      if (onDisk) {
        await response.addStream(file.openRead());
      } else {
        response.add(bytes!);
      }
      return;
    }

    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
    final first = match?.group(1) ?? '';
    final last = match?.group(2) ?? '';
    final firstNumber = int.tryParse(first);
    final lastNumber = int.tryParse(last);
    if (length == 0 ||
        match == null ||
        (first.isEmpty && last.isEmpty) ||
        (first.isNotEmpty && firstNumber == null) ||
        (last.isNotEmpty && lastNumber == null)) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set('Content-Range', 'bytes */$length');
      return;
    }
    final start = first.isEmpty
        ? (length - lastNumber!).clamp(0, length).toInt()
        : firstNumber!;
    final end = first.isEmpty || last.isEmpty
        ? length - 1
        : lastNumber!.clamp(0, length - 1).toInt();
    if (start >= length || end < start) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set('Content-Range', 'bytes */$length');
      return;
    }
    response.statusCode = HttpStatus.partialContent;
    response.headers.set('Content-Range', 'bytes $start-$end/$length');
    response.headers.contentLength = end - start + 1;
    if (onDisk) {
      await response.addStream(file.openRead(start, end + 1));
    } else {
      response.add(Uint8List.sublistView(bytes!, start, end + 1));
    }
  }
}
