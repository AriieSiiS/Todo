"""Comprueba el aprovisionamiento SSH sin utilizar el Kindle ni sus credenciales."""
from pathlib import Path
import json
import subprocess
import sys
import tempfile

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')
root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / '.codex_tmp/kindle_python'))
from lupa.luajit21 import LuaRuntime

script = root / 'tooling/prepare_kindle_ssh.ps1'
assert script.is_file(), 'Falta la preparación SSH por USB.'
with tempfile.TemporaryDirectory(prefix='todo-kindle-ssh-') as temporary:
    base = Path(temporary)
    kindle = base / 'kindle'
    reader = kindle / 'koreader'
    private = base / 'privado'
    (kindle / 'system').mkdir(parents=True)
    (reader / 'plugins/SSH.koplugin').mkdir(parents=True)
    (reader / 'settings/SSH').mkdir(parents=True)
    (kindle / 'system/version.txt').write_text('Kindle sintético', encoding='utf-8')
    (reader / 'reader.lua').write_text('-- Prueba', encoding='utf-8')
    (reader / 'dropbear').write_bytes(b'Servidor no ejecutable de prueba')
    (reader / 'plugins/SSH.koplugin/main.lua').write_text('-- Prueba', encoding='utf-8')
    settings = reader / 'settings.reader.lua'
    original = '''-- Preferencias de prueba
return {
    ["idioma"] = "Español: acción y ñ",
    ["SSH_allow_no_password"] = true,
    ["SSH_port"] = "2244",
    ["SSH_autostart"] = false,
    ["nested"] = {
        ["SSH_port"] = "otro valor",
    },
}
'''
    settings.write_text(original, encoding='utf-8')
    original_bytes = settings.read_bytes()
    keys = reader / 'settings/SSH/authorized_keys'
    previous_key = '# Clave anterior conservada\n'
    keys.write_text(previous_key, encoding='utf-8')
    previous_bytes = keys.read_bytes()
    args = ['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
            str(script), '-KindleRoot', str(kindle), '-PrivateDirectory', str(private)]
    result = subprocess.run(args, capture_output=True, encoding='utf-8')
    assert result.returncode == 0, result.stderr
    report = json.loads(result.stdout)
    assert report['estado'] == 'preparado_pendiente_de_abrir_koreader'
    assert report['puerto'] == 2244
    content = settings.read_text(encoding='utf-8-sig')
    config = LuaRuntime().execute(content)
    assert config['SSH_autostart'] is True
    assert config['SSH_key_only_auth'] is True
    assert config['SSH_allow_no_password'] is False
    assert config['SSH_port'] == '2244'
    assert config['idioma'] == 'Español: acción y ñ'
    assert config['nested']['SSH_port'] == 'otro valor'
    backup = Path(report['copia'])
    assert (backup / 'settings.reader.lua').read_bytes() == original_bytes
    assert (backup / 'authorized_keys').read_bytes() == previous_bytes
    public = (private / 'todo_kindle.pub').read_text().strip()
    secret = (private / 'todo_kindle').read_bytes()
    assert public.startswith('ecdsa-sha2-nistp256 ')
    assert keys.read_text(encoding='utf-8').startswith(previous_key)
    assert keys.read_text(encoding='utf-8').count(public) == 1
    assert not any(b'PRIVATE KEY' in p.read_bytes() for p in kindle.rglob('*') if p.is_file())
    second = subprocess.run(args, capture_output=True, encoding='utf-8')
    assert second.returncode == 0, second.stderr
    assert keys.read_text(encoding='utf-8').count(public) == 1
    assert (private / 'todo_kindle').read_bytes() == secret
    assert settings.read_text(encoding='utf-8-sig') == content
    invalid = content.replace('["SSH_port"] = "2244",', '["SSH_port"] = "inválido",')
    settings.write_text(invalid, encoding='utf-8')
    rejected = subprocess.run(args, capture_output=True, encoding='utf-8')
    assert rejected.returncode != 0
    assert settings.read_text(encoding='utf-8') == invalid
    print('SSH: clave privada solo en el PC, preferencias y claves conservadas, copia exacta y repetición sin duplicados.')
