"""Prepara y verifica solo la limpieza comercial del inicio del Kindle."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

root = Path(__file__).resolve().parent.parent / '.codex_tmp'
sys.path.insert(0, str(root / 'kpp_env'))
from kpp_patch.patcher import KindleHBC
from kpp_patch.patcher.common import ALWAYS_FALSE
from hbctool.hbc.hbc84.translator import assemble

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--original', type=Path, default=root/'KPPMainApp-original.hbc')
parser.add_argument('--salida', type=Path, default=root/'KPPMainApp-clean.hbc')
parser.add_argument('--verify-original', action='store_true')
args = parser.parse_args()
original = args.original
assert original.resolve() != args.salida.resolve(), 'La salida debe ser una copia distinta del original.'
source_hash = hashlib.sha256(original.read_bytes()).hexdigest()
recipes = {
    '789c66aaeb37550042ca59e055a6d3ef2e849a49a31b017afcaaf9d93d8d8c48': ('chrome.topnavbar.button.open_store', -2),
    '50280b9576e000f483f029991acb5f08620dccb3f3b14615a3a28b80c7807e86': ('cart-filled', -12),
}
assert source_hash in recipes, 'El inicio original no corresponde a un firmware inspeccionado.'
app = KindleHBC(str(original))
assert app.hbcs.getVersion() == 84
templates = app.find_strings_regex(r'Template(\d*)Card', len('Template0Card'))
assert any(name == 'Template13Card' for _, _, name in templates)
targets = {}

render_functions = list(app.find_all_funcs_by_name('render'))
for _, _, template in templates:
    anchor = ('template26ParentStyle' if source_hash ==
        '50280b9576e000f483f029991acb5f08620dccb3f3b14615a3a28b80c7807e86'
        and template == 'Template26Card' else template)
    sid = app.find_string(anchor)
    component_name = template.removesuffix('Card')
    candidates = list(app.find_all_funcs_by_name(component_name)) + render_functions
    matches = []
    for fid, func in candidates:
        refs = {arg.arg_value for inst in func.instructions for arg in inst.arguments if arg.is_string}
        if sid in refs:
            names = {app.hbcs.getString(ref).val for ref in refs}
            assert 'createElement' in names
            matches.append(fid)
    assert len(matches) == 1, f'Componente comercial no identificado de forma única: {template}'
    targets[matches[0]] = ALWAYS_FALSE

store_functions = list(app.find_all_funcs_by_name('RenderTopNavBarButtons'))
assert len(store_functions) == 1
store_fid, store_func = store_functions[0]
store_label, store_delta = recipes[source_hash]
store_sid = app.find_string(store_label)
assert store_sid >= 0
store_indexes = [index for index, inst in enumerate(store_func.instructions)
                 if any(arg.is_string and arg.arg_value == store_sid for arg in inst.arguments)]
assert len(store_indexes) == 1
store_index = store_indexes[0] + store_delta
prior_instruction = store_func.instructions[store_index]
assert prior_instruction.instruction == 'LoadFromEnvironment'
assert len(assemble([prior_instruction])) == len(assemble(ALWAYS_FALSE)) == 4
store_code = store_func.instructions[:store_index] + ALWAYS_FALSE + store_func.instructions[store_index+1:]
prior_code = assemble(store_func.instructions)
patched_code = assemble(store_code)
store_offset = len(assemble(store_func.instructions[:store_index]))
assert len(prior_code) == len(patched_code)
assert prior_code[:store_offset] == patched_code[:store_offset]
assert prior_code[store_offset+4:] == patched_code[store_offset+4:]
targets[store_fid] = store_code

if args.verify_original:
    for fid, code in targets.items():
        assert app.check_func_patch(fid, code), 'El inicio original todavía muestra los accesos comerciales.'
    raise SystemExit(0)

before_functions = [app.hbcs.getFunction(fid, disasm=False).instructions
                    for fid in range(app.hbcs.getFunctionCount())]
before_strings = [app.hbcs.getString(sid).val for sid in range(app.hbcs.getStringCount())]
for fid, code in targets.items():
    assert app.patch_func_by_id(fid, code)
output = args.salida
output.parent.mkdir(parents=True,exist_ok=True)
app.dump(str(output))
data = output.read_bytes()
assert hashlib.sha1(original.read_bytes()[:-20]).digest() == original.read_bytes()[-20:]
assert len(data) == len(original.read_bytes())
output.write_bytes(data[:-20] + hashlib.sha1(data[:-20]).digest())
verified = KindleHBC(str(output))
assert verified.hbcs.getFunctionCount() == len(before_functions)
assert verified.hbcs.getStringCount() == len(before_strings)
changed_functions = []
for fid, prior in enumerate(before_functions):
    current = verified.hbcs.getFunction(fid, disasm=False).instructions
    if current != prior:
        changed_functions.append(fid)
        assert fid in targets, f'Función modificada fuera del alcance: {fid}'
for fid, code in targets.items():
    assert verified.check_func_patch(fid, code)
assert set(changed_functions) == set(targets)
changed_strings = 0
for sid, prior in enumerate(before_strings):
    current = verified.hbcs.getString(sid).val
    assert current == prior, f'Cadena modificada fuera del alcance: {sid}'
    changed_strings += current != prior
backup = Path(os.environ['LOCALAPPDATA']) / 'Todo/kindle_backups' / ('inicio-amazon-'+source_hash[:12])
backup.mkdir(parents=True, exist_ok=True)
for source in [original, output]:
    name = source.name if source == original else 'inicio-' + hashlib.sha256(source.read_bytes()).hexdigest()[:12] + '.hbc'
    target = backup / name
    if target.exists():
        assert target.read_bytes() == source.read_bytes()
    else:
        target.write_bytes(source.read_bytes())
report = {'originalSha256': source_hash,
          'parcheSha256': hashlib.sha256(output.read_bytes()).hexdigest(),
          'funcionesVerificadas': len(before_functions),
          'funcionesModificadas': changed_functions,
          'cadenasModificadas': changed_strings,
          'copiaLocal': str(backup)}
(backup / 'verificacion.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=False))
