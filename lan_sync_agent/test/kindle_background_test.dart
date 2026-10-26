import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:todo_lan_sync_agent/kindle_gateway.dart';
import 'package:todo_core/runtime_writer_lock.dart';

void main() {
  late Directory directory;
  late File snapshot;
  late KindleBridgeClient client;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('todo-kindle-agente-');
    snapshot = File('${directory.path}/todo_state.json');
    await snapshot.writeAsString(jsonEncode({
      'schemaVersion': 12,
      'tasks': [
        {'id': 'tarea', 'title': 'Tarea de prueba', 'status': 'active'}
      ],
      'libraryItems': [
        {
          'id': 'libro',
          'type': 'book',
          'title': 'Libro de prueba',
          'author': 'Autora'
        }
      ],
      'datosFuturos': {'texto': 'Conservar íntegro'},
      'notes': [
        {'id': 'nota', 'content': 'No modificar'}
      ],
    }));
    client = KindleBridgeClient(directory);
    await File('${directory.path}/sync_metadata.json')
        .writeAsString(jsonEncode({
      'deviceId': 'equipo-local',
      'lastSeenCloudRevision': 42,
      'pendingLocalChanges': false,
      'datoFuturo': 'Conservar',
    }));
  });

  tearDown(() => directory.delete(recursive: true));

  test('el Kindle consulta y guarda con la interfaz cerrada', () async {
    final before = await snapshot.readAsString();
    final agenda = await client.call('get_kindle_agenda', {});
    expect(await snapshot.readAsString(), before);
    final task = (agenda['days'][0]['tasks'] as List).single;
    final args = <String, dynamic>{
      'request_id': 'marca-agente-0001',
      'root_task_id': 'tarea',
      'occurrence_date': agenda['logical_date'],
      'expected_version': task['task_version'],
      'task_ids': ['tarea'],
    };
    final result = await client.call('complete_kindle_group', args);
    expect(result['savedLocally'], true);
    expect(result['status'], 'saved');
    expect(
        await KindleBridgeClient(directory).call('complete_kindle_group', args),
        result);
    final saved = jsonDecode(await snapshot.readAsString()) as Map;
    expect(saved['tasks'][0]['status'], 'completed');
    expect(saved['datosFuturos'], {'texto': 'Conservar íntegro'});
    expect(saved['notes'], [
      {'id': 'nota', 'content': 'No modificar'}
    ]);
    expect(saved['agentOperationReceipts'], contains('marca-agente-0001'));
    final metadata = jsonDecode(
            await File('${directory.path}/sync_metadata.json').readAsString())
        as Map;
    expect(metadata['pendingLocalChanges'], true);
    expect(metadata['lastSeenCloudRevision'], 42);
    expect(metadata['datoFuturo'], 'Conservar');
  });

  test('el agente no sustituye al escritor activo de la app', () async {
    final before = await snapshot.readAsString();
    final lease = await RuntimeWriterLock.acquire(directory);
    try {
      await expectLater(client.call('get_kindle_agenda', {}),
          throwsA(isA<FileSystemException>()));
      expect(await snapshot.readAsString(), before);
    } finally {
      await lease.release();
    }
    expect((await client.call('get_kindle_agenda', {}))['days'], hasLength(7));
  });

  test('lectura y citas sobreviven al reinicio sin cargar Flutter', () async {
    final args = <String, dynamic>{
      'request_id': 'lectura-agente-0001',
      'document_id': 'a' * 32,
      'source_id': 'kindle-pruebas',
      'sequence': 1,
      'title': 'Libro de prueba',
      'author': 'Autora',
      'page': '30',
      'total_pages': 100,
      'chapter': 'Capítulo 2',
      'position': '/body/30',
      'progress': 0.3,
      'statistics': {
        'origin': 'historial-prueba', 'book_id': 1,
        'periods': [{'start': 3600, 'seconds': 120, 'pages': 2}]
      },
      'observed_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'quotes': [
        {
          'anchor': '/body/2',
          'text': 'Una cita',
          'note': '',
          'page': '2',
          'chapter': 'Capítulo 1',
          'created_at': ''
        }
      ],
    };
    final result = await client.call('sync_kindle_book', args);
    expect(result['savedLocally'], true);
    expect(await KindleBridgeClient(directory).call('sync_kindle_book', args),
        result);
    final saved = jsonDecode(await snapshot.readAsString()) as Map;
    expect(saved['libraryItems'][0]['reading']['progress'], 0.3);
    expect(saved['libraryItems'][0]['reading']['quotes'], hasLength(1));
    expect(saved['libraryItems'][0]['reading']['statistics']['historial-prueba:1']['periods'].single['seconds'], 120);
    expect(saved['datosFuturos'], {'texto': 'Conservar íntegro'});
    await expectLater(
        client.call('sync_kindle_book', {...args, 'progress': 0.4}),
        throwsFormatException);
  });

  test('el puente de la app tiene preferencia y respeta su bloqueo', () async {
    final lease = await RuntimeWriterLock.acquire(directory);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final before = await snapshot.readAsString();
    await File('${directory.path}/agent_bridge_session.json')
        .writeAsString(jsonEncode({
      'version': 1,
      'port': server.port,
      'token': 'x' * 44,
    }));
    server.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'source': 'app', 'books': []}));
      await request.response.close();
    });
    try {
      expect((await client.call('get_kindle_books', {}))['source'], 'app');
      expect(await snapshot.readAsString(), before);
    } finally {
      await server.close(force: true);
      await lease.release();
    }
  });

  test('desactivar la conexión en segundo plano impide su uso sin app',
      () async {
    final disabled =
        KindleBridgeClient(directory, allowBackground: () async => false);
    await expectLater(disabled.call('get_kindle_books', {}),
        throwsA(isA<FileSystemException>()));
  });

  test('un snapshot dañado no se sustituye por datos vacíos', () async {
    await snapshot.writeAsString('{incompleto');
    await expectLater(
        client.call('get_kindle_books', {}), throwsFormatException);
    expect(await snapshot.readAsString(), '{incompleto');
  });

  test('una sesión local caducada o dañada permite el relevo al agente',
      () async {
    await File('${directory.path}/agent_bridge_session.json')
        .writeAsString('{incompleto');
    expect((await client.call('get_kindle_books', {}))['books'], hasLength(1));
  });

  test('recupera una escritura interrumpida y rechaza comandos arbitrarios',
      () async {
    await snapshot.copy('${snapshot.path}.previous');
    await snapshot.delete();
    expect((await client.call('get_kindle_books', {}))['books'], hasLength(1));
    expect(await snapshot.exists(), true);
    await expectLater(client.call('delete_task', {}), throwsFormatException);
  });
}
