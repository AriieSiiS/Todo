"""Comprueba la salida real de Todo y el relevo al agente con datos sintéticos aislados."""
import ctypes
from ctypes import wintypes
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import urllib.request
import winreg

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

root = Path(__file__).resolve().parent.parent
exe = root / 'build/windows/x64/runner/Release/todo.exe'
dart = Path(shutil.which('dart'))
if dart.suffix.lower() == '.bat':
    dart = dart.parent / 'cache/dart-sdk/bin/dart.exe'
user32 = ctypes.WinDLL('user32', use_last_error=True)
user32.FindWindowW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR]
user32.FindWindowW.restype = wintypes.HWND
user32.IsWindowVisible.argtypes = [wintypes.HWND]
user32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
assert not user32.FindWindowW('FLUTTER_RUNNER_WIN32_WINDOW', 'todo'), 'Cierra Todo antes de esta prueba aislada.'
assert exe.is_file(), 'Falta la compilación de pruebas.'
shortcut = Path(os.environ['APPDATA']) / 'Microsoft/Windows/Start Menu/Programs/Todo/Todo.lnk'
old_shortcut = shortcut.read_bytes() if shortcut.exists() else None
registry_path = r'Software\Classes\CLSID\{cf7b9a93-31fc-45c5-8cee-31f61b7aac84}\LocalServer32'
try:
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, registry_path) as key:
        registry_value = winreg.QueryValueEx(key, '')
except FileNotFoundError:
    registry_value = None

def wait_for(condition, message, timeout=30):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        result = condition()
        if result:
            return result
        time.sleep(0.1)
    raise AssertionError(message)

with tempfile.TemporaryDirectory(prefix='todo-kindle-ventana-') as temporary:
    profile = Path(temporary)
    runtime = profile / 'Documents/Todo/runtime'
    runtime.mkdir(parents=True)
    local = profile / 'Local'
    config = local / 'Todo/lan_sync'
    config.mkdir(parents=True)
    (config / 'kindle_enabled').write_text('1', encoding='utf-8')
    (runtime / 'todo_state.json').write_text(json.dumps({'schemaVersion': 12, 'tasks': [
        {'id': 'prueba', 'title': 'Tarea sintética', 'status': 'active'}
    ]}), encoding='utf-8')
    env = {**os.environ, 'USERPROFILE': str(profile), 'LOCALAPPDATA': str(local),
           'APPDATA': str(profile / 'Roaming'), 'TODO_MCP_DISABLE_REMOTE': '1'}
    process = None
    try:
        def background_command(name, arguments, *, direct=False, failure=False):
            result = subprocess.run([str(dart), '--packages=' + str(root / 'lan_sync_agent/.dart_tool/package_config.json'),
                str(root / 'lan_sync_agent/test/fixtures/kindle_client.dart'), str(runtime)],
                input=json.dumps({'name': name, 'arguments': arguments, 'direct': direct}),
                capture_output=True, text=True, encoding='utf-8', timeout=20, env=env)
            if failure:
                assert result.returncode != 0 and 'Otro escritor' in result.stderr, result.stderr
                return None
            assert result.returncode == 0, result.stderr
            return json.loads(result.stdout)

        background = background_command('get_kindle_agenda', {})
        assert background['days'][0]['tasks'][0]['id'] == 'prueba'
        process = subprocess.Popen([str(exe)], cwd=exe.parent, env=env,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        session_file = runtime / 'agent_bridge_session.json'
        wait_for(lambda: session_file.exists(), 'No arrancó el puente de la aplicación.')
        session = json.loads(session_file.read_text(encoding='utf-8'))
        hwnd = wait_for(lambda: user32.FindWindowW('FLUTTER_RUNNER_WIN32_WINDOW', 'todo'), 'Falta la ventana nativa.')
        wait_for(lambda: user32.IsWindowVisible(hwnd), 'La aplicación no mostró su ventana.')
        second = subprocess.run([str(exe)], cwd=exe.parent, env=env, timeout=10)
        assert second.returncode == 0 and process.poll() is None
        assert background_command('get_kindle_books', {}) == {'books': []}
        background_command('get_kindle_books', {}, direct=True, failure=True)

        def command(name, arguments):
            request = urllib.request.Request(f'http://127.0.0.1:{session["port"]}/command',
                data=json.dumps({'name': name, 'arguments': arguments}).encode('utf-8'),
                headers={'Authorization': 'Bearer ' + session['token'], 'Content-Type': 'application/json'})
            with urllib.request.urlopen(request, timeout=10) as response:
                return json.load(response)

        agenda = command('get_kindle_agenda', {})
        task = next(task for task in agenda['days'][0]['tasks'] if task['id'] == 'prueba')
        result = command('complete_kindle_group', {'request_id': 'prueba-ventana-0001',
            'root_task_id': task['id'], 'occurrence_date': agenda['logical_date'],
            'expected_version': task['task_version'], 'task_ids': [task['id']]})
        assert result['savedLocally']
        user32.PostMessageW(hwnd, 0x0010, 0, 0)
        process.wait(timeout=20)
        assert process.returncode == 0, f'Cerrar la ventana terminó con error: {process.returncode:#x}.'
        saved = json.loads((runtime / 'todo_state.json').read_text(encoding='utf-8'))
        assert next(task for task in saved['tasks'] if task['id'] == 'prueba')['status'] == 'completed'
        assert 'prueba-ventana-0001' in saved['agentOperationReceipts']
        assert not session_file.exists(), 'Quedó una sesión activa después de salir.'
        assert background_command('complete_kindle_group', {'request_id': 'prueba-ventana-0001',
            'root_task_id': task['id'], 'occurrence_date': agenda['logical_date'],
            'expected_version': task['task_version'], 'task_ids': [task['id']]}) == result
        assert background_command('get_kindle_agenda', {})['days'][0]['tasks'] == []
        assert not user32.FindWindowW('FLUTTER_RUNNER_WIN32_WINDOW', 'todo')
        print('Windows: agente sin interfaz, instancia única, bloqueo, guardado, salida real y relevo verificados.')
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=10)
        if old_shortcut is not None:
            shortcut.write_bytes(old_shortcut)
        elif shortcut.exists():
            shortcut.unlink()
        if registry_value is not None:
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER, registry_path) as key:
                winreg.SetValueEx(key, '', 0, registry_value[1], registry_value[0])
