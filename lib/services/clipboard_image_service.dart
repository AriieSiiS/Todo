import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:super_clipboard/super_clipboard.dart';

class ClipboardImageResult {
  const ClipboardImageResult._({this.bytes, this.errorMessage});

  const ClipboardImageResult.success(Uint8List bytes) : this._(bytes: bytes);

  const ClipboardImageResult.failure(String message)
      : this._(errorMessage: message);

  final Uint8List? bytes;
  final String? errorMessage;

  bool get hasImage => bytes?.isNotEmpty == true;
}

Future<ClipboardImageResult> readClipboardImage() async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) {
    return const ClipboardImageResult.failure(
      'No se puede acceder al portapapeles en este equipo.',
    );
  }
  try {
    final reader = await clipboard.read();
    final bytes = await _readImageBytes(reader);
    if (bytes == null || bytes.isEmpty) {
      return const ClipboardImageResult.failure(
        'El portapapeles no contiene una imagen.',
      );
    }
    return ClipboardImageResult.success(bytes);
  } catch (_) {
    return const ClipboardImageResult.failure(
      'No se pudo pegar la imagen del portapapeles.',
    );
  }
}

Future<Uint8List?> _readImageBytes(ClipboardDataReader reader) async {
  for (final format in [Formats.png, Formats.jpeg, Formats.webp, Formats.gif]) {
    if (!reader.canProvide(format)) continue;
    final completer = Completer<Uint8List>();
    final progress = reader.getFile(
      format,
      (file) async {
        try {
          final bytes = await file.readAll();
          if (!completer.isCompleted) completer.complete(bytes);
        } catch (error, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        }
      },
      onError: (error) {
        if (!completer.isCompleted) completer.completeError(error);
      },
    );
    if (progress != null) return completer.future;
  }

  final uri = await reader.readValue(Formats.fileUri);
  if (uri == null || uri.scheme != 'file') return null;
  final extension = uri.path.split('.').last.toLowerCase();
  if (!const {'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(extension)) {
    return null;
  }
  return File.fromUri(uri).readAsBytes();
}
