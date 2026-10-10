"""Consultas acotadas a las colecciones personales sin escrituras de snapshot."""
import json
import tempfile
import unittest
from pathlib import Path
from chatgpt_adapter import LocalBackend
import server as core


class ContentTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / 'estado.json'
        state = core.default_state()
        state.update(
            wardrobeItems=[{'id': 'camisa', 'name': 'Camisa azul', 'material': 'Algodón', 'imagePath': 'C:/privado/camisa.png'}, {'id': 'otra', 'name': 'Camisa blanca'}],
            libraryItems=[{'id': 'juego', 'title': 'Juego completado', 'type': 'game', 'status': 'completed', 'completedDate': '2026-10-02', 'rating': 8}],
            libraryGoals=[{'id': 'pendiente', 'title': 'Juego pendiente', 'status': 'pending'}],
            notes=[{'id': 'nota', 'content': 'Lista de ideas', 'status': 'inbox'}])
        self.path.write_text(json.dumps(state), encoding='utf-8')
        self.before = self.path.read_bytes()
        self.backend = LocalBackend(self.path, live=True)

    def tearDown(self):
        self.assertEqual(self.path.read_bytes(), self.before)
        self.temp.cleanup()

    def test_search_detail_and_pagination_preserve_registered_evidence(self):
        page = self.backend.call('browse_content', {'section': 'ropa', 'query': 'CAMISA algodon', 'limit': 1})
        self.assertEqual([item['id'] for item in page['items']], ['camisa'])
        self.assertEqual(page['source'], 'snapshot')
        detail = self.backend.call('get_content_item', {'section': 'ropa', 'item_id': 'camisa'})
        self.assertEqual(detail['item']['material'], 'Algodón')
        self.assertNotIn('C:/privado', json.dumps(detail))
        first = self.backend.call('browse_content', {'section': 'ropa', 'limit': 1})
        second = self.backend.call('browse_content', {'section': 'ropa', 'limit': 1, 'offset': first['next_offset']})
        self.assertEqual(second['items'][0]['id'], 'otra')
        self.assertIsNone(second['next_offset'])
        played = self.backend.call('get_content_item', {'section': 'biblioteca', 'item_id': 'juego'})['item']
        self.assertEqual(played['completedDate'], '2026-10-02')
        self.assertEqual(played['status'], 'completed')
        pending = self.backend.call('get_content_item', {'section': 'objetivos_biblioteca', 'item_id': 'pendiente'})['item']
        self.assertEqual(pending['status'], 'pending')

    def test_notes_have_versions_and_unavailable_sections_never_read_other_data(self):
        note = self.backend.call('get_note', {'note_id': 'nota'})['note']
        self.assertEqual(len(note['note_version']), 64)
        with self.assertRaises(ValueError):
            self.backend.call('browse_content', {'section': 'calendarSettings'})
        with self.assertRaises(ValueError):
            self.backend.call('browse_content', {'section': 'ropa', 'limit': 101})
        with self.assertRaises(ValueError):
            self.backend.call('get_content_item', {'section': 'ropa', 'item_id': 'inexistente'})
        with self.assertRaises(ValueError):
            self.backend.call('delete_note', {'note_id': 'nota', 'request_id': 'borrar-001', 'expected_version': note['note_version'], 'confirm': True})


if __name__ == '__main__':
    unittest.main()
