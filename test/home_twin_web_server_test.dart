import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/services/home_twin_service.dart';
import 'package:todo/services/home_twin_web_server.dart';

void main() {
  late Directory root;
  late HomeTwinWebServer server;
  late HttpClient client;
  late String base;
  final contents = List<int>.generate(256, (i) => i);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('todo-auditoria-media-');
    final asset = File('${root.path}/wallpapers/monitor_derecho.mp4');
    await asset.parent.create(recursive: true);
    await asset.writeAsBytes(contents);
    server = HomeTwinWebServer(HomeTwinService(rootOverride: root),
        assetDirectory: root);
    base = await server.start();
    client = HttpClient();
  });
  tearDown(() async {
    client.close(force: true);
    await server.stop();
    await root.delete(recursive: true);
  });

  Future<HttpClientResponse> request(
      {String? range, String path = 'wallpapers/monitor_derecho.mp4'}) async {
    final request = await client.getUrl(Uri.parse('$base$path'));
    if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
    return request.close();
  }

  test('sirve un vídeo local completo sin depender del paquete de recursos',
      () async {
    final response = await request();
    expect(response.statusCode, 200);
    expect(response.contentLength, 256);
    expect(await response.fold<List<int>>([], (all, part) => all..addAll(part)),
        contents);
  });

  for (final range in <String, (int, int)>{
    'bytes=10-19': (10, 19),
    'bytes=250-': (250, 255),
    'bytes=-4': (252, 255),
    'bytes=250-999': (250, 255),
    'bytes=-999': (0, 255),
  }.entries) {
    test('sirve el fragmento ${range.key}', () async {
      final response = await request(range: range.key);
      final (start, end) = range.value;
      expect(response.statusCode, 206);
      expect(response.headers.value('Content-Range'), 'bytes $start-$end/256');
      expect(
          await response.fold<List<int>>([], (all, part) => all..addAll(part)),
          contents.sublist(start, end + 1));
    });
  }

  for (final range in [
    'bytes=256-',
    'bytes=20-10',
    'bytes=-0',
    'bytes=-',
    'bytes=0-1,3-4',
    'bytes=999999999999999999999999-',
    'bytes=0-999999999999999999999999'
  ]) {
    test('rechaza el rango inválido $range sin error interno', () async {
      final response = await request(range: range);
      expect(response.statusCode, 416);
      expect(response.headers.value('Content-Range'), 'bytes */256');
      await response.drain<void>();
    });
  }

  test('rechaza un rango sobre un archivo vacío', () async {
    await File('${root.path}/wallpapers/monitor_derecho.mp4').writeAsBytes([]);
    final response = await request(range: 'bytes=0-1');
    expect(response.statusCode, 416);
    await response.drain<void>();
  });

  test('los sonidos con espacios conservan su ruta', () async {
    final file = File('${root.path}/audio/sonidos/timer down.ogg');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(contents);
    final response = await request(
        path: 'audio/sonidos/timer%20down.ogg', range: 'bytes=0-1');
    expect(response.statusCode, 206);
    expect(await response.fold<List<int>>([], (all, part) => all..addAll(part)),
        [0, 1]);
  });
}
