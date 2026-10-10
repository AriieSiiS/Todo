"""Arranque privado del motor fijado a changedetection.io 0.60.8."""

import argparse
import base64
import hashlib
import json
import logging
import os
from pathlib import Path
import secrets
import sys

import changedetectionio
from changedetectionio.store import ChangeDetectionStore

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--connection', type=Path, required=True)
    parser.add_argument('--store', type=Path, required=True)
    args = parser.parse_args()
    config = json.loads(args.connection.read_text(encoding='utf-8'))
    args.store.mkdir(parents=True, exist_ok=True)
    store = ChangeDetectionStore(datastore_path=str(args.store), include_default_watches=False,
                                 version_tag=changedetectionio.__version__)
    store.data['settings']['application']['api_access_token'] = config['engineToken']
    store.data['settings']['application']['api_access_token_enabled'] = True
    store._save_settings()
    # Bloquear también el panel web; la app usa únicamente la API autenticada.
    salt = secrets.token_bytes(32)
    key = hashlib.pbkdf2_hmac('sha256', config['engineToken'].encode(), salt, 100000)
    os.environ['SALTED_PASS'] = base64.b64encode(salt + key).decode('ascii')
    sys.argv = ['changedetection.io', '-d', str(args.store), '-h', '127.0.0.1',
                '-p', str(config['enginePort']), '-l', 'WARNING']
    logging.getLogger('werkzeug').setLevel(logging.ERROR)
    changedetectionio.main()


if __name__ == '__main__':
    main()
