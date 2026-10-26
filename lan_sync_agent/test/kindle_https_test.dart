import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import '../bin/todo_lan_agent.dart';

void main() {
  test('HTTPS real: huella, perfiles separados, revocación y puente local',
      () async {
    final root = await Directory.systemTemp.createTemp('todo-kindle-https-');
    final runtime = await Directory('${root.path}/runtime').create();
    final config = await Directory('${root.path}/config').create();
    final commands = <String>[];
    final bridge = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final bridgeToken = 's' * 44;
    bridge.listen((request) async {
      expect(request.headers.value('Authorization'), 'Bearer $bridgeToken');
      final data = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      commands.add(data['name'] as String);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'protocol_version': 1,
        'days': [],
        'savedLocally': true,
        'status': 'saved'
      }));
      await request.response.close();
    });
    await File('${runtime.path}/agent_bridge_session.json')
        .writeAsString(jsonEncode({
      'version': 1,
      'port': bridge.port,
      'token': bridgeToken,
    }));
    await File('${runtime.path}/todo_state.json')
        .writeAsString(jsonEncode({'tasks': []}));
    final devicesFile = File('${config.path}/paired_devices.json');
    final devices = [
      {
        'id': 'k',
        'profile': 'kindle',
        'tokenHash': sha256.convert(utf8.encode('kindle')).toString()
      },
      {
        'id': 'a',
        'tokenHash': sha256.convert(utf8.encode('android')).toString()
      },
    ];
    await devicesFile.writeAsString(jsonEncode({'devices': devices}));
    final agent = TodoLanAgent(
        dataDirectory: config,
        stateDirectory: runtime,
        port: 0,
        advertise: false);
    final client = HttpClient();
    try {
      await agent.start();
      final certificate = jsonDecode(
          await File('${config.path}/certificate.json').readAsString());
      final base = 'https://127.0.0.1:${agent.listeningPort}';
      final untrusted = HttpClient();
      try {
        await expectLater(untrusted.getUrl(Uri.parse('$base/v1/kindle/agenda')),
            throwsA(isA<HandshakeException>()));
      } finally {
        untrusted.close(force: true);
      }
      client.badCertificateCallback = (cert, host, port) =>
          sha256.convert(cert.der).toString() ==
          certificate['fingerprintSha256'];
      Future<int> get(String path, String token) async {
        final request = await client.getUrl(Uri.parse('$base$path'));
        request.headers.set('Authorization', 'Bearer $token');
        final response = await request.close();
        await response.drain<void>();
        return response.statusCode;
      }

      expect(await get('/v1/task-snapshot', 'android'), 200);
      expect(await get('/v1/task-snapshot', 'kindle'), 401);
      expect(await get('/v1/wardrobe-snapshot', 'kindle'), 401);
      expect(await get('/v1/kindle/agenda', 'android'), 401);
      expect(await get('/v1/kindle/agenda', 'kindle'), 200);
      expect(await get('/v1/kindle/books', 'android'), 401);
      expect(await get('/v1/kindle/books', 'kindle'), 200);
      final request =
          await client.postUrl(Uri.parse('$base/v1/kindle/completions'));
      request.headers.set('Authorization', 'Bearer kindle');
      request.headers.contentType = ContentType.json;
      request.write('{}');
      final response = await request.close();
      expect(response.statusCode, 200);
      await response.drain<void>();
      final reading = await client.postUrl(Uri.parse('$base/v1/kindle/reading'));
      reading.headers.set('Authorization', 'Bearer kindle');
      reading.headers.contentType = ContentType.json;
      reading.write('{}');
      final readingResponse=await reading.close();
      expect(readingResponse.statusCode,200);
      await readingResponse.drain<void>();
      expect(commands, ['get_kindle_agenda', 'get_kindle_books', 'complete_kindle_group', 'sync_kindle_book']);
      await bridge.close(force: true);
      await File('${config.path}/kindle_enabled').writeAsString('1');
      await File('${runtime.path}/todo_state.json').writeAsString(jsonEncode({
        'tasks': [{'id': 'sin-interfaz', 'title': 'Tarea sin interfaz', 'status': 'active'}],
        'libraryItems': [],
      }));
      Future<Map<String, dynamic>> kindle(String path, {Map<String, dynamic>? body}) async {
        final request = await client.openUrl(body == null ? 'GET' : 'POST', Uri.parse('$base$path'));
        request.headers.set('Authorization', 'Bearer kindle');
        if (body != null) {
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(body));
        }
        final response = await request.close();
        expect(response.statusCode, 200);
        return jsonDecode(await utf8.decoder.bind(response).join()) as Map<String, dynamic>;
      }
      final agenda = await kindle('/v1/kindle/agenda');
      final task = (agenda['days'][0]['tasks'] as List).single;
      final saved = await kindle('/v1/kindle/completions', body: {
        'request_id': 'https-sin-interfaz-0001', 'root_task_id': task['id'],
        'occurrence_date': agenda['logical_date'], 'expected_version': task['task_version'],
        'task_ids': [task['id']],
      });
      expect(saved['savedLocally'], true);
      expect((jsonDecode(await File('${runtime.path}/todo_state.json').readAsString()) as Map)['tasks'][0]['status'], 'completed');
      await devicesFile.writeAsString(jsonEncode({
        'devices': [devices.last]
      }));
      expect(await get('/v1/kindle/agenda', 'kindle'), 401);
      expect(await get('/v1/task-snapshot', 'android'), 200);
    } finally {
      client.close(force: true);
      await agent.stop(exitProcess: false);
      await bridge.close(force: true);
      await root.delete(recursive: true);
    }
  });
}
