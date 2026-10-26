import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todo/services/steam_service.dart';
import 'package:todo/application/state/todo_workspace.dart';

class MemorySecrets implements SteamSecretStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
  @override
  Future<void> delete() async => value = null;
}

void main() {
  const id = '76561198000000001';
  final key = List.filled(32, 'a').join();
  http.Response response(Object data) => http.Response(jsonEncode(data), 200,
      headers: {'content-type': 'application/json; charset=utf-8'});
  final library = {
    'response': {
      'game_count': 1,
      'games': [
        {'appid': 42, 'name': 'Juego de prueba', 'playtime_forever': 123}
      ]
    }
  };

  test('valida el formato antes de guardar o consultar', () async {
    final store = MemorySecrets();
    final service = SteamService(
        store: store,
        client: MockClient((_) async {
          fail('No debe consultar una clave inválida.');
        }));
    await expectLater(service.connect(id, 'incorrecta'), throwsFormatException);
    expect(store.value, isNull);
  });

  test('no confirma conexión ni guarda un perfil inaccesible', () async {
    final store = MemorySecrets();
    final service = SteamService(
        store: store,
        client: MockClient((_) async => response({'response': {}})));
    await expectLater(service.connect(id, key), throwsFormatException);
    expect(store.value, isNull);
  });

  test('guarda solo tras comprobar y reutiliza caché sin exponer la clave',
      () async {
    var requests = 0;
    final store = MemorySecrets();
    final service = SteamService(
        store: store,
        client: MockClient((request) async {
          requests++;
          expect(request.url.host, 'api.steampowered.com');
          expect(request.url.queryParameters.containsKey('key'), isFalse);
          expect(request.headers['x-webapi-key'], key);
          return response(library);
        }));
    await service.connect('https://steamcommunity.com/profiles/$id/', key);
    final games = await service.games();
    expect(games.single['playtime_minutes'], 123);
    expect(requests, 1);
    expect(jsonEncode(games), isNot(contains(key)));
    await service.link('ficha', 42);
    expect(await service.linkedApp('ficha', 'otro título', games), 42);
    await service.disconnect();
    expect(store.value, isNull);
    await expectLater(service.games(), throwsFormatException);
  });

  test('mezcla logros por identificador, conserva desconocidos y rareza',
      () async {
    final service = SteamService(
        store: MemorySecrets(),
        client: MockClient((r) async {
          if (r.url.path.contains('GetOwnedGames')) return response(library);
          if (r.url.path.contains('GetSchemaForGame')) {
            return response({
              'game': {
                'gameName': 'Juego',
                'availableGameStats': {
                  'achievements': [
                    {
                      'name': 'A',
                      'displayName': 'Primero',
                      'description': 'Descripción'
                    },
                    {'name': 'B', 'displayName': 'Segundo'},
                    {'name': 'C', 'displayName': 'Desconocido'},
                  ]
                }
              }
            });
          }
          if (r.url.path.contains('GetPlayerAchievements')) {
            return response({
              'playerstats': {
                'success': true,
                'achievements': [
                  {'apiname': 'B', 'achieved': 0, 'unlocktime': 0},
                  {'apiname': 'A', 'achieved': 1, 'unlocktime': 1000},
                ]
              }
            });
          }
          return response({
            'achievementpercentages': {
              'achievements': [
                {'name': 'A', 'percent': '12.5'}
              ]
            }
          });
        }));
    await service.connect(id, key);
    final result = await service.achievements(42);
    final achievements = result['achievements'] as List;
    expect(result['name'], 'Juego de prueba');
    expect(result['unlocked'], 1);
    expect(result['total'], 3);
    expect(result['completion_percent'], isNull);
    expect(achievements[0]['global_percent'], 12.5);
    expect(achievements[0]['unlock_time'], 1000);
    expect(achievements[1]['unlocked'], false);
    expect(achievements[2]['unlocked'], isNull);
    expect(result['queried_at'], isNotEmpty);
  });

  test('redacta errores de red que pudieran contener la clave', () async {
    final service = SteamService(
        store: MemorySecrets(),
        client: MockClient(
            (_) async => throw http.ClientException('secreto $key')));
    try {
      await service.connect(id, key);
      fail('Debe fallar.');
    } on FormatException catch (error) {
      expect(error.message, isNot(contains(key)));
    }
  });

  test('no enlaza títulos ambiguos', () async {
    final service = SteamService(store: MemorySecrets());
    expect(
        await service.linkedApp('ficha', 'Juego', [
          {'appid': 1, 'name': 'Juego'},
          {'appid': 2, 'name': 'Juego™'}
        ]),
        isNull);
    service.dispose();
  });

  test('el puente pagina y filtra Steam sin modificar el estado de Todo',
      () async {
    final service = SteamService(
        store: MemorySecrets(),
        client: MockClient((_) async => response(library)));
    await service.connect(id, key);
    final workspace = TodoWorkspace.createForTest(steamService: service);
    addTearDown(workspace.dispose);
    final result = await workspace.executeAgentCommand(
        'get_steam_games', {'query': 'PRUEBA', 'limit': 1});
    expect((result['games'] as List).single['appid'], 42);
    expect(result['source'], 'steam');
    expect(result['next_offset'], isNull);
    expect(workspace.libraryItems, isEmpty);
    await expectLater(
        workspace.executeAgentCommand('get_steam_games', {'limit': 101}),
        throwsFormatException);
    await expectLater(
        workspace.executeAgentCommand('get_steam_achievements', {'appid': 0}),
        throwsFormatException);
    await expectLater(
        workspace.executeAgentCommand('get_steam_games', {'key': key}),
        throwsFormatException);
  });

  test('un juego sin logros no se confunde con un perfil inaccesible',
      () async {
    final service = SteamService(
        store: MemorySecrets(),
        client: MockClient((r) async {
          if (r.url.path.contains('GetOwnedGames')) return response(library);
          if (r.url.path.contains('GetSchemaForGame')) {
            return response({
              'game': {'gameName': 'Juego sin logros'}
            });
          }
          return response({
            'playerstats': {'success': false}
          });
        }));
    addTearDown(service.dispose);
    await service.connect(id, key);
    final result = await service.achievements(42);
    expect(result['total'], 0);
    expect(result['completion_percent'], isNull);
  });

  test('completa la descripción de los logros ocultos desde la página pública',
      () async {
    final service = SteamService(
        store: MemorySecrets(),
        client: MockClient((r) async {
          if (r.url.host == 'steamcommunity.com') {
            return http.Response.bytes(
                utf8.encode(
                r'{\"achievements\":[{\"api_name\":\"Oculto\",\"name\":\"Secreto\",'
                r'\"description\":\"Entra en el décimo mundo.\",\"hidden\":true,'
                r'\"icon_achieved\":\"https://shared.fastly.steamstatic.com/a.jpg\",'
                r'\"icon_unachieved\":\"https://shared.fastly.steamstatic.com/b.jpg\"}]}'),
                200);
          }
          if (r.url.host != 'api.steampowered.com') {
            return http.Response('', 404);
          }
          if (r.url.path.contains('GetOwnedGames')) return response(library);
          if (r.url.path.contains('GetSchemaForGame')) {
            return response({
              'game': {
                'gameName': 'Juego de prueba',
                'availableGameStats': {
                  'achievements': [
                    {
                      'name': 'Oculto',
                      'displayName': 'Secreto',
                      'description': '',
                      'hidden': 1,
                    }
                  ]
                }
              }
            });
          }
          if (r.url.path.contains('GetPlayerAchievements')) {
            return response({
              'playerstats': {
                'success': true,
                'achievements': [
                  {'apiname': 'Oculto', 'achieved': 1, 'unlocktime': 1}
                ]
              }
            });
          }
          return response({});
        }));
    addTearDown(service.dispose);
    await service.connect(id, key);
    final result = await service.achievements(42);
    final item = (result['achievements'] as List).single as Map;
    expect(item['description'], 'Entra en el décimo mundo.');
  });
}
