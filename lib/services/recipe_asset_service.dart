import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class RecipeImportedImage {
  const RecipeImportedImage({
    required this.imagePath,
    required this.thumbnailPath,
    required this.sha256,
  });

  final String imagePath;
  final String thumbnailPath;
  final String sha256;
}

class RecipeAssetService {
  RecipeAssetService({Directory? rootOverride}) : _rootOverride = rootOverride;

  final Directory? _rootOverride;

  Future<Directory> recipeDirectory() async {
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
      '${base.path}${Platform.pathSeparator}Todo${Platform.pathSeparator}recipes',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<String> absolutePath(String relativePath) async {
    if (relativePath.trim().isEmpty) return '';
    final normalized = relativePath.replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.contains('../')) return '';
    final base = await recipeDirectory();
    return '${base.path}${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}';
  }

  Future<RecipeImportedImage> importImage(
    String recipeId,
    String sourcePath,
  ) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('No se encuentra la imagen.');
    }
    return _storeImage(recipeId, await source.readAsBytes());
  }

  Future<RecipeImportedImage> importImageBytes(
    String recipeId,
    Uint8List bytes,
  ) =>
      _storeImage(recipeId, bytes);

  Future<RecipeImportedImage> importImageFromUrl(
    String recipeId,
    String sourceUrl,
  ) async {
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || !<String>{'http', 'https'}.contains(uri.scheme)) {
      throw const FormatException('La dirección de la imagen no es válida.');
    }
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'No se pudo descargar la imagen (${response.statusCode}).',
        uri: uri,
      );
    }
    return _storeImage(recipeId, response.bodyBytes);
  }

  Future<RecipeImportedImage> _storeImage(
    String recipeId,
    Uint8List bytes,
  ) async {
    final preparada = await Isolate.run(() => _prepararImagenReceta(bytes));
    final imageBytes = preparada.imagen;
    final digest = sha256.convert(imageBytes).toString();
    final fileStem = '${_safeId(recipeId)}-${digest.substring(0, 12)}';
    final root = await recipeDirectory();
    final images = Directory('${root.path}${Platform.pathSeparator}images');
    final thumbnails =
        Directory('${root.path}${Platform.pathSeparator}thumbnails');
    await images.create(recursive: true);
    await thumbnails.create(recursive: true);
    final image = File('${images.path}${Platform.pathSeparator}$fileStem.jpg');
    final thumbnail =
        File('${thumbnails.path}${Platform.pathSeparator}$fileStem.jpg');
    await _atomicWrite(image, imageBytes);
    try {
      await _atomicWrite(thumbnail, preparada.miniatura);
    } catch (_) {
      if (await image.exists()) await image.delete();
      rethrow;
    }
    return RecipeImportedImage(
      imagePath: 'images/$fileStem.jpg',
      thumbnailPath: 'thumbnails/$fileStem.jpg',
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
        ? 'receta-${DateTime.now().microsecondsSinceEpoch}'
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
_ImagenPreparada _prepararImagenReceta(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('El archivo seleccionado no es una imagen.');
  }
  if (decoded.width < 300 || decoded.height < 200) {
    throw const FormatException(
      'La imagen debe medir al menos 300 × 200 píxeles.',
    );
  }
  final longest = max(decoded.width, decoded.height);
  final scale = longest > 2200 ? 2200 / longest : 1.0;
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
    width: normalized.width >= normalized.height ? 720 : null,
    height: normalized.height > normalized.width ? 720 : null,
    interpolation: img.Interpolation.average,
  );
  return _ImagenPreparada(
    Uint8List.fromList(img.encodeJpg(normalized, quality: 92)),
    Uint8List.fromList(img.encodeJpg(thumb, quality: 86)),
  );
}
