import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

class HouseholdImportedImage {
  const HouseholdImportedImage({
    required this.imagePath,
    required this.thumbnailPath,
    required this.sha256,
  });

  final String imagePath;
  final String thumbnailPath;
  final String sha256;
}

class HouseholdAssetService {
  HouseholdAssetService(
      {Directory? rootOverride, this.directoryName = 'household'})
      : _rootOverride = rootOverride;

  final Directory? _rootOverride;
  final String directoryName;

  Future<Directory> householdDirectory() async {
    if (_rootOverride != null) {
      await _rootOverride.create(recursive: true);
      return _rootOverride;
    }
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final documents = Directory('$home${Platform.pathSeparator}Documents');
    final base = documents.existsSync() ? documents : Directory(home);
    final directory = Directory(
      '${base.path}${Platform.pathSeparator}Todo${Platform.pathSeparator}$directoryName',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<String> absolutePath(String relativePath) async {
    if (relativePath.trim().isEmpty) return '';
    final normalized = relativePath.replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.contains('../')) return '';
    final base = await householdDirectory();
    return '${base.path}${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}';
  }

  Future<HouseholdImportedImage> importImage(
    String itemId,
    String sourcePath,
  ) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('No se encuentra la imagen.');
    }
    return importImageBytes(itemId, await source.readAsBytes());
  }

  Future<HouseholdImportedImage> importImageBytes(
    String itemId,
    Uint8List bytes,
  ) async {
    final preparada = await Isolate.run(() => _prepararImagenHogar(bytes));
    final imageBytes = preparada.imagen;
    final digest = sha256.convert(imageBytes).toString();
    final fileStem = '${_safeId(itemId)}-${digest.substring(0, 12)}';
    final root = await householdDirectory();
    final images = Directory(
      '${root.path}${Platform.pathSeparator}images',
    );
    final thumbnails = Directory(
      '${root.path}${Platform.pathSeparator}thumbnails',
    );
    await images.create(recursive: true);
    await thumbnails.create(recursive: true);
    final image = File('${images.path}${Platform.pathSeparator}$fileStem.png');
    final thumbnail =
        File('${thumbnails.path}${Platform.pathSeparator}$fileStem.png');
    await _atomicWrite(image, imageBytes);
    try {
      await _atomicWrite(thumbnail, preparada.miniatura);
    } catch (_) {
      if (await image.exists()) await image.delete();
      rethrow;
    }
    return HouseholdImportedImage(
      imagePath: 'images/$fileStem.png',
      thumbnailPath: 'thumbnails/$fileStem.png',
      sha256: digest,
    );
  }

  Future<String> importPdf(
    String itemId,
    String sourcePath, {
    required String kind,
  }) async {
    if (!const <String>{'manuals', 'invoices', 'documents'}.contains(kind)) {
      throw ArgumentError('Tipo de documento no compatible.');
    }
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('No se encuentra el documento.');
    }
    final bytes = await source.readAsBytes();
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw const FormatException('El documento debe ser un PDF válido.');
    }
    final digest = sha256.convert(bytes).toString();
    final root = await householdDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}$kind',
    );
    await directory.create(recursive: true);
    final fileName = '${_safeId(itemId)}-${digest.substring(0, 12)}.pdf';
    await _atomicWrite(
      File('${directory.path}${Platform.pathSeparator}$fileName'),
      bytes,
    );
    return '$kind/$fileName';
  }

  Future<void> deleteAsset(String relativePath) async {
    final path = await absolutePath(relativePath);
    if (path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> _atomicWrite(File destination, List<int> bytes) async {
    if (await destination.exists()) return;
    final temporary = File('${destination.path}.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(destination.path);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  String _safeId(String value) {
    final safe = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
    return safe.isEmpty
        ? 'hogar-${DateTime.now().microsecondsSinceEpoch}'
        : safe;
  }
}

/// Imagen ya normalizada y su miniatura, calculadas fuera del hilo de la interfaz.
class _ImagenPreparada {
  const _ImagenPreparada(this.imagen, this.miniatura);

  final Uint8List imagen;
  final Uint8List miniatura;
}

/// Decodifica, valida, reduce y codifica la imagen. Es costosa, por eso se
/// ejecuta con `Isolate.run`.
_ImagenPreparada _prepararImagenHogar(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('El archivo seleccionado no es una imagen.');
  }
  if (decoded.width < 400 || decoded.height < 400) {
    throw const FormatException(
      'La imagen debe medir al menos 400 × 400 píxeles.',
    );
  }
  final longest = max(decoded.width, decoded.height);
  final scale = longest > 2000 ? 2000 / longest : 1.0;
  final normalized = scale < 1
      ? img.copyResize(
          decoded,
          width: max(1, (decoded.width * scale).round()),
          height: max(1, (decoded.height * scale).round()),
          interpolation: img.Interpolation.average,
        )
      : decoded;
  final thumb = img.copyResize(
    normalized,
    width: normalized.width >= normalized.height ? 640 : null,
    height: normalized.height > normalized.width ? 640 : null,
    interpolation: img.Interpolation.average,
  );
  return _ImagenPreparada(
    Uint8List.fromList(img.encodePng(normalized)),
    Uint8List.fromList(img.encodePng(thumb)),
  );
}
