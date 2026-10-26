"""Ejecuta las pruebas del complemento con LuaJIT en Windows, sin tocar datos reales."""
from pathlib import Path
import sys

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / '.codex_tmp' / 'kindle_python'))
from lupa.luajit21 import LuaRuntime

runtime = LuaRuntime(unpack_returned_tuples=True)
for source in (root / 'kindle' / 'todo.koplugin').glob('*.lua'):
    runtime.execute('assert(loadstring(...))', source.read_text(encoding='utf-8'))
for test in sorted((root / 'kindle' / 'tests').glob('*_test.lua')):
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.execute(test.read_text(encoding='utf-8'))
