"""Instala por el SSH emparejado el arranque de Todo, conservando una copia privada."""
from pathlib import Path
import argparse
import datetime
import hashlib
import ipaddress
import json
import os
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parent.parent
BASE = '/mnt/us/system/todo-koreader'
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', required=True)
    parser.add_argument('--private-directory', type=Path,
                        default=Path(os.environ['LOCALAPPDATA']) / 'Todo/kindle_ssh')
    parser.add_argument('--port', type=int, default=2222)
    args = parser.parse_args()
    ipaddress.IPv4Address(args.host)
    if not 1 <= args.port <= 65535:
        parser.error('El puerto no es válido.')
    private = args.private_directory
    common = ['-i', str(private / 'todo_kindle'), '-o', 'IdentitiesOnly=yes',
              '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=5',
              '-o', 'StrictHostKeyChecking=yes',
              '-o', 'KexAlgorithms=curve25519-sha256',
              '-o', 'UserKnownHostsFile=' + str(private / 'known_hosts')]
    target = 'root@' + args.host

    def remote(script, timeout=60):
        result = subprocess.run(['ssh.exe', '-T', '-p', str(args.port), *common, target, 'sh -s'],
                                input=script, capture_output=True, timeout=timeout)
        if result.returncode:
            raise RuntimeError(result.stderr.decode('utf-8', errors='replace') +
                               result.stdout.decode('utf-8', errors='replace'))
        return result.stdout

    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S')
    backup = Path(os.environ['LOCALAPPDATA']) / 'Todo/kindle_backups' / ('arranque-' + stamp)
    backup.mkdir(parents=True)
    data = remote(b'tar -czf - /mnt/us/koreader/settings.reader.lua /mnt/us/koreader/settings/todo /mnt/us/koreader/plugins/todo.koplugin /mnt/us/kmc/kpm/packages/koreader/launch.sh\n')
    archive = backup / 'antes.tar.gz'
    archive.write_bytes(data)
    with tarfile.open(archive, 'r:gz') as saved:
        assert 'mnt/us/koreader/settings/todo/state.json' in saved.getnames()
        assert 'mnt/us/kmc/kpm/packages/koreader/launch.sh' in saved.getnames()
        for member in saved.getmembers():
            if member.isfile():
                assert len(saved.extractfile(member).read()) == member.size

    sources = {path.name: path for path in (ROOT / 'kindle/boot').iterdir() if path.is_file()}
    for name in ['main.lua', 'arranque.lua']:
        sources[name] = ROOT / 'kindle/todo.koplugin' / name
    with tempfile.TemporaryDirectory(prefix='todo-kindle-') as directory:
        stage = Path(directory)
        hashes = {}
        for name, path in sources.items():
            payload = path.read_bytes().replace(b'\r\n', b'\n')
            (stage / name).write_bytes(payload)
            hashes[name] = hashlib.sha256(payload).hexdigest()
        (stage / 'archivos.sha256').write_text(
            ''.join(f'{value}  {name}\n' for name, value in hashes.items()), encoding='ascii', newline='\n')
        destinations = {'boot.sh': BASE + '/boot.sh', 'launch.sh': BASE + '/launch.sh',
                        'kpm-launch.sh': '/mnt/us/kmc/kpm/packages/koreader/launch.sh',
                        'todo-koreader.conf': '/etc/upstart/todo-koreader.conf',
                        'main.lua': '/mnt/us/koreader/plugins/todo.koplugin/main.lua',
                        'arranque.lua': '/mnt/us/koreader/plugins/todo.koplugin/arranque.lua'}
        (stage / 'instalados.sha256').write_text(
            ''.join(f'{hashes[name]}  {path}\n' for name, path in destinations.items()),
            encoding='ascii', newline='\n')
        remote(b'mkdir -p /mnt/us/system/todo-koreader/preparacion\n')
        commands = []
        for path in stage.iterdir():
            local = path.as_posix()
            assert not any(character in local for character in ['"', '\r', '\n'])
            commands.append(f'put "{local}" {BASE}/preparacion/{path.name}')
        batch = stage / 'transferencia.sftp'
        batch.write_text('\n'.join(commands) + '\n', encoding='utf-8', newline='\n')
        sent = subprocess.run(['sftp.exe', '-b', str(batch), '-s', '/mnt/us/koreader/sftp-server',
                               '-P', str(args.port), *common, target], capture_output=True, timeout=60)
        if sent.returncode:
            raise RuntimeError(sent.stderr.decode('utf-8', errors='replace'))
        result = remote((stage / 'install.sh').read_bytes())
    report = {'copia': str(archive), 'copiaSha256': hashlib.sha256(data).hexdigest(), 'archivos': hashes}
    (backup / 'instalacion.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(result.decode('utf-8'))
    print(json.dumps(report, ensure_ascii=False))


if __name__ == '__main__':
    main()
