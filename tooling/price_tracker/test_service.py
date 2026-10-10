import json
from pathlib import Path
import tempfile
import threading
import unittest
from urllib import request, error

from tooling.price_tracker.service import Tracker, make_server, parse_price, product_url


class Motor:
    def __init__(self):
        self.watches = {}
        self.created = []
        self.text = '299,99 €'

    def call(self, method, path, data=None, text=False):
        if method == 'POST':
            watch_id = str(len(self.created) + 1)
            self.created.append(data)
            self.watches[watch_id] = dict(data, last_checked=0, check_count=0, last_error='')
            return {'uuid': watch_id}
        watch_id = path.split('/')[1].split('?')[0]
        if method == 'PUT':
            self.watches[watch_id].update(data)
            return {}
        if '/history/' in path:
            return self.text
        return self.watches[watch_id]


class SeguimientoTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.motor = Motor()
        self.avisos = []
        self.tracker = Tracker(Path(self.temp.name), self.motor,
                               lambda event: self.avisos.append(event), clock=lambda: 10000)
        self.addCleanup(lambda: self.tracker.close())
        self.item = {'id': 'tableta', 'name': 'Tableta',
                     'sourceUrl': 'https://www.amazon.es/dp/B09VMPHY5W?ref=prueba',
                     'targetPrice': 250, 'status': 'saved'}

    def activar(self):
        self.tracker.configure(self.item, True)

    def lectura(self, timestamp, text):
        self.motor.text = text
        self.motor.watches['1']['last_checked'] = timestamp
        self.motor.watches['1']['check_count'] += 1
        self.tracker.poll()

    def test_precio_espanol_sin_confundir_cuotas_o_recomendaciones(self):
        self.assertEqual(parse_price('1.234,56 €'), 123456)
        self.assertEqual(parse_price('299,99\n€'), 29999)
        self.assertEqual(parse_price('€ 75'), 7500)
        self.assertEqual(parse_price('299,99 €\n299,99 €'), 29999)
        for text in ['25 €/mes', '299,99 € 199,99 €', 'Robot Check',
                     '29.99 USD', '', '0,00 €', 'Nan €']:
            with self.subTest(text=text), self.assertRaises(ValueError):
                parse_price(text)

    def test_solo_ficha_https_amazon_es_sin_ssrf(self):
        self.assertEqual(product_url(self.item['sourceUrl']),
                         'https://www.amazon.es/dp/B09VMPHY5W')
        for url in ['http://127.0.0.1/dp/B09VMPHY5W',
                    'https://www.amazon.es.ejemplo.com/dp/B09VMPHY5W',
                    'https://www.amazon.es/s?k=tableta',
                    'https://user:pass@www.amazon.es/dp/B09VMPHY5W',
                    'https://www.amazon.es:123/dp/B09VMPHY5W']:
            with self.subTest(url=url), self.assertRaises(ValueError):
                product_url(url)

    def test_programa_diario_y_desactiva_ia(self):
        self.activar()
        config = self.motor.created[0]
        self.assertEqual(config['time_between_check']['hours'], 24)
        self.assertFalse(config['time_between_check_use_default'])
        self.assertFalse(config['llm_backend_profile'])
        self.assertEqual(config['processor'], 'text_json_diff')
        self.assertTrue(config['include_filters'])

    def test_varias_opciones_una_ficha_con_historial_y_aviso_independientes(self):
        item = dict(self.item, offers=[
            {'name': 'Black', 'sourceUrl': self.item['sourceUrl']},
            {'name': 'Apollo', 'sourceUrl': 'https://www.amazon.es/dp/B094D3XL55'}])
        self.tracker.configure(item, True)
        self.assertEqual(len(self.motor.created), 2)
        for info in self.motor.watches.values():
            info.update(last_checked=100, check_count=1)
        self.motor.text = '17,49 €'
        self.tracker.poll()
        self.assertFalse(self.avisos)
        state = self.tracker.state()['watches']['tableta']
        self.assertEqual(len(state['offers']), 2)
        self.motor.watches['2'].update(last_checked=200, check_count=2)
        self.motor.text = '15,00 €'
        self.tracker.poll()
        self.assertEqual(len(self.avisos), 1)
        self.assertEqual(self.avisos[0]['itemId'], 'tableta')
        self.assertIn('Apollo', self.avisos[0]['name'])
        self.assertEqual(self.avisos[0]['url'], 'https://www.amazon.es/dp/B094D3XL55')
        offers = self.tracker.state()['watches']['tableta']['offers']
        self.assertEqual(offers[0]['currentPrice'], 17.49)
        self.assertEqual(offers[1]['currentPrice'], 15)
        self.tracker.configure(item, False)
        self.assertTrue(all(info['paused'] for info in self.motor.watches.values()))
        self.assertFalse(self.tracker.state()['watches']['tableta']['enabled'])
        self.tracker.configure(item, True)
        self.assertEqual(len(self.motor.created), 2)

    def test_quitar_opcion_pausa_su_monitor_sin_perder_el_historial(self):
        offers = [{'name': 'Black', 'sourceUrl': self.item['sourceUrl']},
                  {'name': 'Apollo', 'sourceUrl': 'https://www.amazon.es/dp/B094D3XL55'}]
        item = dict(self.item, offers=offers)
        self.tracker.configure(item, True)
        for info in self.motor.watches.values():
            info.update(last_checked=100, check_count=1)
        self.tracker.poll()
        snapshot = Path(self.temp.name) / 'snapshot.json'
        snapshot.write_text(json.dumps({'shoppingItems': [dict(item, offers=offers[:1])]}),
                            encoding='utf-8')
        self.tracker.reconcile(snapshot)
        self.assertTrue(self.motor.watches['2']['paused'])
        self.assertEqual(len(self.tracker.state()['watches']['tableta']['offers']), 1)
        self.tracker.configure(item, True)
        self.assertEqual(len(self.motor.created), 2)
        self.assertEqual(len(self.tracker.state()['watches']['tableta']['offers'][1]['history']), 1)
        snapshot.write_text(json.dumps({'shoppingItems': [dict(item, status='purchased')]}),
                            encoding='utf-8')
        self.tracker.reconcile(snapshot)
        self.assertTrue(all(info['paused'] for info in self.motor.watches.values()))

    def test_primera_lectura_sin_aviso_cambios_deduplicados_y_objetivo(self):
        self.activar()
        self.lectura(100, '299,99 €')
        self.assertEqual(self.avisos, [])
        self.lectura(200, '249,99 €')
        self.tracker.poll()
        self.assertEqual(len(self.avisos), 1)
        self.assertEqual(self.avisos[0]['previousPrice'], 299.99)
        self.assertTrue(self.avisos[0]['targetReached'])
        self.lectura(300, '259,99 €')
        self.assertEqual(len(self.avisos), 2)
        self.assertEqual(self.avisos[1]['previousPrice'], 249.99)
        state = self.tracker.state()
        self.assertEqual(state['watches']['tableta']['currentPrice'], 259.99)
        self.assertEqual(len(state['watches']['tableta']['history']), 3)

    def test_error_no_reutiliza_snapshot_antiguo_ni_borra_precio(self):
        self.activar()
        self.lectura(100, '299,99 €')
        self.motor.watches['1'].update(last_checked=200, last_error='403 forbidden')
        self.motor.watches['1']['check_count'] += 1
        self.tracker.poll()
        watch = self.tracker.state()['watches']['tableta']
        self.assertEqual(watch['currentPrice'], 299.99)
        self.assertTrue(watch['error'])
        self.assertEqual(len(watch['history']), 1)
        self.assertFalse(self.avisos)
        self.motor.watches['1']['last_error'] = ''
        self.lectura(300, '199,99 € 29,99 €')
        self.assertEqual(self.tracker.state()['watches']['tableta']['currentPrice'], 299.99)
        self.assertFalse(self.avisos)

    def test_pausa_y_compra_no_reactivan_seguimiento_ni_tocan_snapshot(self):
        self.activar()
        snapshot = Path(self.temp.name) / 'snapshot.json'
        snapshot.write_text(json.dumps({'shoppingItems': [dict(self.item, status='purchased')]}),
                            encoding='utf-8')
        original = snapshot.read_bytes()
        self.tracker.reconcile(snapshot)
        self.assertFalse(self.tracker.state()['watches']['tableta']['enabled'])
        self.assertTrue(self.motor.watches['1']['paused'])
        self.assertEqual(snapshot.read_bytes(), original)
        self.tracker.reconcile(snapshot)
        self.assertEqual(len(self.motor.created), 1)

    def test_enlace_nuevo_establece_otra_base_y_preserva_historial_anterior(self):
        self.activar()
        self.lectura(100, '299,99 €')
        self.tracker.configure(dict(self.item, sourceUrl='https://www.amazon.es/dp/B0F5WXH9XF'), True)
        self.assertIsNone(self.tracker.state()['watches']['tableta']['currentPrice'])
        self.assertTrue(self.motor.watches['1']['paused'])
        self.motor.watches['2']['last_checked'] = 200
        self.motor.watches['2']['check_count'] = 1
        self.motor.text = '599,99 €'
        self.tracker.poll()
        self.assertEqual(self.avisos, [])

    def test_reinicio_no_duplica_avisos(self):
        self.activar()
        self.lectura(100, '299,99 €')
        self.lectura(200, '249,99 €')
        self.tracker.close()
        self.tracker = Tracker(Path(self.temp.name), self.motor,
                               lambda event: self.avisos.append(event))
        self.tracker.poll()
        self.assertEqual(len(self.avisos), 1)

    def test_no_consume_un_check_en_curso_con_snapshot_anterior(self):
        self.activar()
        self.lectura(100, '299,99 €')
        self.motor.watches['1']['last_checked'] = 200
        self.tracker.poll()
        self.assertEqual(len(self.tracker.state()['watches']['tableta']['history']), 1)
        self.lectura(200, '249,99 €')
        self.assertEqual(len(self.avisos), 1)

    def test_respeta_notificaciones_desactivadas_pero_guarda_cambios(self):
        self.activar()
        snapshot = Path(self.temp.name) / 'snapshot.json'
        snapshot.write_text(json.dumps({'shoppingItems': [self.item],
                            'notificationSettings': {'notificationsEnabled': False}}), encoding='utf-8')
        self.tracker.reconcile(snapshot)
        self.lectura(100, '299,99 €')
        self.lectura(200, '249,99 €')
        self.assertFalse(self.avisos)
        self.assertEqual(len(self.tracker.state()['alerts']), 1)

    def test_api_local_autenticada_rechaza_navegador_sin_token(self):
        server = make_server(self.tracker, 'secreto-de-prueba', port=0)
        self.addCleanup(server.server_close)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.shutdown)
        url = f'http://127.0.0.1:{server.server_port}/state'
        with self.assertRaises(error.HTTPError) as failure:
            request.urlopen(url)
        self.assertEqual(failure.exception.code, 401)
        req = request.Request(url, headers={'Authorization': 'Bearer secreto-de-prueba'})
        with request.urlopen(req) as response:
            self.assertEqual(json.load(response)['watches'], {})
        req = request.Request(url, headers={'Authorization': 'Bearer secreto-de-prueba',
                                           'Origin': 'https://ejemplo.com'})
        with self.assertRaises(error.HTTPError) as failure:
            request.urlopen(req)
        self.assertEqual(failure.exception.code, 403)


if __name__ == '__main__':
    unittest.main()
