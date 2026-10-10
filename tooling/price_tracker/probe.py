"""Comprobación técnica local, sin abrir Todo ni mostrar credenciales."""

import argparse
import json
import os
from pathlib import Path
from urllib import request

parser = argparse.ArgumentParser()
parser.add_argument('--enable-samples', action='store_true')
parser.add_argument('--details', action='store_true')
parser.add_argument('--recheck', action='store_true')
args = parser.parse_args()
runtime = Path(os.environ['LOCALAPPDATA']) / 'Todo' / 'price_tracker'
data_root = Path(os.environ['USERPROFILE']) / 'Documents' / 'Todo'
connection = json.loads((runtime / 'connection.json').read_text(encoding='utf-8'))


def call(path, method='GET', data=None, engine=False):
    port = connection['enginePort' if engine else 'port']
    headers = {'Content-Type': 'application/json'}
    if engine:
        headers['x-api-key'] = connection['engineToken']
        path = '/api/v1' + path
    else:
        headers['Authorization'] = 'Bearer ' + connection['token']
    req = request.Request(f'http://127.0.0.1:{port}{path}', method=method, headers=headers,
                          data=json.dumps(data).encode('utf-8') if data is not None else None)
    with request.urlopen(req, timeout=20) as response:
        return json.load(response)


if args.enable_samples:
    from service import product_url
    snapshot = json.loads((data_root / 'runtime' / 'todo_state.json').read_text(encoding='utf-8-sig'))
    count = 0
    for item in snapshot['shoppingItems']:
        if item.get('subcategory') != 'Proyectores' or item.get('status') == 'purchased' or item.get('archived'):
            continue
        try:
            product_url(item.get('sourceUrl', ''))
        except ValueError:
            continue
        call('/watches/' + item['id'], 'PUT', dict(item, enabled=True))
        count += 1
        if count == 2:
            break

state = call('/state')
if args.recheck:
    for item_id, watch in state['watches'].items():
        if watch['enabled']:
            call('/watches/' + item_id + '/check', 'POST')
print(json.dumps(state, ensure_ascii=True, indent=2))
if args.details:
    for uuid, watch in call('/watch', engine=True).items():
        info = call('/watch/' + uuid, engine=True)
        print(json.dumps({'title': info.get('title'), 'lastChecked': info.get('last_checked'),
                          'lastError': info.get('last_error'), 'historyCount': info.get('history_n'),
                          'fetchBackend': info.get('fetch_backend')}, ensure_ascii=True))
