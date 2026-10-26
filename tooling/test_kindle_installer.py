"""Valida el aprovisionamiento USB en una unidad sintética, sin tocar el Kindle."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')
root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='todo-kindle-instalador-') as temporary:
    base = Path(temporary)
    kindle = base / 'kindle'
    reader = kindle / 'koreader'
    config = base / 'config'
    for path in [kindle / 'system', reader / 'plugins', reader / 'settings/todo', config]:
        path.mkdir(parents=True, exist_ok=True)
    (kindle / 'system/version.txt').write_text('Kindle de prueba', encoding='utf-8')
    (reader / 'reader.lua').write_text('-- Instalación sintética', encoding='utf-8')
    certificate = b'certificado sintetico'
    (config / 'server.cer').write_bytes(certificate)
    fingerprint = hashlib.sha256(certificate).hexdigest()
    (config / 'status.json').write_text(json.dumps({
        'addresses': ['192.168.1.10'], 'certificateFingerprint': fingerprint,
    }), encoding='utf-8')
    (config / 'paired_devices.json').write_text(json.dumps({'devices': [
        {'id': 'android-anterior', 'tokenHash': 'conservar'}
    ]}), encoding='utf-8')
    state = reader / 'settings/todo/state.json'
    state.write_text('{"queue":[{"id":"marca-pendiente"}]}', encoding='utf-8')
    args = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
        str(root / 'tooling/install_kindle.ps1'), '-KindleRoot', str(kindle),
        '-ConfigDirectory', str(config), '-SourceDirectory', str(root / 'kindle/todo.koplugin')]
    first = subprocess.run(args, capture_output=True, encoding='utf-8')
    assert first.returncode == 0, first.stderr
    report = json.loads(first.stdout)
    assert report['estado'] == 'copiado_y_verificado'
    assert report['autenticacion'] == 'pendiente_de_abrir_en_kindle'
    credentials = json.loads((reader / 'settings/todo/config.json').read_text(encoding='utf-8'))
    second = subprocess.run(args, capture_output=True, encoding='utf-8')
    assert second.returncode == 0, second.stderr
    assert json.loads((reader / 'settings/todo/config.json').read_text(encoding='utf-8')) == credentials
    devices = json.loads((config / 'paired_devices.json').read_text(encoding='utf-8'))['devices']
    assert len(devices) == 2 and devices[0]['id'] == 'android-anterior'
    assert devices[1]['profile'] == 'kindle' and 'token' not in devices[1]
    assert state.read_text(encoding='utf-8') == '{"queue":[{"id":"marca-pendiente"}]}'
    for source in (root / 'kindle/todo.koplugin').glob('*.lua'):
        assert source.read_bytes() == (reader / 'plugins/todo.koplugin' / source.name).read_bytes()
    settings=reader/'settings.reader.lua'
    settings.write_text('return { ["device_id"] = "identidad-propia" }\n',encoding='utf-8')
    settings_before=settings.read_bytes()
    installed=subprocess.run(args,capture_output=True,encoding='utf-8')
    assert installed.returncode==0,installed.stderr
    assert not (reader/'patches').exists(), 'Actualizar el complemento no instala perfiles de traslado.'
    assert settings.read_bytes()==settings_before
    assert state.read_text(encoding='utf-8')=='{"queue":[{"id":"marca-pendiente"}]}'
    other=base/'otro-kindle'
    (other/'system').mkdir(parents=True)
    (other/'koreader/plugins').mkdir(parents=True)
    (other/'system/version.txt').write_text('Otro Kindle sintético',encoding='utf-8')
    (other/'koreader/reader.lua').write_text('-- Otro lector',encoding='utf-8')
    other_args=args.copy()
    other_args[other_args.index('-KindleRoot')+1]=str(other)
    installed=subprocess.run(other_args,capture_output=True,encoding='utf-8')
    assert installed.returncode==0,installed.stderr
    other_config=json.loads((other/'koreader/settings/todo/config.json').read_text(encoding='utf-8'))
    assert other_config['device_id']!=credentials['device_id'] and other_config['token']!=credentials['token']
    devices=json.loads((config/'paired_devices.json').read_text(encoding='utf-8'))['devices']
    assert len(devices)==3
    (config / 'status.json').write_text(json.dumps({
        'addresses': ['192.168.1.10'], 'certificateFingerprint': 'incorrecta',
    }), encoding='utf-8')
    assert subprocess.run(args, capture_output=True).returncode != 0
    print('Instalador: copia verificada, actualización sin duplicados, cola conservada y certificado comprobado.')
