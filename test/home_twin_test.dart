import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/services/home_twin_service.dart';
import 'package:todo/services/home_twin_web_server.dart';

void main() {
  test('carga habitaciones contiguas y solo sirve modelos locales válidos',
      () async {
    final household = await Directory.systemTemp.createTemp('todo-gemelo-');
    addTearDown(() => household.delete(recursive: true));
    final twin = Directory('${household.path}${Platform.pathSeparator}twin');
    final models = Directory('${twin.path}${Platform.pathSeparator}models');
    await models.create(recursive: true);
    await File('${models.path}${Platform.pathSeparator}dormitorio.glb')
        .writeAsBytes(<int>[0x67, 0x6c, 0x54, 0x46]);
    await File('${models.path}${Platform.pathSeparator}salon.glb')
        .writeAsBytes(<int>[0x67, 0x6c, 0x54, 0x46]);
    await File('${twin.path}${Platform.pathSeparator}house.json').writeAsString(
      jsonEncode(<String, dynamic>{
        'schemaVersion': 1,
        'rooms': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'dormitorio',
            'name': 'Dormitorio',
            'modelPath': 'models/dormitorio.glb',
            'position': <String, num>{'x': 0, 'y': 0, 'z': 0},
            'objects': <dynamic>[],
          },
          <String, dynamic>{
            'id': 'salon',
            'name': 'Salón',
            'modelPath': 'models/salon.glb',
            'position': <String, num>{'x': 4, 'y': 0, 'z': 0},
            'objects': <dynamic>[],
          },
        ],
      }),
    );

    final service = HomeTwinService(rootOverride: household);
    final scene = await service.load();
    expect(
        scene.rooms.map((room) => room.name), <String>['Dormitorio', 'Salón']);
    expect(scene.rooms.last.position.x, 4);
    expect(await service.modelFile('../runtime/todo_state.json'), isNull);
    expect(await service.loadWindowOpen(), isFalse);
    await service.saveWindowOpen(true);
    expect(await service.loadWindowOpen(), isTrue);
    await File('${twin.path}${Platform.pathSeparator}house.json')
        .writeAsString(jsonEncode(scene.toJson()));
    expect(await service.loadWindowOpen(), isTrue);

    final web = HomeTwinWebServer(service);
    addTearDown(web.stop);
    final base = await web.start();
    final client = HttpClient();
    addTearDown(client.close);
    final request = await client.getUrl(Uri.parse('${base}api/house'));
    final response = await request.close();
    expect(response.statusCode, HttpStatus.ok);
    final document = jsonDecode(await response.transform(utf8.decoder).join())
        as Map<String, dynamic>;
    expect((document['rooms'] as List<dynamic>).length, 2);
  });
}
