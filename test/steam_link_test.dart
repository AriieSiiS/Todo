import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/services/steam_service.dart';

import 'steam_service_test.dart' show MemorySecrets;

void main() {
  test(
      'enlaza un juego ausente, valida versión y conserva el vínculo al reconectar',
      () async {
    final service = SteamService(
        store: MemorySecrets(),
        client: MockClient((request) async {
          Object data;
          if (request.url.path.contains('GetOwnedGames')) {
            data = {
              'response': {'game_count': 0}
            };
          } else if (request.url.path.contains('GetSchemaForGame')) {
            data = {
              'game': {
                'gameName': 'Nombre interno',
                'availableGameStats': {
                  'achievements': [
                    {'name': 'A', 'displayName': 'Primer logro'}
                  ]
                }
              }
            };
          } else {
            data = {
              'playerstats': {
                'success': true,
                'achievements': [
                  {'apiname': 'A', 'achieved': 1, 'unlocktime': 1000}
                ]
              }
            };
          }
          return http.Response(jsonEncode(data), 200);
        }));
    await service.connect('76561198000000001', List.filled(32, 'a').join());
    final now = DateTime(2026, 10, 25);
    final item = LibraryItem(
        id: 'juego-ausente',
        type: LibraryItemType.game,
        title: 'Juego traducido',
        createdAt: now,
        updatedAt: now);
    final workspace = TodoWorkspace.createForTest(
        steamService: service,
        snapshot: AppStateSnapshot.fromJson({
          'libraryItems': [item.toJson()]
        }));
    addTearDown(workspace.dispose);
    final initial = await workspace
        .executeAgentCommand('get_steam_link', {'item_id': item.id});
    final arguments = <String, dynamic>{
      'item_id': item.id,
      'appid': 999,
      'expected_version': (initial['link'] as Map)['link_version'],
      'request_id': 'enlazar-juego-001'
    };
    final saved =
        await workspace.executeAgentCommand('link_steam_game', arguments);
    expect(saved['savedLocally'], true);
    expect((saved['link'] as Map)['appid'], 999);
    expect(await workspace.executeAgentCommand('link_steam_game', arguments),
        saved);
    await expectLater(
        workspace.executeAgentCommand('link_steam_game', {
          ...arguments,
          'request_id': 'enlazar-juego-002',
          'appid': 998,
        }),
        throwsFormatException);
    expect(workspace.libraryItems.single.toJson(), item.toJson());
    final games = await service.games();
    expect(await service.linkedApp(item.id, item.title, games), 999);
    final linked = games.singleWhere((game) => game['appid'] == 999);
    expect(linked['playtime_minutes'], isNull);
    expect(linked['from_owned_games'], false);
    expect((await service.achievements(999))['name'], item.title);
    await service.connect('76561198000000001', '');
    expect((await service.games()).any((game) => game['appid'] == 999), true);
  });
}
