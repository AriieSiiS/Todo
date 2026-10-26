import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:todo_lan_sync_agent/kindle_gateway.dart';

void main() {
  late HttpServer server;
  late HttpClient client;
  final calls = <String>[];
  setUp(() async {
    calls.clear();
    final gateway = KindleGateway(
      authorize: (request) async =>
          request.headers.value('Authorization') == 'Bearer kindle',
      command: (name, args) async {
        calls.add(name);
        return {'ok': true, ...args};
      },
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (!await gateway.handle(request)) {
        request.response.statusCode = 404;
        await request.response.close();
      }
    });
    client = HttpClient();
  });
  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
  });

  Future<(int, Map)> call(String path,
      {String token = 'kindle',
      String? origin,
      String method = 'GET',
      String? body}) async {
    final request = await client.openUrl(
        method, Uri.parse('http://127.0.0.1:${server.port}$path'));
    request.headers.set('Authorization', 'Bearer $token');
    if (origin != null) request.headers.set('Origin', origin);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(body);
    }
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    return (response.statusCode, text.isEmpty ? {} : jsonDecode(text) as Map);
  }

  test('solo el perfil Kindle consulta la agenda y envía marcas', () async {
    expect((await call('/v1/kindle/agenda', token: 'android')).$1, 401);
    expect(
        (await call('/v1/kindle/agenda', origin: 'http://otra.test')).$1, 401);
    expect(calls, isEmpty);
    expect((await call('/v1/kindle/agenda?start_date=2026-10-23')).$1, 200);
    expect(
        (await call('/v1/kindle/completions', method: 'POST', body: '{}')).$1,
        200);
    expect(calls, ['get_kindle_agenda', 'complete_kindle_group']);
  });
  test('rechaza comandos arbitrarios, parámetros extra y cuerpos grandes',
      () async {
    expect((await call('/v1/kindle/agenda?name=delete_task')).$1, 400);
    expect(
        (await call('/v1/kindle/command', method: 'POST', body: '{}')).$1, 404);
    expect(
        (await call('/v1/kindle/completions',
                method: 'POST', body: 'x' * 70000))
            .$1,
        400);
    expect(calls, isEmpty);
  });
  test('lectura limitada al perfil Kindle y a sus rutas concretas', () async {
    expect((await call('/v1/kindle/books', token: 'android')).$1, 401);
    expect(
        (await call('/v1/kindle/reading',
                token: 'android', method: 'POST', body: '{}'))
            .$1,
        401);
    expect(calls, isEmpty);
    expect((await call('/v1/kindle/books')).$1, 200);
    expect(
        (await call('/v1/kindle/reading', method: 'POST', body: '{}')).$1, 200);
    expect(calls, ['get_kindle_books', 'sync_kindle_book']);
    expect(
        (await call('/v1/kindle/reading?name=delete_task',
                method: 'POST', body: '{}'))
            .$1,
        400);
    expect(
        (await call('/v1/kindle/reading', method: 'POST', body: 'x' * 1048577))
            .$1,
        400);
  });
}
