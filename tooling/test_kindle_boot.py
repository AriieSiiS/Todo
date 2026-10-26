"""Prueba el arranque y la recuperación con servicios simulados, sin usar el Kindle."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
BASH = 'C:/Program Files/Git/bin/bash.exe'


class ArranqueKindleTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.base = self.root / 'system/todo-koreader'
        self.base.mkdir(parents=True)
        (self.base / 'activado').touch()
        self.environment = dict(os.environ, TODO_TEST_ROOT=self.root.as_posix())
        self.harness = ROOT / 'kindle/tests/boot_commands.sh'

    def execute(self, name, *arguments, **environment):
        path = ROOT / 'kindle/boot' / name
        source = path.read_text(encoding='utf-8')
        source = source.replace('/mnt/us', self.root.as_posix())
        source = source.replace('/tmp/todo-koreader-iniciado', (self.root / 'iniciado').as_posix())
        script = self.root / name
        script.write_text(source, encoding='utf-8', newline='\n')
        return subprocess.run([BASH, str(self.harness), str(script), *arguments],
                              env=dict(self.environment, **environment), capture_output=True,
                              text=True, encoding='utf-8', timeout=30)

    def prepare_reader(self):
        (self.root / 'koreader').mkdir()
        (self.root / 'koreader/koreader.sh').write_bytes(
            (ROOT / 'kindle/tests/boot_reader_target.sh').read_bytes())

    def prepare_boot_target(self):
        self.prepare_reader()
        (self.base / 'launch.sh').write_bytes(
            (ROOT / 'kindle/tests/boot_reader_target.sh').read_bytes())

    def test_sin_activar_no_abre_lector(self):
        (self.base / 'activado').unlink()
        self.prepare_boot_target()
        result = self.execute('boot.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('hijo:', result.stdout)

    def test_marca_de_recuperacion_archivo_o_carpeta(self):
        self.prepare_boot_target()
        for directory in [False, True]:
            marker = self.root / 'DESACTIVAR_INICIO_TODO'
            marker.mkdir() if directory else marker.touch()
            result = self.execute('boot.sh')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn('hijo:', result.stdout)
            marker.rmdir() if directory else marker.unlink()

    def test_usb_evade_arranque(self):
        self.prepare_boot_target()
        result = self.execute('boot.sh', TODO_TEST_USB='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('hijo:', result.stdout)

    def test_usb_durante_la_espera_evade_arranque(self):
        self.prepare_boot_target()
        result = self.execute('boot.sh', TODO_TEST_USB_LATER='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('hijo:', result.stdout)

    def test_solo_una_apertura_por_arranque(self):
        self.prepare_boot_target()
        result = self.execute('boot.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('hijo:', result.stdout)
        result = self.execute('boot.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('hijo:', result.stdout)

    def test_no_duplica_un_lector_abierto(self):
        self.prepare_boot_target()
        result = self.execute('boot.sh', TODO_TEST_READER_ACTIVE='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('hijo:', result.stdout)

    def test_servicio_usb_no_disponible_conserva_sistema_original(self):
        self.prepare_boot_target()
        result = self.execute('boot.sh', TODO_TEST_SERVICE_ERROR='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('hijo:', result.stdout)

    def test_recuperacion_desde_menu_impide_arranque(self):
        self.prepare_boot_target()
        (self.base / 'desactivado').touch()
        result = self.execute('boot.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('hijo:', result.stdout)

    def test_fallo_de_arranque_no_provoca_reintentos(self):
        self.prepare_boot_target()
        result = self.execute('boot.sh', TODO_TEST_CHILD_EXIT='3')
        self.assertEqual(result.returncode, 3, result.stderr)
        result = self.execute('boot.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('hijo:', result.stdout)

    def test_lanzamiento_sin_interfaz_y_argumentos_conservados(self):
        self.prepare_reader()
        result = self.execute('launch.sh', '--asap', 'libro con espacios.mobi', TODO_TEST_CHILD_EXIT='17')
        self.assertEqual(result.returncode, 17, result.stderr)
        self.assertIn('<--framework_stop>\n<libro con espacios.mobi>', result.stdout)
        self.assertNotIn('<--asap>', result.stdout)
        self.assertIn('recuperar-interfaz', result.stdout)

    def test_fallo_del_lector_recupera_interfaz(self):
        self.prepare_reader()
        result = self.execute('launch.sh', TODO_TEST_CHILD_EXIT='1')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('recuperar-interfaz', result.stdout)
        self.assertIn('abrir-inicio-original', result.stdout)

    def test_limpieza_del_inicio_antes_de_recuperar_la_interfaz(self):
        self.prepare_reader()
        native=self.root/'system/todo-native-home'
        native.mkdir()
        (native/'activar.sh').write_text("#!/bin/sh\nprintf 'limpiar-inicio\\n'\n",encoding='utf-8')
        result=self.execute('launch.sh')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('limpiar-inicio',result.stdout)
        self.assertLess(result.stdout.index('limpiar-inicio'),result.stdout.index('recuperar-interfaz'))

    def test_fallo_de_limpieza_conserva_la_recuperacion(self):
        self.prepare_reader()
        native=self.root/'system/todo-native-home'
        native.mkdir()
        (native/'activar.sh').write_text('#!/bin/sh\nexit 7\n',encoding='utf-8')
        result=self.execute('launch.sh')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('abrir-inicio-original',result.stdout)

    def test_interfaz_restaurada_abre_inicio_sin_duplicar_servicios(self):
        self.prepare_reader()
        result = self.execute('launch.sh', TODO_TEST_GUI_ACTIVE='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('recuperar-interfaz', result.stdout)
        self.assertIn('abrir-inicio-original', result.stdout)

    def test_cierra_la_aplicacion_nativa_antes_de_detener_la_interfaz(self):
        self.prepare_reader()
        result = self.execute('launch.sh', TODO_TEST_GUI_ACTIVE='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('cerrar-inicio-original', result.stdout)
        self.assertLess(result.stdout.index('cerrar-inicio-original'), result.stdout.index('hijo:'))

    def test_fallo_del_inicio_no_bloquea_la_salida(self):
        self.prepare_reader()
        result = self.execute('launch.sh', TODO_TEST_HOME_ERROR='1', TODO_TEST_CHILD_EXIT='17')
        self.assertEqual(result.returncode, 17, result.stderr)
        self.assertIn('abrir-inicio-original', result.stdout)
        self.assertIn('No se pudo abrir el inicio original', result.stderr)

    def test_recuperacion_espera_la_inicializacion_lenta_del_firmware(self):
        self.prepare_reader()
        result = self.execute('launch.sh', TODO_TEST_GUI_DELAY='40')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('abrir-inicio-original', result.stdout)
        self.assertNotIn('No se pudo abrir el inicio original', result.stderr)


if __name__ == '__main__':
    unittest.main()
