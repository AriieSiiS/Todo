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
    var delayCommands = false;
    var state = <String, dynamic>{
      'entity_id': 'light.techo',
      'state': 'off',
      'attributes': {
        'friendly_name': 'Luz del techo',
        'brightness': 100,
        'supported_features': 32,
        'supported_color_modes': ['color_temp', 'hs'],
        'min_color_temp_kelvin': 2500,
        'max_color_temp_kelvin': 6500,
      },
    };
    var weatherState = <String, dynamic>{
      'entity_id': 'weather.casa',
      'state': 'sunny',
      'attributes': {
        'friendly_name': 'Casa',
        'temperature': 17.0,
        'temperature_unit': '°C',
      },
    };
    var hallwayState = <String, dynamic>{
      'entity_id': 'light.pasillo',
      'state': 'off',
      'attributes': {
        'friendly_name': 'Pasillo',
        'brightness': 120,
        'supported_color_modes': ['color_temp', 'hs'],
      },
    };
    var secondRoomState = <String, dynamic>{
      'entity_id': 'light.dormitorio',
      'state': 'off',
      'attributes': {
        'friendly_name': 'Dormitorio',
        'brightness': 185,
        'supported_color_modes': ['color_temp', 'hs'],
      },
    };
    final sunState = <String, dynamic>{
      'entity_id': 'sun.sun',
      'state': 'above_horizon',
      'attributes': {'elevation': 36.5},
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
          final entity = options['entity_id'] as String;
          final current = switch (entity) {
            'light.pasillo' => hallwayState,
            'light.dormitorio' => secondRoomState,
            _ => state,
          };
          final updated = <String, dynamic>{
            ...current,
            'state': data['service'] == 'turn_on' ? 'on' : 'off',
            'attributes': {
              ...(current['attributes'] as Map),
              if (options['brightness'] != null)
                'brightness': options['brightness'],
              if (options['rgb_color'] != null)
                'rgb_color': options['rgb_color'],
              if (options['color_temp_kelvin'] != null)
                'color_temp_kelvin': options['color_temp_kelvin'],
              if (options['rgb_color'] != null)
                'color_mode': 'hs',
              if (options['color_temp_kelvin'] != null)
                'color_mode': 'color_temp',
            },
          };
          switch (entity) {
            case 'light.pasillo':
              hallwayState = updated;
            case 'light.dormitorio':
              secondRoomState = updated;
            default:
              state = updated;
          }
        }
        void respond() {
          socket.add(jsonEncode({
            'id': data['id'],
            'type': 'result',
            'success': true,
            'result': type == 'get_states'
                ? [state, hallwayState, secondRoomState, weatherState, sunState]
                : null,
          }));
          if (type == 'call_service') {
            final entity = (data['service_data'] as Map)['entity_id'];
            socket.add(jsonEncode({
              'type': 'event',
              'event': {
                'data': {
                  'entity_id': entity,
                  'new_state': switch (entity) {
                    'light.pasillo' => hallwayState,
                    'light.dormitorio' => secondRoomState,
                    _ => state,
                  },
                },
              },
            }));
          }
        }

        if (type == 'call_service' && delayCommands) {
          Future<void>.delayed(const Duration(milliseconds: 120), respond);
        } else {
          respond();
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
      await Future<void>.delayed(const Duration(milliseconds: 100));
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
    expect(controller.weatherEntityId, 'weather.casa');
    expect(controller.weatherVisualState['condition'], 'sunny');
    expect(controller.weatherVisualState['temperatureC'], 17.0);
    expect(controller.weatherVisualState['sunElevation'], 36.5);
    weatherState = {
      ...weatherState,
      'state': 'lightning-rainy',
      'attributes': {
        'friendly_name': 'Casa',
        'temperature': 64.4,
        'temperature_unit': '°F',
      },
    };
    sockets.last.add(jsonEncode({
      'type': 'event',
      'event': {
        'data': {'entity_id': 'weather.casa', 'new_state': weatherState},
      },
    }));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.weatherVisualState['condition'], 'lightning-rainy');
    expect(controller.weatherVisualState['temperatureC'], closeTo(18, 0.01));
    sockets.last.add(jsonEncode({
      'type': 'event',
      'event': {
        'data': {
          'entity_id': 'weather.casa',
          'new_state': {
            ...weatherState,
            'state': 'unavailable',
          },
        },
      },
    }));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.weatherVisualState['condition'], 'lightning-rainy');
    expect(controller.weatherVisualState['stale'], isTrue);
    await controller.setGradualOnEnabled(false);

    controller.previewLight(on: true, brightness: 77);
    expect(controller.selectedLight?.isOn, isFalse);
    expect(controller.selectedLight?.brightness, 77);
    expect(controller.commandPending, isFalse);
    sockets.last.add(jsonEncode({
      'type': 'event',
      'event': {
        'data': {'entity_id': 'light.techo', 'new_state': state},
      },
    }));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.selectedLight?.brightness, 77);
    controller.previewLight(on: true, brightness: 91);
    await controller.setLight(on: true, brightness: 128);
    expect(commands, isEmpty);
    expect(controller.selectedLight?.isOn, isFalse);
    await controller.setLight(on: true);
    expect(commands, hasLength(1));
    expect(commands.first['service'], 'turn_on');
    expect((commands.first['service_data'] as Map)['brightness'], 128);
    expect(controller.selectedLight?.isOn, isTrue);
    expect(controller.selectedLight?.brightness, 128);

    await controller.setLight(on: true, rgb: [240, 30, 90]);
    await controller.setLight(on: true, temperature: 4200);
    expect((commands[1]['service_data'] as Map)['rgb_color'], [240, 30, 90]);
    expect((commands[2]['service_data'] as Map)['color_temp_kelvin'], 4200);

    delayCommands = true;
    final firstSlowChange = controller.setLight(on: true, brightness: 80);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    controller.previewLight(on: true, brightness: 110);
    final lastSlowChange = controller.setLight(on: true, brightness: 150);
    expect(controller.selectedLight?.brightness, 150);
    await Future.wait([firstSlowChange, lastSlowChange]);
    expect(commands, hasLength(5));
    expect((commands[3]['service_data'] as Map)['brightness'], 80);
    expect((commands[4]['service_data'] as Map)['brightness'], 150);
    delayCommands = false;

    state = {...state, 'state': 'off'};
    sockets.last.add(jsonEncode({
      'type': 'event',
      'event': {
        'data': {'entity_id': 'light.techo', 'new_state': state},
      },
    }));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.selectedLight?.isOn, isFalse);
    expect(controller.selectedLight?.brightness, 150);

    await controller.setGradualOnEnabled(true);
    final commandsBeforePowerOn = commands.length;
    await controller.setLight(on: true);
    final powerOnCommands = commands.skip(commandsBeforePowerOn).toList();
    expect(powerOnCommands, hasLength(1));
    expect(commands.last['service'], 'turn_on');
    expect((commands.last['service_data'] as Map)['brightness'], 150);
    expect((commands.last['service_data'] as Map).containsKey('transition'),
        isFalse);
    expect(controller.selectedLight?.brightness, 150);

    await controller.savePreset('Luz de lectura');
    expect(controller.presets.single.name, 'Luz de lectura');
    final savedConfiguration = (jsonDecode(await File(
      '${directory.path}${Platform.pathSeparator}twin${Platform.pathSeparator}home_assistant.json',
    ).readAsString()) as Map)
        .cast<String, dynamic>();
    expect((savedConfiguration['presets'] as List).single['name'],
        'Luz de lectura');
    expect((savedConfiguration['lastOnLight'] as Map)['brightness'], 150);
    final presetId = controller.presets.single.id;
    await controller.renamePreset(presetId, 'Lectura');
    expect(controller.presets.single.name, 'Lectura');
    await controller.setLight(on: false);
    expect(commands.last['service'], 'turn_off');
    expect((commands.last['service_data'] as Map).containsKey('transition'),
        isFalse);
    expect(controller.selectedLight?.brightness, 150);
    final commandsBeforePreset = commands.length;
    await controller.applyPreset(controller.presets.single);
    expect(commands, hasLength(commandsBeforePreset));
    expect(controller.selectedLight?.isOn, isFalse);
    await controller.setLight(on: true);
    expect(commands.last['service'], 'turn_on');
    expect((commands.last['service_data'] as Map)['brightness'], 150);
    await controller.deletePreset(presetId);
    expect(controller.presets, isEmpty);
    await controller.setGradualOnEnabled(false);
    expect(controller.gradualOnEnabled, isFalse);
    await controller.setLight(on: false);
    expect((commands.last['service_data'] as Map).containsKey('transition'),
        isFalse);
    await controller.setLight(on: true);
    expect((commands.last['service_data'] as Map).containsKey('transition'),
        isFalse);
    final updatedConfiguration = (jsonDecode(await File(
      '${directory.path}${Platform.pathSeparator}twin${Platform.pathSeparator}home_assistant.json',
    ).readAsString()) as Map)
        .cast<String, dynamic>();
    expect((updatedConfiguration['gradualOnByEntity'] as Map)['light.techo'],
        isFalse);
    await controller.setLight(on: false);

    await sockets.last.close();
    for (var attempt = 0; attempt < 20 && controller.connected; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(controller.connected, isFalse);
    expect(controller.weatherVisualState['stale'], isTrue);
    expect(controller.weatherVisualState['condition'], 'lightning-rainy');
    await expectLater(
      controller.setLight(on: true),
      throwsFormatException,
    );
    for (var attempt = 0; attempt < 80 && !controller.connected; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(controller.connected, isTrue);
    expect(controller.selectedLight?.isOn, isFalse);
    await controller.bindHallwayLight('light.pasillo');
    expect(controller.hallwayLight?.name, 'Pasillo');
    expect(
        controller.hallwayLight?.toVisualState(
          roomId: 'pasillo',
          objectId: 'luz_pasillo',
        )['roomId'],
        'pasillo');
    await controller.setHallwayLight(on: true);
    expect(
        (commands.last['service_data'] as Map)['entity_id'], 'light.pasillo');
    expect((commands.last['service_data'] as Map).containsKey('transition'),
        isFalse);
    expect(controller.hallwayLight?.isOn, isTrue);
    await controller.setLightForRoom('pasillo', on: true, brightness: 89);
    expect((commands.last['service_data'] as Map)['brightness'], 89);
    await controller.setLightForRoom('pasillo', on: true, rgb: [80, 40, 190]);
    expect((commands.last['service_data'] as Map)['rgb_color'], [80, 40, 190]);
    await controller.savePresetForRoom('pasillo', 'Violeta');
    expect(controller.presetsForRoom('pasillo').single.name, 'Violeta');
    expect(controller.presetsForRoom('dormitorio'), isEmpty);
    final hallwayConfiguration = (jsonDecode(await File(
      '${directory.path}${Platform.pathSeparator}twin${Platform.pathSeparator}home_assistant.json',
    ).readAsString()) as Map)
        .cast<String, dynamic>();
    expect((hallwayConfiguration['bindings'] as Map)['pasillo/luz_pasillo'],
        'light.pasillo');
    await controller.bindSecondRoomLight('light.dormitorio');
    expect(controller.secondRoomLight?.name, 'Dormitorio');
    expect(
        controller.secondRoomLight?.toVisualState(
          roomId: 'habitacion_vacia',
          objectId: 'luz_techo',
        )['roomId'],
        'habitacion_vacia');
    await controller.setSecondRoomLight(on: true);
    expect((commands.last['service_data'] as Map)['entity_id'],
        'light.dormitorio');
    expect((commands.last['service_data'] as Map).containsKey('transition'),
        isFalse);
    await controller.setLightForRoom(
      'habitacion_vacia',
      on: true,
      temperature: 3100,
    );
    expect((commands.last['service_data'] as Map)['color_temp_kelvin'], 3100);
    expect(controller.secondRoomLight?.temperature, 3100);
    await controller.savePresetForRoom('habitacion_vacia', 'Lectura');
    expect(controller.presetsForRoom('habitacion_vacia').single.name, 'Lectura');
    expect(controller.presetsForRoom('pasillo').single.name, 'Violeta');
    await controller.setGradualOnEnabledForRoom('pasillo', false);
    expect(controller.gradualOnEnabledForRoom('pasillo'), isFalse);
    expect(controller.gradualOnEnabledForRoom('habitacion_vacia'), isTrue);
    final secondRoomConfiguration = (jsonDecode(await File(
      '${directory.path}${Platform.pathSeparator}twin${Platform.pathSeparator}home_assistant.json',
    ).readAsString()) as Map)
        .cast<String, dynamic>();
    expect(
        (secondRoomConfiguration['bindings']
            as Map)['habitacion_vacia/luz_techo'],
        'light.dormitorio');

    final commandsBeforePrimarySetting = commands.length;
    await controller.setLight(on: true, temperature: 3000);
    controller.previewLight(on: true, brightness: 90);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(commands, hasLength(commandsBeforePrimarySetting));
    expect(controller.selectedLight?.isOn, isFalse);
    expect(controller.selectedLight?.temperature, 3000);
    expect(controller.selectedLight?.brightness, 90);
    final preparedConfiguration = (jsonDecode(await File(
      '${directory.path}${Platform.pathSeparator}twin${Platform.pathSeparator}home_assistant.json',
    ).readAsString()) as Map)
        .cast<String, dynamic>();
    expect((preparedConfiguration['lastOnLight'] as Map)['temperature'], 3000);
    await controller.setLight(on: true);
    expect((commands.last['service_data'] as Map)['brightness'], 90);
    expect((commands.last['service_data'] as Map)['color_temp_kelvin'], 3000);

    await controller.setHallwayLight(on: false);
    final commandsBeforeHallwaySetting = commands.length;
    controller.previewLightForRoom('pasillo', on: true, rgb: [60, 90, 160]);
    await controller.setLightForRoom('pasillo', on: true, brightness: 100);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(commands, hasLength(commandsBeforeHallwaySetting));
    expect(controller.hallwayLight?.isOn, isFalse);
    expect(controller.hallwayLight?.brightness, 100);
    await controller.setHallwayLight(on: true);
    expect((commands.last['service_data'] as Map)['rgb_color'], [60, 90, 160]);
    expect((commands.last['service_data'] as Map)['brightness'], 100);

    await controller.setLightForRoom(
      'habitacion_vacia',
      on: true,
      rgb: [20, 90, 180],
    );
    await controller.setSecondRoomLight(on: false);
    expect(controller.secondRoomLight?.colorMode, isNot('color_temp'));
    final commandsBeforeSecondRoomSetting = commands.length;
    await controller.applyPresetForRoom(
      'habitacion_vacia',
      controller.presetsForRoom('habitacion_vacia').single,
    );
    expect(commands, hasLength(commandsBeforeSecondRoomSetting));
    expect(controller.secondRoomLight?.isOn, isFalse);
    expect(controller.secondRoomLight?.colorMode, 'color_temp');
    expect(controller.secondRoomLight?.temperature, 3100);
    await controller.setSecondRoomLight(on: true);
    expect((commands.last['service_data'] as Map)['color_temp_kelvin'], 3100);
  });
}
