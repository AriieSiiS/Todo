"""Comprueba las parejas admitidas de firmware y hash nativo antes de instalar."""
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parent.parent
BASH = 'C:/Program Files/Git/bin/bash.exe'
SCRIPT = ROOT / 'kindle/boot/compatibilidad.sh'
KT5 = ('Kindle 5.19.2.0.1 (~~otaVersion~~)',
       '789c66aaeb37550042ca59e055a6d3ef2e849a49a31b017afcaaf9d93d8d8c48')
KT6 = ('Kindle 5.17.1.0.4 (~~otaVersion~~)',
       '50280b9576e000f483f029991acb5f08620dccb3f3b14615a3a28b80c7807e86')


class CompatibilidadTest(unittest.TestCase):
    def comprobar(self, version, huella):
        result = subprocess.run([BASH, str(SCRIPT), version, huella],
                                capture_output=True, text=True, encoding='utf-8', timeout=10)
        return result.returncode == 0

    def test_los_dos_destinos_conocidos_se_admiten(self):
        self.assertTrue(self.comprobar(*KT5))
        self.assertTrue(self.comprobar(*KT6))

    def test_no_se_mezclan_firmware_y_hash_de_distintos_destinos(self):
        self.assertFalse(self.comprobar(KT5[0], KT6[1]))
        self.assertFalse(self.comprobar(KT6[0], KT5[1]))

    def test_las_copias_limpias_verificadas_se_admiten(self):
        self.assertTrue(self.comprobar(KT5[0],'ece6c579fb0e75811f691ebbc21cba826898f207633e2bf6b6a3bdff864dbd99'))
        self.assertTrue(self.comprobar(KT6[0],'db7ceae850d1159c0ffdac4cc8c7e8113daa71c151acb3888dd676da9b7cf23f'))

    def test_una_copia_limpia_de_otro_firmware_se_rechaza(self):
        self.assertFalse(self.comprobar(KT5[0],'db7ceae850d1159c0ffdac4cc8c7e8113daa71c151acb3888dd676da9b7cf23f'))
        self.assertFalse(self.comprobar(KT6[0],'ece6c579fb0e75811f691ebbc21cba826898f207633e2bf6b6a3bdff864dbd99'))

    def test_otra_edicion_o_archivo_modificado_se_rechazan(self):
        self.assertFalse(self.comprobar('Kindle 5.17.1.0.5 (~~otaVersion~~)', KT6[1]))
        self.assertFalse(self.comprobar(KT6[0], '0' * 64))

    def test_datos_vacios_y_texto_como_argumentos_se_rechazan(self):
        self.assertFalse(self.comprobar('', ''))
        self.assertFalse(self.comprobar(KT6[0] + '; true', KT6[1]))


if __name__ == '__main__':
    unittest.main()
