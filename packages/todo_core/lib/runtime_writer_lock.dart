import 'dart:async';
import 'dart:io';

/// Propiedad exclusiva del snapshot durante una sesión gráfica o una transacción.
class RuntimeWriterLock {
  RuntimeWriterLock._(this._handle);
  RandomAccessFile? _handle;

  static Directory defaultDirectory() {
    final profile =
        Platform.environment['USERPROFILE'] ?? Directory.current.path;
    return Directory(Directory('$profile/Documents').existsSync()
        ? '$profile/Documents/Todo/runtime'
        : '$profile/runtime');
  }

  static Future<RuntimeWriterLock> acquire(Directory directory,
      {Duration timeout = const Duration(seconds: 5)}) async {
    await directory.create(recursive: true);
    final until = DateTime.now().add(timeout);
    while (true) {
      final handle = await File('${directory.path}/todo_state.json.lock')
          .open(mode: FileMode.append);
      try {
        await handle.lock(FileLock.exclusive, 0, 1);
        return RuntimeWriterLock._(handle);
      } on FileSystemException {
        await handle.close();
        if (!DateTime.now().isBefore(until)) {
          throw const FileSystemException(
              'Otro escritor de Todo está activo. Reintenta la operación.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  Future<void> release() async {
    final handle = _handle;
    _handle = null;
    await handle?.close();
  }
}
