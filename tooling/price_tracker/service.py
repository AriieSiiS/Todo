"""API local de Compras sobre changedetection.io; no modifica el snapshot de Todo."""

import argparse
import hashlib
from datetime import datetime, timezone
from decimal import Decimal
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import logging
import math
import os
from pathlib import Path
import re
import secrets
import sqlite3
import socket
import subprocess
import sys
import threading
import time
from urllib import request, parse, error


ENGINE_PORT = 51247
API_PORT = 51248
PRICE_FILTER = (
    "xpath:((//*[@id='apex_desktop_newAccordionRow' or @id='corePriceDisplay_desktop_feature_div']"
    "//*[@id='apex-pricetopay-accessibility-label' and normalize-space()]) | "
    "(//*[@id='corePriceDisplay_desktop_feature_div' or "
    "@id='corePrice_feature_div' or @id='apex_desktop' or @id='buybox']"
    "//*[contains(concat(' ',normalize-space(@class),' '),' a-price ') and "
    "not(contains(concat(' ',normalize-space(@class),' '),' a-text-price '))]"
    "/*[contains(concat(' ',normalize-space(@class),' '),' a-offscreen ') and normalize-space()]))[1]"
)


def product_url(value):
    url = parse.urlsplit(value)
    if (url.scheme != 'https' or url.hostname not in ('amazon.es', 'www.amazon.es')
            or url.username or url.password or url.port not in (None, 443)):
        raise ValueError('Usa una ficha HTTPS de Amazon España, no un enlace de búsqueda.')
    asin = re.search(r'/(?:dp|gp/product)/([A-Z0-9]{10})(?:/|$)', url.path, re.I)
    if not asin:
        raise ValueError('Falta el enlace exacto del producto con su ASIN.')
    return f'https://www.amazon.es/dp/{asin.group(1).upper()}'


def parse_price(text):
    # Exigir euros y un único importe; nunca asumir que una cuota es el precio.
    if re.search(r'(?i)(/\s*mes|cuota|mensual|month|USD|\$)', text):
        raise ValueError('El contenido contiene cuotas u otra moneda, no un precio inequívoco.')
    amount = r'(\d{1,3}(?:\.\d{3})+(?:,\d{2})?|\d+(?:,\d{2})?)'
    matches = re.findall(amount + r'\s*€|€\s*' + amount, text)
    prices = {int(Decimal((a or b).replace('.', '').replace(',', '.')) * 100)
              for a, b in matches}
    if len(prices) != 1 or not 0 < next(iter(prices)) < 100000000:
        raise ValueError('No se ha encontrado un único precio válido en euros.')
    return prices.pop()


def iso(timestamp):
    return datetime.fromtimestamp(timestamp, timezone.utc).isoformat()

def shopping_offers(item):
    offers = item.get('offers') or [{'name': '', 'sourceUrl': item.get('sourceUrl', '')}]
    if not isinstance(offers, list) or len(offers) > 25:
        raise ValueError('Una ficha admite como máximo 25 opciones de compra.')
    result = {}
    for offer in offers:
        if not isinstance(offer, dict) or not isinstance(offer.get('sourceUrl'), str):
            raise ValueError('Cada opción necesita un enlace válido.')
        name = offer.get('name', '')
        if not isinstance(name, str):
            raise ValueError('El nombre de la opción debe ser texto.')
        url = product_url(offer['sourceUrl'])
        result.setdefault(url, {'name': name.strip()[:300], 'sourceUrl': url})
    return list(result.values())


class Engine:
    def __init__(self, token, port=ENGINE_PORT):
        self.token = token
        self.base = f'http://127.0.0.1:{port}/api/v1/'

    def call(self, method, path, data=None, text=False):
        req = request.Request(self.base + path, method=method,
                              headers={'x-api-key': self.token, 'Content-Type': 'application/json'},
                              data=json.dumps(data).encode('utf-8') if data is not None else None)
        with request.urlopen(req, timeout=15) as response:
            body = response.read(2000000).decode('utf-8')
            return body if text else json.loads(body)


class Tracker:
    def __init__(self, directory, engine, notifier, clock=time.time):
        directory.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(directory / 'prices.sqlite3', check_same_thread=False)
        self.db.row_factory = sqlite3.Row
        self.lock = threading.RLock()
        self.engine = engine
        self.notifier = notifier
        self.clock = clock
        self.engine_available = False
        self.notifications_enabled = True
        self.db.executescript('''
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS watches (
                id TEXT PRIMARY KEY, name TEXT NOT NULL, url TEXT NOT NULL,
                uuid TEXT NOT NULL, enabled INTEGER NOT NULL, target REAL,
                current INTEGER, checked INTEGER NOT NULL DEFAULT 0,
                success INTEGER, error TEXT NOT NULL DEFAULT '',
                requested REAL NOT NULL DEFAULT 0, engine_count INTEGER NOT NULL DEFAULT -1
            );
            CREATE TABLE IF NOT EXISTS observations (
                item_id TEXT NOT NULL, url TEXT NOT NULL, checked INTEGER NOT NULL,
                cents INTEGER NOT NULL, PRIMARY KEY (item_id,url,checked)
            );
            CREATE TABLE IF NOT EXISTS alerts (
                id INTEGER PRIMARY KEY AUTOINCREMENT, item_id TEXT NOT NULL,
                name TEXT NOT NULL, url TEXT NOT NULL, checked INTEGER NOT NULL,
                before_cents INTEGER NOT NULL, after_cents INTEGER NOT NULL,
                target_reached INTEGER NOT NULL, seen INTEGER NOT NULL DEFAULT 0,
                notification_error TEXT NOT NULL DEFAULT ''
            );
        ''')
        columns = {row['name'] for row in self.db.execute('PRAGMA table_info(watches)')}
        if 'engine_count' not in columns:
            self.db.execute('ALTER TABLE watches ADD COLUMN engine_count INTEGER NOT NULL DEFAULT -1')
            self.db.commit()
        for column in ('parent_id', 'offer_name'):
            if column not in columns:
                self.db.execute(f"ALTER TABLE watches ADD COLUMN {column} TEXT NOT NULL DEFAULT ''")
        if 'listed' not in columns:
            self.db.execute('ALTER TABLE watches ADD COLUMN listed INTEGER NOT NULL DEFAULT 1')
        self.db.commit()
        self.closed = False

    def close(self):
        if not self.closed:
            self.closed = True
            self.db.close()

    def configure(self, item, enabled):
        with self.lock:
            parent = item['id']
            if not re.fullmatch(r'[\w-]{1,160}', parent) or not isinstance(enabled, bool):
                raise ValueError('Identificador o estado de seguimiento no válido.')
            rows = self.db.execute('SELECT * FROM watches WHERE id=? OR parent_id=?',
                                   (parent, parent)).fetchall()
            if not enabled:
                for row in rows:
                    self._configure_offer({'id': row['id']}, False)
                return
            offers = shopping_offers(item)
            # Validar todos los enlaces antes de modificar cualquier monitor.
            primary = next((row['url'] for row in rows if row['id'] == parent
                            and any(offer['sourceUrl'] == row['url'] for offer in offers)),
                           offers[0]['sourceUrl'])
            wanted = set()
            for offer in offers:
                url = offer['sourceUrl']
                offer_id = parent if url == primary else 'offer-' + hashlib.sha256(
                    (parent + '\0' + url).encode('utf-8')).hexdigest()[:40]
                wanted.add(offer_id)
                title = item['name'] + (f" · {offer['name']}" if offer['name'] else '')
                self._configure_offer(dict(item, id=offer_id, name=title, sourceUrl=url), True)
                with self.db:
                    self.db.execute('UPDATE watches SET parent_id=?,offer_name=?,listed=1 WHERE id=?',
                                    (parent, offer['name'], offer_id))
            for row in rows:
                if row['id'] not in wanted:
                    if row['enabled']:
                        self._configure_offer({'id': row['id']}, False)
                    with self.db:
                        self.db.execute('UPDATE watches SET listed=0 WHERE id=?', (row['id'],))

    def _configure_offer(self, item, enabled):
        with self.lock:
            item_id = item['id']
            if not re.fullmatch(r'[\w-]{1,160}', item_id) or not isinstance(enabled, bool):
                raise ValueError('Identificador o estado de seguimiento no válido.')
            previous = self.db.execute('SELECT * FROM watches WHERE id=?', (item_id,)).fetchone()
            if not enabled:
                if previous:
                    self.engine.call('PUT', f"watch/{previous['uuid']}", {'paused': True})
                    with self.db:
                        self.db.execute('UPDATE watches SET enabled=0 WHERE id=?', (item_id,))
                return
            if item.get('archived') or item.get('status') == 'purchased':
                raise ValueError('El seguimiento solo se activa para compras pendientes.')
            url = product_url(item['sourceUrl'])
            name = str(item['name']).strip()[:500]
            if not name:
                raise ValueError('El producto necesita un nombre.')
            target = item.get('targetPrice')
            if target is not None and (not isinstance(target, (int, float)) or
                                       not math.isfinite(target) or target <= 0):
                raise ValueError('El precio objetivo debe ser positivo.')
            changed_url = previous is not None and previous['url'] != url
            if changed_url:
                self.engine.call('PUT', f"watch/{previous['uuid']}", {'paused': True})
            config = {
                'url': url, 'title': name, 'paused': False,
                'processor': 'text_json_diff', 'fetch_backend': 'html_webdriver',
                'include_filters': [PRICE_FILTER], 'notification_muted': True,
                'time_between_check': {'weeks': 0, 'days': 0, 'hours': 24, 'minutes': 0, 'seconds': 0},
                'time_between_check_use_default': False,
                'llm_backend_profile': False, 'llm_intent': '', 'llm_change_summary': '',
                'headers': {'Accept-Language': 'es-ES,es;q=0.9'},
            }
            if previous is None or changed_url:
                created = self.engine.call('POST', 'watch', config)
                watch_id = created['uuid']
                with self.db:
                    self.db.execute('''INSERT INTO watches(id,name,url,uuid,enabled,target)
                        VALUES(?,?,?,?,1,?) ON CONFLICT(id) DO UPDATE SET
                        name=excluded.name,url=excluded.url,uuid=excluded.uuid,enabled=1,
                        target=excluded.target,current=NULL,checked=0,success=NULL,error='',requested=0,engine_count=-1''',
                                    (item_id, name, url, watch_id, target))
            else:
                self.engine.call('PUT', f"watch/{previous['uuid']}", config)
                with self.db:
                    self.db.execute('UPDATE watches SET name=?,target=?,enabled=1 WHERE id=?',
                                    (name, target, item_id))

    def recheck(self, item_id):
        with self.lock:
            rows = self.db.execute('SELECT * FROM watches WHERE (id=? OR parent_id=?) AND enabled=1',
                                   (item_id, item_id)).fetchall()
            if not rows:
                raise ValueError('Activa el seguimiento antes de revisar el precio.')
            if any(self.clock() - row['requested'] < 60 for row in rows):
                raise ValueError('Espera un minuto antes de solicitar otra revisión.')
            for row in rows:
                self.engine.call('GET', f"watch/{row['uuid']}?recheck=1")
                with self.db:
                    self.db.execute('UPDATE watches SET requested=? WHERE id=?', (self.clock(), row['id']))

    def reconcile(self, snapshot):
        # Solo lectura: una escritura de Flutter en curso no debe pausar productos.
        try:
            data = json.loads(snapshot.read_text(encoding='utf-8-sig'))
            if not isinstance(data.get('shoppingItems'), list):
                return
            items = {item['id']: item for item in data['shoppingItems']}
        except (OSError, ValueError, KeyError, TypeError):
            return
        with self.lock:
            settings = data.get('notificationSettings')
            if isinstance(settings, dict):
                self.notifications_enabled = settings.get('notificationsEnabled') is True
            parents = {row['parent_id'] or row['id'] for row in
                       self.db.execute('SELECT * FROM watches WHERE enabled=1').fetchall()}
            for parent in parents:
                item = items.get(parent)
                if item is None or item.get('archived') or item.get('status') == 'purchased':
                    self.configure({'id': parent}, False)
                    continue
                try:
                    offers = shopping_offers(item)
                except (ValueError, TypeError):
                    self.configure({'id': parent}, False)
                    continue
                rows = self.db.execute('SELECT * FROM watches WHERE (id=? OR parent_id=?) AND enabled=1',
                                       (parent, parent)).fetchall()
                expected = {(offer['sourceUrl'], item['name'] +
                            (f" · {offer['name']}" if offer['name'] else '')) for offer in offers}
                if (expected != {(row['url'], row['name']) for row in rows}
                        or any(item.get('targetPrice') != row['target'] for row in rows)):
                    self.configure(item, True)

    def poll(self):
        with self.lock:
            for row in self.db.execute('SELECT * FROM watches WHERE enabled=1').fetchall():
                checked = row['checked']
                count = row['engine_count']
                try:
                    info = self.engine.call('GET', f"watch/{row['uuid']}")
                    self.engine_available = True
                    checked = int(info.get('last_checked') or 0)
                    # last_checked se adelanta al iniciar la carga; check_count al terminarla.
                    count = int(info.get('check_count') or 0)
                    if not checked or count == 0 or count <= row['engine_count']:
                        continue
                    failure = info.get('last_error')
                    if failure:
                        raise ValueError('Amazon no ha devuelto un precio legible (bloqueo o filtro sin resultados).')
                    cents = parse_price(self.engine.call('GET', f"watch/{row['uuid']}/history/latest", text=True))
                    event = None
                    with self.db:
                        self.db.execute('INSERT OR IGNORE INTO observations VALUES(?,?,?,?)',
                                        (row['id'], row['url'], checked, cents))
                        self.db.execute('UPDATE watches SET current=?,checked=?,success=?,error=?,engine_count=? WHERE id=?',
                                        (cents, checked, checked, '', count, row['id']))
                        if row['current'] is not None and cents != row['current']:
                            reached = row['target'] is not None and cents <= round(row['target'] * 100)
                            cursor = self.db.execute('''INSERT INTO alerts
                                (item_id,name,url,checked,before_cents,after_cents,target_reached)
                                VALUES(?,?,?,?,?,?,?)''',
                                (row['parent_id'] or row['id'], row['name'], row['url'], checked, row['current'], cents, reached))
                            event = {'id': cursor.lastrowid, 'itemId': row['parent_id'] or row['id'], 'name': row['name'],
                                     'url': row['url'], 'previousPrice': row['current'] / 100,
                                     'price': cents / 100, 'targetReached': reached, 'checkedAt': iso(checked)}
                    if event:
                        try:
                            if self.notifications_enabled:
                                self.notifier(event)
                        except Exception:
                            # El cambio sigue visible en Compras aunque Windows no permita el aviso.
                            with self.db:
                                self.db.execute('UPDATE alerts SET notification_error=? WHERE id=?',
                                                ('Windows no pudo mostrar el aviso.', event['id']))
                except ValueError as failure:
                    with self.db:
                        self.db.execute('UPDATE watches SET checked=?,error=?,engine_count=? WHERE id=?',
                                        (checked, str(failure), count, row['id']))
                except (OSError, error.URLError, KeyError):
                    self.engine_available = False
                    with self.db:
                        self.db.execute('UPDATE watches SET error=? WHERE id=?',
                                        ('No se pudo conectar con el motor de seguimiento.', row['id']))

    def state(self):
        with self.lock:
            watches = {}
            for row in self.db.execute('SELECT * FROM watches WHERE listed=1').fetchall():
                history = self.db.execute('''SELECT checked,cents FROM observations
                    WHERE item_id=? AND url=? ORDER BY checked DESC LIMIT 30''', (row['id'], row['url']))
                parent = row['parent_id'] or row['id']
                entry = {
                    'name': row['offer_name'],
                    'enabled': bool(row['enabled']), 'url': row['url'],
                    'currentPrice': row['current'] / 100 if row['current'] is not None else None,
                    'checkedAt': iso(row['checked']) if row['checked'] else None,
                    'lastSuccessAt': iso(row['success']) if row['success'] else None,
                    'error': row['error'], 'targetPrice': row['target'],
                    'history': [{'checkedAt': iso(h['checked']), 'price': h['cents'] / 100} for h in history],
                }
                if parent not in watches:
                    watches[parent] = dict(entry, offers=[])
                watches[parent]['offers'].append(entry)
            for watch in watches.values():
                # No convertir el precio de un pack en el precio de otra variante.
                if len(watch['offers']) > 1:
                    watch['enabled'] = any(offer['enabled'] for offer in watch['offers'])
                    watch['currentPrice'] = None
                    watch['history'] = []
                    watch['error'] = ''
            alerts = [{'id': row['id'], 'itemId': row['item_id'], 'name': row['name'],
                       'url': row['url'], 'checkedAt': iso(row['checked']),
                       'previousPrice': row['before_cents'] / 100, 'price': row['after_cents'] / 100,
                       'targetReached': bool(row['target_reached']), 'seen': bool(row['seen']),
                       'notificationError': row['notification_error']}
                      for row in self.db.execute('SELECT * FROM alerts ORDER BY id DESC LIMIT 100')]
            return {'engineAvailable': self.engine_available, 'intervalHours': 24,
                    'notificationsEnabled': self.notifications_enabled,
                    'watches': watches, 'alerts': alerts}

    def mark_seen(self):
        with self.lock, self.db:
            self.db.execute('UPDATE alerts SET seen=1')


def make_server(tracker, token, port=API_PORT):
    class Handler(BaseHTTPRequestHandler):
        def setup(self):
            super().setup()
            self.connection.settimeout(15)

        def log_message(self, *_):
            pass

        def send_json(self, status, data):
            body = json.dumps(data, ensure_ascii=False, allow_nan=False).encode('utf-8')
            self.send_response(status)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def handle_api(self):
            if self.headers.get('Origin') or self.headers.get('Host') != f'127.0.0.1:{self.server.server_port}':
                return self.send_json(403, {'error': 'Origen no permitido.'})
            if not secrets.compare_digest(self.headers.get('Authorization', ''), f'Bearer {token}'):
                return self.send_json(401, {'error': 'Autenticación local necesaria.'})
            try:
                if self.command == 'GET' and self.path in ('/health', '/state'):
                    return self.send_json(200, tracker.state())
                if self.command == 'POST' and self.path == '/alerts/read':
                    tracker.mark_seen()
                    return self.send_json(200, {})
                match = re.fullmatch(r'/watches/([\w-]{1,160})(/check)?', self.path)
                if match and self.command == 'POST' and match[2]:
                    tracker.recheck(match[1])
                    return self.send_json(202, {})
                if match and self.command == 'PUT' and not match[2]:
                    size = int(self.headers.get('Content-Length', '0'))
                    if not 0 < size <= 16384:
                        raise ValueError('Petición demasiado grande o vacía.')
                    body = json.loads(self.rfile.read(size))
                    body['id'] = match[1]
                    tracker.configure(body, body['enabled'])
                    return self.send_json(200, tracker.state())
                return self.send_json(404, {'error': 'Operación no disponible.'})
            except (ValueError, KeyError, TypeError) as failure:
                message = str(failure) if isinstance(failure, ValueError) else 'Petición no válida.'
                return self.send_json(400, {'error': message})
            except (OSError, error.URLError):
                return self.send_json(503, {'error': 'El motor no está disponible. Vuelve a intentarlo.'})

        do_GET = do_POST = do_PUT = handle_api

    server = ThreadingHTTPServer(('127.0.0.1', port), Handler)
    server.daemon_threads = True
    return server


def notify(event):
    formatter = lambda value: f'{value:.2f}'.replace('.', ',') + ' €'
    title = 'Bajada de precio' if event['price'] < event['previousPrice'] else 'Cambio de precio'
    body = f"{event['name']}: {formatter(event['previousPrice'])} → {formatter(event['price'])}"
    if event['targetReached']:
        body += '. Dentro de tu precio objetivo.'
    result = subprocess.run(['powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass',
                             '-File', str(Path(__file__).with_name('notify.ps1')),
                             '-Title', title, '-Body', body, '-Url', event['url']],
                            creationflags=subprocess.CREATE_NO_WINDOW, capture_output=True, timeout=20)
    if result.returncode:
        raise RuntimeError('Windows no pudo entregar el aviso.')


def load_config(directory):
    path = directory / 'connection.json'
    if path.exists():
        return json.loads(path.read_text(encoding='utf-8'))
    config = {'port': API_PORT, 'token': secrets.token_urlsafe(32),
              'engineToken': secrets.token_hex(32), 'enginePort': ENGINE_PORT}
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(config), encoding='utf-8')
    temporary.replace(path)
    return config


def free_port():
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 0))
        return probe.getsockname()[1]


def start_browser(runtime):
    # Usar Edge instalado, con perfil independiente, sin plugins de evasión.
    edge = Path(os.environ.get('PROGRAMFILES(X86)', 'C:/Program Files (x86)')) / 'Microsoft/Edge/Application/msedge.exe'
    if not edge.is_file():
        raise RuntimeError('No se encontró Microsoft Edge para revisar los precios.')
    port = free_port()
    process = subprocess.Popen([str(edge), '--headless=new',
                                '--remote-debugging-address=127.0.0.1',
                                f'--remote-debugging-port={port}',
                                f'--user-data-dir={runtime / "browser-profile"}',
                                '--no-first-run', '--no-default-browser-check', 'about:blank'],
                               creationflags=subprocess.CREATE_NO_WINDOW,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for _ in range(30):
        try:
            with request.urlopen(f'http://127.0.0.1:{port}/json/version', timeout=1) as response:
                websocket = json.load(response)['webSocketDebuggerUrl']
                return process, websocket
        except (OSError, ValueError):
            time.sleep(.5)
    process.terminate()
    raise RuntimeError('Microsoft Edge no pudo arrancar para revisar precios.')


def create_process_job():
    # El cierre del supervisor (también forzado) debe cerrar sus procesos hijos.
    import ctypes
    from ctypes import wintypes

    class BasicLimits(ctypes.Structure):
        _fields_ = [('processTime', ctypes.c_int64), ('jobTime', ctypes.c_int64),
                    ('flags', wintypes.DWORD), ('minWorking', ctypes.c_size_t),
                    ('maxWorking', ctypes.c_size_t), ('activeProcesses', wintypes.DWORD),
                    ('affinity', ctypes.c_size_t), ('priority', wintypes.DWORD),
                    ('scheduling', wintypes.DWORD)]

    class IoCounters(ctypes.Structure):
        _fields_ = [(name, ctypes.c_uint64) for name in
                    ('readOps', 'writeOps', 'otherOps', 'readBytes', 'writeBytes', 'otherBytes')]

    class ExtendedLimits(ctypes.Structure):
        _fields_ = [('basic', BasicLimits), ('io', IoCounters),
                    ('processMemory', ctypes.c_size_t), ('jobMemory', ctypes.c_size_t),
                    ('peakProcessMemory', ctypes.c_size_t), ('peakJobMemory', ctypes.c_size_t)]

    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.CreateJobObjectW.restype = wintypes.HANDLE
    kernel.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
    kernel.SetInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]
    kernel.GetCurrentProcess.restype = wintypes.HANDLE
    kernel.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
    job = kernel.CreateJobObjectW(None, None)
    limits = ExtendedLimits()
    limits.basic.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
    if not job or not kernel.SetInformationJobObject(job, 9, ctypes.byref(limits), ctypes.sizeof(limits)):
        raise ctypes.WinError(ctypes.get_last_error())
    if not kernel.AssignProcessToJobObject(job, kernel.GetCurrentProcess()):
        raise ctypes.WinError(ctypes.get_last_error())
    return job


def main():
    parser = argparse.ArgumentParser(description='Seguimiento local de precios de Todo')
    parser.add_argument('--runtime', type=Path, required=True)
    parser.add_argument('--data-root', type=Path, required=True)
    args = parser.parse_args()
    args.runtime.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(filename=args.runtime / 'service.log', level=logging.INFO,
                        format='%(asctime)s %(levelname)s %(message)s', encoding='utf-8')
    process_job = create_process_job()
    # Windows puede reservar rangos de puertos: elegir puertos disponibles.
    import msvcrt
    lock_file = open(args.runtime / 'service.lock', 'a+b')
    lock_file.seek(0)
    msvcrt.locking(lock_file.fileno(), msvcrt.LK_NBLCK, 1)
    config = load_config(args.runtime)
    config['enginePort'] = free_port()
    engine = Engine(config['engineToken'], config['enginePort'])
    data = args.data_root / 'shopping' / 'price_tracking'
    tracker = Tracker(data, engine, notify)
    server = make_server(tracker, config['token'], 0)
    config['port'] = server.server_port
    config['pid'] = os.getpid()
    temporary = args.runtime / 'connection.tmp'
    temporary.write_text(json.dumps(config), encoding='utf-8')
    temporary.replace(args.runtime / 'connection.json')
    threading.Thread(target=server.serve_forever, daemon=True).start()
    child = None
    browser = None
    browser_url = None
    engine_log = open(args.runtime / 'engine.log', 'a', encoding='utf-8')
    try:
        while True:
            if browser is not None and browser.poll() is not None and child is not None and child.poll() is None:
                child.terminate()
                child.wait(timeout=10)
            try:
                engine.call('GET', 'watch')
                tracker.engine_available = True
            except (OSError, ValueError):
                tracker.engine_available = False
                if child is None or child.poll() is not None:
                    if browser is None or browser.poll() is not None:
                        browser, browser_url = start_browser(args.runtime)
                    environment = os.environ.copy()
                    environment['DISABLE_VERSION_CHECK'] = '1'
                    environment['FETCH_WORKERS'] = '1'
                    environment['PLAYWRIGHT_DRIVER_URL'] = browser_url
                    environment['PLAYWRIGHT_BYPASS_CSP'] = 'false'
                    environment['FAST_PUPPETEER_CHROME_FETCHER'] = 'false'
                    # No se configura ningún proveedor de IA ni clave de modelos.
                    child = subprocess.Popen([
                        str(Path(sys.executable).with_name('python.exe')),
                        str(Path(__file__).with_name('engine.py')),
                        '--connection', str(args.runtime / 'connection.json'),
                        '--store', str(data / 'changedetection'),
                    ], env=environment, stdout=engine_log, stderr=engine_log,
                       creationflags=subprocess.CREATE_NO_WINDOW)
                    logging.info('Motor de seguimiento iniciado.')
            if tracker.engine_available:
                tracker.reconcile(args.data_root / 'runtime' / 'todo_state.json')
                tracker.poll()
            time.sleep(10)
    finally:
        server.shutdown()
        if child and child.poll() is None:
            child.terminate()
        if browser and browser.poll() is None:
            browser.terminate()
        tracker.close()
        engine_log.close()
        lock_file.close()


if __name__ == '__main__':
    try:
        main()
    except Exception:
        logging.exception('El servicio de precios no pudo continuar.')
        raise
