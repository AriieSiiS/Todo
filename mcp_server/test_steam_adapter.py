"""Las consultas de Steam usan Todo abierto y no leen claves ni el snapshot."""

import unittest
from pathlib import Path
from unittest.mock import patch

from chatgpt_adapter import BridgeError, LocalBackend, tool_definitions


class SteamAdapterTest(unittest.TestCase):
    def test_link_requires_version_and_retry_identity_and_is_only_live(self):
        tools = {tool['name']: tool for tool in tool_definitions(live=True)}
        self.assertTrue(tools['get_steam_link']['annotations']['readOnlyHint'])
        link = tools['link_steam_game']
        self.assertFalse(link['annotations']['readOnlyHint'])
        self.assertTrue({'item_id', 'appid', 'expected_version', 'request_id'} <= set(link['inputSchema']['required']))
        self.assertNotIn('link_steam_game', {tool['name'] for tool in tool_definitions(sandbox=True)})
        backend = LocalBackend(Path('no-existe/estado.json'), live=True)
        arguments = {'item_id': 'juego', 'appid': 42, 'request_id': 'enlazar-001', 'expected_version': 'a' * 64}
        with patch.object(backend, '_bridge_call', return_value={'savedLocally': True}) as bridge:
            self.assertTrue(backend.call('link_steam_game', arguments)['savedLocally'])
            bridge.assert_called_once_with('link_steam_game', arguments)

    def test_exposes_read_only_external_queries_without_credentials(self):
        tools = {tool['name']: tool for tool in tool_definitions(live=True)}
        for name in ('get_steam_games', 'get_steam_achievements'):
            self.assertTrue(tools[name]['annotations']['readOnlyHint'])
            self.assertTrue(tools[name]['annotations']['openWorldHint'])
            self.assertNotIn('key', tools[name]['inputSchema']['properties'])
        self.assertNotIn('get_steam_games', {tool['name'] for tool in tool_definitions()})

    def test_forwards_results_and_fails_without_live_app(self):
        backend = LocalBackend(Path('no-existe/estado.json'), live=True)
        with patch.object(backend, '_bridge_call', return_value={'games': [], 'source': 'steam'}) as bridge:
            result = backend.call('get_steam_games', {'query': 'juego'})
            self.assertEqual(result['source'], 'steam')
            bridge.assert_called_once_with('get_steam_games', {'query': 'juego'}, read_only=True)
        with patch.object(backend, '_bridge_call', return_value=None), patch.object(backend, '_read') as read:
            with self.assertRaises(BridgeError):
                backend.call('get_steam_achievements', {'appid': 42})
            read.assert_not_called()


if __name__ == '__main__':
    unittest.main()
