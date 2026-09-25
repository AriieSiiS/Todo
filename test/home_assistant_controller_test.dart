import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/services/home_assistant_controller.dart';
import 'package:todo/services/home_twin_service.dart';

class _MemoryTokenStore implements HomeAssistantTokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async => token = value;
}

void main() {
  test('el token solo puede enviarse a una dirección local', () async {
    final controller = HomeAssistantController(tokenStore: _MemoryTokenStore());
    addTearDown(controller.dispose);
    await expectLater(
      controller.configure(
        url: 'https://servidor.example.com',
        newToken: 'secreto',
        selectedEntityId: '',
      ),
      throwsFormatException,
    );
  });

  test('sincroniza estados externos y confirma órdenes de luz', () async {
    final directory = await Directory.systemTemp.createTemp('todo-ha-test-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    final commands = <Map<String, dynamic>>[];
    var state = <String, dynamic>{
      'entity_id': 'light.techo',
      'state': 'off',
      'attributes': {
        'friendly_name': 'Luz del techo',
        'brightness': 100,
        'supported_color_modes': ['color_temp', 'hs'],
        'min_color_temp_kelvin': 2500,
        'max_color_temp_kelvin': 6500,
      },
    };
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.add(jsonEncode({'type': 'auth_required'}));
      socket.listen((message) {
        final data =
            (jsonDecode(message as String) as Map).cast<String, dynamic>();
        final type = data['type'];
        if (type == 'auth') {
          expect(data['access_token'], 'token-de-prueba');
          socket.add(jsonEncode({'type': 'auth_ok'}));
          return;
        }
        if (type == 'call_service') {
          commands.add(data);
          final options = (data['service_data'] as Map).cast<String, dynamic>();
          state = {
            ...state,
            'state': data['service'] == 'turn_on' ? 'on' : 'off',
            'attributes': {
              ...(state['attributes'] as Map),
              if (options['brightness'] != null)
                'brightness': options['brightness'],
              if (options['rgb_color'] != null)
                'rgb_color': options['rgb_color'],
              if (options['color_temp_kelvin'] != null)
                'color_temp_kelvin': options['color_temp_kelvin'],
            },
          };
        }
        socket.add(jsonEncode({
          'id': data['id'],
          'type': 'result',
          'success': true,
          'result': type == 'get_states' ? [state] : null,
        }));
        if (type == 'call_service') {
          socket.add(jsonEncode({
            'type': 'event',
            'event': {
              'data': {'entity_id': 'light.techo', 'new_state': state},
            },
          }));
        }
      });
    });
    final controller = HomeAssistantController(
      twin: HomeTwinService(rootOverride: directory),
      tokenStore: _MemoryTokenStore(),
    );
    addTearDown(() async {
      controller.dispose();
      for (final socket in sockets) {
        await socket.close();
      }
      await server.close(force: true);
      await directory.delete(recursive: true);
    });

    await controller.configure(
      url: 'http://127.0.0.1:${server.port}',
      newToken: 'token-de-prueba',
      selectedEntityId: 'light.techo',
    );
    expect(controller.connected, isTrue);
    expect(controller.selectedLight?.isOn, isFalse);
    expect(controller.selectedLight?.supportsColor, isTrue);
    expect(controller.selectedLight?.supportsTemperature, isTrue);

    await controller.setLight(on: true, brightness: 128);
    expect(commands.first['service'], 'turn_on');
    expect((commands.first['service_data'] as Map)['brightness'], 128);
    expect(controller.selectedLight?.isOn, isTrue);
    expect(controller.selectedLight?.brightness, 128);

    await controller.setLight(on: true, rgb: [240, 30, 90]);
    await controller.setLight(on: true, temperature: 4200);
    expect((commands[1]['service_data'] as Map)['rgb_color'], [240, 30, 90]);
    expect((commands[2]['service_data'] as Map)['color_temp_kelvin'], 4200);

    state = {...state, 'state': 'off'};
    sockets.last.add(jsonEncode({
      'type': 'event',
      'event': {
        'data': {'entity_id': 'light.techo', 'new_state': state},
      },
    }));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.selectedLight?.isOn, isFalse);

    await sockets.last.close();
    for (var attempt = 0; attempt < 20 && controller.connected; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(controller.connected, isFalse);
    await expectLater(
      controller.setLight(on: true),
      throwsFormatException,
    );
    for (var attempt = 0; attempt < 80 && !controller.connected; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(controller.connected, isTrue);
    expect(controller.selectedLight?.isOn, isFalse);
  });
}
