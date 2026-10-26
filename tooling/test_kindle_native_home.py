"""Comprueba la activación reversible con archivos sintéticos y servicios simulados."""
from pathlib import Path
import hashlib
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
BASH = Path('C:/Program Files/Git/bin/bash.exe')
SOURCE = ROOT / 'kindle/native-home/activar.sh'
HARNESS = ROOT / 'kindle/tests/native_home_commands.sh'
ORIGINAL = b'inicio original de prueba'
PATCHED = b'inicio sin promociones de prueba'


class ActivacionInicioTest(unittest.TestCase):
    original_sha='789c66aaeb37550042ca59e055a6d3ef2e849a49a31b017afcaaf9d93d8d8c48'
    patched_sha='ece6c579fb0e75811f691ebbc21cba826898f207633e2bf6b6a3bdff864dbd99'

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.base = self.root / 'configuracion'
        self.base.mkdir()
        self.target = self.root / 'inicio-sistema'
        self.target.write_bytes(ORIGINAL)
        self.image = self.base / ('inicio-'+self.patched_sha[:12]+'.hbc')
        self.image.write_bytes(PATCHED)
        (self.base / 'validado').touch()
        source = SOURCE.read_text(encoding='utf-8')
        replacements = {
            '/mnt/us/system/todo-native-home': self.base.as_posix(),
            '/app/KPPMainApp/js/KPPMainApp.js.hbc': self.target.as_posix(),
            '/tmp/todo-native-home.lock': (self.root / 'bloqueo').as_posix(),
            self.original_sha: hashlib.sha256(ORIGINAL).hexdigest(),
            self.patched_sha: hashlib.sha256(PATCHED).hexdigest(),
        }
        for before, after in replacements.items():
            self.assertIn(before, source)
            source = source.replace(before, after)
        self.script = self.root / 'activar.sh'
        self.script.write_text(source, encoding='utf-8', newline='\n')
        source=(ROOT/'kindle/native-home/desactivar.sh').read_text(encoding='utf-8')
        for before,after in replacements.items():
            source=source.replace(before,after)
        mounts=self.root/'montajes'
        mounts.write_text('simulado '+self.target.as_posix()+' simulado\n',encoding='utf-8')
        source=source.replace('/proc/mounts',mounts.as_posix())
        self.deactivation=self.root/'desactivar.sh'
        self.deactivation.write_text(source,encoding='utf-8',newline='\n')

    def run_activation(self, **options):
        environment = dict(os.environ, TODO_TEST_ROOT=self.root.as_posix(), **options)
        return subprocess.run([str(BASH), str(HARNESS), str(self.script)],
                              env=environment, capture_output=True, text=True, timeout=10)

    def assert_no_changes(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('accion:', result.stdout)
        self.assertEqual(self.target.read_bytes(), ORIGINAL)

    def test_sin_validacion(self):
        (self.base / 'validado').unlink()
        self.assert_no_changes(self.run_activation())

    def test_desactivado(self):
        (self.base / 'desactivado').touch()
        self.assert_no_changes(self.run_activation())

    def test_firmware_diferente(self):
        self.target.write_bytes(b'otro firmware')
        result = self.run_activation()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('accion:', result.stdout)
        self.assertEqual(self.target.read_bytes(), b'otro firmware')

    def test_copia_corrupta(self):
        self.image.write_bytes(b'copia incompleta')
        result = self.run_activation()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('accion:', result.stdout)
        self.assertEqual(self.target.read_bytes(), ORIGINAL)

    def test_activacion_y_reintento(self):
        result = self.run_activation()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count('accion:montar'), 1)
        self.assertEqual(result.stdout.count('accion:recargar'), 1)
        self.assertEqual(self.target.read_bytes(), PATCHED)
        result = self.run_activation()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('accion:', result.stdout)

    def test_servicio_detenido(self):
        result = self.run_activation(TODO_TEST_RUNNING='0')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('accion:recargar', result.stdout)
        self.assertEqual(self.target.read_bytes(), PATCHED)

    def test_desactivar_restaura_el_original_y_no_reaplica(self):
        self.assertEqual(self.run_activation().returncode,0)
        result=subprocess.run([str(BASH),str(HARNESS),str(self.deactivation)],
            env=dict(os.environ,TODO_TEST_ROOT=self.root.as_posix()),
            capture_output=True,text=True,timeout=10)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(self.target.read_bytes(),ORIGINAL)
        self.assertTrue((self.base/'desactivado').exists())
        self.assert_no_changes(self.run_activation())

    def test_recarga_fallida_recupera_original(self):
        result = self.run_activation(TODO_TEST_FAIL_RESTART='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('accion:desmontar', result.stdout)
        self.assertEqual(self.target.read_bytes(), ORIGINAL)
        self.assertTrue((self.base / 'desactivado').exists())
        self.assertFalse((self.root / 'bloqueo').exists())

    def test_montaje_fallido_conserva_original(self):
        result = self.run_activation(TODO_TEST_FAIL_MOUNT='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('accion:recargar', result.stdout)
        self.assertEqual(self.target.read_bytes(), ORIGINAL)
        self.assertFalse((self.root / 'bloqueo').exists())


class ActivacionInicioKT6Test(ActivacionInicioTest):
    original_sha='50280b9576e000f483f029991acb5f08620dccb3f3b14615a3a28b80c7807e86'
    patched_sha='db7ceae850d1159c0ffdac4cc8c7e8113daa71c151acb3888dd676da9b7cf23f'


if __name__ == '__main__':
    unittest.main()
