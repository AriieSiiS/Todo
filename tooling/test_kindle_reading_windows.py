"""Comprueba la lectura en el ejecutable de Windows con una biblioteca aislada."""
import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import urllib.request
import winreg

ROOT=Path(__file__).resolve().parent.parent
EXE=ROOT/'build/windows/x64/runner/Release/todo.exe'
u=ctypes.WinDLL('user32',use_last_error=True)
u.FindWindowW.argtypes=[wintypes.LPCWSTR,wintypes.LPCWSTR]
u.FindWindowW.restype=wintypes.HWND
u.PostMessageW.argtypes=[wintypes.HWND,wintypes.UINT,wintypes.WPARAM,wintypes.LPARAM]
assert not u.FindWindowW('FLUTTER_RUNNER_WIN32_WINDOW','todo'),'Cierra Todo antes de probar el perfil aislado.'
shortcut=Path(os.environ['APPDATA'])/'Microsoft/Windows/Start Menu/Programs/Todo/Todo.lnk'
previous_shortcut=shortcut.read_bytes() if shortcut.exists() else None
registry_path=r'Software\Classes\CLSID\{cf7b9a93-31fc-45c5-8cee-31f61b7aac84}\LocalServer32'
try:
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER,registry_path) as key:
        previous_registry=winreg.QueryValueEx(key,'')
except FileNotFoundError:
    previous_registry=None

def wait(condition,message):
    end=time.monotonic()+30
    while time.monotonic()<end:
        value=condition()
        if value: return value
        time.sleep(.1)
    raise AssertionError(message)

process=None
try:
    with tempfile.TemporaryDirectory(prefix='todo-lectura-windows-') as temporary:
        profile=Path(temporary)
        runtime=profile/'Documents/Todo/runtime'; runtime.mkdir(parents=True)
        local=profile/'Local'
        config=local/'Todo/lan_sync'; config.mkdir(parents=True)
        (config/'kindle_enabled').write_text('1',encoding='utf-8')
        state=runtime/'todo_state.json'
        state.write_text(json.dumps({'schemaVersion':12,'libraryItems':[{
            'id':'libro-prueba','type':'book','title':'Lectura de prueba','author':'Autora de prueba',
            'status':'inProgress','createdAt':'2026-10-24T00:00:00','updatedAt':'2026-10-24T00:00:00'}]}),encoding='utf-8')
        env={**os.environ,'USERPROFILE':str(profile),'LOCALAPPDATA':str(local),
             'APPDATA':str(profile/'Roaming'),'TODO_MCP_DISABLE_REMOTE':'1'}
        def launch():
            global process
            process=subprocess.Popen([str(EXE)],cwd=EXE.parent,env=env,creationflags=subprocess.CREATE_NO_WINDOW)
            wait(lambda:(runtime/'agent_bridge_session.json').exists(),'No arranca el puente aislado.')
            return json.loads((runtime/'agent_bridge_session.json').read_text(encoding='utf-8'))
        session=launch()
        def command(args):
            request=urllib.request.Request(f'http://127.0.0.1:{session["port"]}/command',
                data=json.dumps({'name':'sync_kindle_book','arguments':args}).encode('utf-8'),
                headers={'Authorization':'Bearer '+session['token'],'Content-Type':'application/json'})
            with urllib.request.urlopen(request,timeout=15) as response: return json.load(response)
        event={'request_id':'lectura-binario-0001','source_id':'kindle-prueba','sequence':1,
            'document_id':'a'*32,'title':'Lectura de prueba','author':'Autora de prueba',
            'observed_at':int(time.time()),'progress':.14,'page':'42','total_pages':1300,'position':'/p[42]',
            'quotes':[{'anchor':'/p[5]','text':'Una cita guardada en el Kindle.', 'note':'Mi nota.',
                'page':'5','chapter':'Capítulo uno','created_at':'2026-10-24 12:00:00'}]}
        receipt=command(event); assert receipt['savedLocally']
        assert command(event)==receipt
        def close():
            hwnd=wait(lambda:u.FindWindowW('FLUTTER_RUNNER_WIN32_WINDOW','todo'),'Falta la ventana de pruebas.')
            assert u.PostMessageW(hwnd,0x0010,0,0)
            process.wait(timeout=20)
            assert process.returncode==0
        close()
        data=json.loads(state.read_text(encoding='utf-8'))['libraryItems'][0]
        assert data['reading']['progress']==.14 and len(data['reading']['quotes'])==1
        assert data['reading']['totalPages']==1300 and data['reading']['page']=='42'
        assert data['reading']['quotes'][0]['note']=='Mi nota.' and data['status']=='inProgress'
        session=launch(); assert command(event)==receipt; close()
        assert len(json.loads(state.read_text(encoding='utf-8'))['libraryItems'][0]['reading']['quotes'])==1
        print('Windows: 14 %, cita, nota, persistencia y reintento tras reinicio verificados con datos aislados.')
finally:
    if process is not None and process.poll() is None:
        process.terminate(); process.wait(timeout=10)
    if previous_shortcut is not None: shortcut.write_bytes(previous_shortcut)
    elif shortcut.exists(): shortcut.unlink()
    if previous_registry is not None:
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER,registry_path) as key:
            winreg.SetValueEx(key,'',0,previous_registry[1],previous_registry[0])
