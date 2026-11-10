import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/data/local_store_file_backed.dart';

void main() {
  test('un bloqueo pasajero del archivo se reintenta', () async {
    var llamadas = 0;
    final valor = await FileBackedLocalStore.conReintentos(() async {
      llamadas++;
      if (llamadas < 3) {
        throw const FileSystemException('El archivo está en uso');
      }
      return 'guardado';
    });
    expect(valor, 'guardado');
    expect(llamadas, 3);
  });

  test('si el bloqueo no se va, el error llega a quien guarda', () async {
    var llamadas = 0;
    await expectLater(
        FileBackedLocalStore.conReintentos(() async {
          llamadas++;
          throw const FileSystemException('El archivo está en uso');
        }, intentos: 3),
        throwsA(isA<FileSystemException>()));
    expect(llamadas, 3);
  });
}
