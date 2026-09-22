import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

class PlantImportedImage {
  const PlantImportedImage({
    required this.imagePath,
    required this.thumbnailPath,
    required this.sha256,
  });

  final String imagePath;
  final String thumbnailPath;
  final String sha256;
}

class PlantAssetService {
  PlantAssetService({Directory? rootOverride}) : _rootOverride = rootOverride;

  final Directory? _rootOverride;

  Future<Directory> plantsDirectory() async {
    if (_rootOverride != null) {
      await _rootOverride.create(recursive: true);
      return _rootOverride;
    }
    final profile = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final documents = Directory('$profile${Platform.pathSeparator}Documents');
    final base = documents.existsSync() ? documents : Directory(profile);
    final directory = Directory(
      '${base.path}${Platform.pathSeparator}Todo${Platform.pathSeparator}plants',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<String> absolutePath(String relativePath) async {
    if (relativePath.trim().isEmpty) return '';
    final normalized = relativePath.replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.contains('../')) return '';
    final base = await plantsDirectory();
    return '${base.path}${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}';
  }

  Future<PlantImportedImage> importImage(
    String plantId,
    String sourcePath,
  ) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('No se encuentra la imagen.');
    }
    return importImageBytes(plantId, await source.readAsBytes());
  }

  Future<PlantImportedImage> importImageBytes(
    String plantId,
    Uint8List bytes,
  ) async {
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
    final imageBytes = img.encodePng(normalized);
    final digest = sha256.convert(imageBytes).toString();
    final stem = '${_safeId(plantId)}-${digest.substring(0, 12)}';
    final root = await plantsDirectory();
    final images = Directory('${root.path}${Platform.pathSeparator}images');
    final thumbnails =
        Directory('${root.path}${Platform.pathSeparator}thumbnails');
    await images.create(recursive: true);
    await thumbnails.create(recursive: true);
    final image = File('${images.path}${Platform.pathSeparator}$stem.png');
    final thumbnail =
        File('${thumbnails.path}${Platform.pathSeparator}$stem.png');
    final thumb = img.copyResize(
      normalized,
      width: normalized.width >= normalized.height ? 640 : null,
      height: normalized.height > normalized.width ? 640 : null,
      interpolation: img.Interpolation.average,
    );
    await _atomicWrite(image, imageBytes);
    try {
      await _atomicWrite(thumbnail, img.encodePng(thumb));
    } catch (_) {
      if (await image.exists()) await image.delete();
      rethrow;
    }
    return PlantImportedImage(
      imagePath: 'images/$stem.png',
      thumbnailPath: 'thumbnails/$stem.png',
      sha256: digest,
    );
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
        ? 'planta-${DateTime.now().microsecondsSinceEpoch}'
        : safe;
  }
}
