import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

import 'cola_imagenes.dart';
import '../domain/models.dart';

class WardrobeApprovedAsset {
  const WardrobeApprovedAsset({
    required this.importItem,
    required this.imagePath,
    required this.thumbnailPath,
    required this.sha256,
  });

  final WardrobeImportItem importItem;
  final String imagePath;
  final String thumbnailPath;
  final String sha256;
}

class WardrobeStoredAsset {
  const WardrobeStoredAsset({
    required this.imagePath,
    required this.thumbnailPath,
    required this.sha256,
  });

  final String imagePath;
  final String thumbnailPath;
  final String sha256;
}

class WardrobeAssetService {
  WardrobeAssetService({Directory? rootOverride})
      : _rootOverride = rootOverride;

  final Directory? _rootOverride;

  Future<Directory> wardrobeDirectory() async {
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
      '${base.path}${Platform.pathSeparator}Todo${Platform.pathSeparator}wardrobe',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<String> absolutePath(String relativePath) async {
    if (relativePath.trim().isEmpty) return '';
    final base = await wardrobeDirectory();
    final normalized = relativePath.replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.contains('../')) return '';
    return '${base.path}${Platform.pathSeparator}${normalized.replaceAll('/', Platform.pathSeparator)}';
  }

  Future<String> importOutfitRender(String outfitId, String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException(
          'No se encuentra la imagen del conjunto.');
    }
    return importOutfitRenderBytes(outfitId, await source.readAsBytes());
  }

  Future<String> importOutfitRenderBytes(
    String outfitId,
    Uint8List bytes,
  ) async {
    final encoded = await procesarImagen(() => _prepararRenderConjunto(bytes));
    final wardrobe = await wardrobeDirectory();
    final directory = Directory(
      '${wardrobe.path}${Platform.pathSeparator}outfits',
    );
    await directory.create(recursive: true);
    final digest = sha256.convert(encoded).toString();
    final fileName = '${_safeId(outfitId)}-${digest.substring(0, 12)}.png';
    final destination = File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );
    if (!await destination.exists()) {
      final temporary = File('${destination.path}.tmp');
      try {
        await temporary.writeAsBytes(encoded, flush: true);
        await temporary.rename(destination.path);
      } catch (_) {
        if (await temporary.exists()) await temporary.delete();
        rethrow;
      }
    }
    return 'outfits/$fileName';
  }

  /// Recorta el espacio transparente y coloca la prenda en un lienzo de
  /// catálogo uniforme. Las reglas por categoría hacen comparables las
  /// prendas equivalentes aunque sus PNG de origen tengan márgenes distintos.
  Uint8List normalizeCatalogPng(Uint8List bytes, String category) {
    final decoded = img.decodePng(bytes);
    if (decoded == null || !_hasTransparency(decoded)) {
      throw const FormatException(
          'La prenda no es un PNG transparente válido.');
    }
    const canvasSize = 1200;
    final bounds = _visibleBounds(decoded);
    final cropped = img.copyCrop(
      decoded,
      x: bounds.$1,
      y: bounds.$2,
      width: bounds.$3,
      height: bounds.$4,
    );
    final targets = _catalogTargets(category);
    final scale = min(
      canvasSize * targets.$1 / cropped.width,
      canvasSize * targets.$2 / cropped.height,
    );
    final width = max(1, (cropped.width * scale).round());
    final height = max(1, (cropped.height * scale).round());
    final resized = img.copyResize(
      cropped,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );
    final canvas =
        img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
    img.compositeImage(
      canvas,
      resized,
      dstX: (canvasSize - width) ~/ 2,
      dstY: (canvasSize - height) ~/ 2,
      blend: img.BlendMode.direct,
    );
    return Uint8List.fromList(img.encodePng(canvas));
  }

  Future<WardrobeStoredAsset> importItemImage({
    required String itemId,
    required String sourcePath,
    required String category,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('No se encuentra la imagen.');
    }
    return importItemImageBytes(
      itemId: itemId,
      bytes: await source.readAsBytes(),
      category: category,
    );
  }

  Future<WardrobeStoredAsset> importItemImageBytes({
    required String itemId,
    required Uint8List bytes,
    required String category,
  }) async {
    final (imageBytes, thumbnailBytes) =
        await _prepararEnCola(bytes, category, lote: false);
    final digest = sha256.convert(imageBytes).toString();
    final fileStem = '${_safeId(itemId)}-${digest.substring(0, 12)}';
    final wardrobe = await wardrobeDirectory();
    final itemsDirectory = Directory(
      '${wardrobe.path}${Platform.pathSeparator}items',
    );
    final thumbnailsDirectory = Directory(
      '${wardrobe.path}${Platform.pathSeparator}thumbnails',
    );
    await itemsDirectory.create(recursive: true);
    await thumbnailsDirectory.create(recursive: true);
    final imageFile = File(
      '${itemsDirectory.path}${Platform.pathSeparator}$fileStem.png',
    );
    final thumbnailFile = File(
      '${thumbnailsDirectory.path}${Platform.pathSeparator}$fileStem.png',
    );
    await _atomicWrite(imageFile, imageBytes);
    try {
      await _atomicWrite(thumbnailFile, thumbnailBytes);
    } catch (_) {
      if (await imageFile.exists()) await imageFile.delete();
      rethrow;
    }
    return WardrobeStoredAsset(
      imagePath: 'items/$fileStem.png',
      thumbnailPath: 'thumbnails/$fileStem.png',
      sha256: digest,
    );
  }

  /// Prepara la imagen guardada y su miniatura; se ejecuta en
  /// `procesarImagen` porque decodificar y codificar PNG es costoso.
  (Uint8List, Uint8List) _prepararPrenda(Uint8List bytes, String category) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('El archivo seleccionado no es una imagen.');
    }

    late final Uint8List imageBytes;
    late final img.Image storedImage;
    if (_hasTransparency(decoded)) {
      imageBytes = normalizeCatalogPng(
        Uint8List.fromList(img.encodePng(decoded)),
        category,
      );
      storedImage = img.decodePng(imageBytes)!;
    } else {
      final longest = max(decoded.width, decoded.height);
      final scale = longest > 2000 ? 2000 / longest : 1.0;
      storedImage = scale < 1
          ? img.copyResize(
              decoded,
              width: max(1, (decoded.width * scale).round()),
              height: max(1, (decoded.height * scale).round()),
              interpolation: img.Interpolation.average,
            )
          : decoded;
      imageBytes = Uint8List.fromList(img.encodePng(storedImage));
    }

    final thumbnail = img.copyResize(
      storedImage,
      width: storedImage.width >= storedImage.height ? 420 : null,
      height: storedImage.height > storedImage.width ? 420 : null,
      interpolation: img.Interpolation.average,
    );
    return (imageBytes, Uint8List.fromList(img.encodePng(thumbnail)));
  }

  // Método síncrono aparte para que el cierre enviado al isolate solo
  // capture estos argumentos y no el estado del método asíncrono que lo llama.
  Future<(Uint8List, Uint8List)> _prepararEnCola(
    Uint8List bytes,
    String category, {
    required bool lote,
  }) =>
      procesarImagen(() => lote
          ? _prepararPrendaDeLote(bytes, category)
          : _prepararPrenda(bytes, category));

  /// Normaliza una prenda de un lote y crea su miniatura cuadrada.
  (Uint8List, Uint8List) _prepararPrendaDeLote(
      Uint8List bytes, String category) {
    final normalizedBytes = normalizeCatalogPng(bytes, category);
    final thumbnail = img.copyResize(
      img.decodePng(normalizedBytes)!,
      width: 420,
      height: 420,
      interpolation: img.Interpolation.average,
    );
    return (normalizedBytes, Uint8List.fromList(img.encodePng(thumbnail)));
  }

  Future<void> deleteAsset(String relativePath) async {
    final path = await absolutePath(relativePath);
    if (path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<WardrobeImportBatch> stageManifestDirectory(
    String sourcePath,
    List<WardrobeItem> existingItems,
  ) async {
    final source = Directory(sourcePath);
    final manifestFile = File(
      '${source.path}${Platform.pathSeparator}manifest.json',
    );
    if (!await manifestFile.exists()) {
      throw const FormatException('La carpeta no contiene manifest.json.');
    }
    final raw = (jsonDecode(await manifestFile.readAsString()) as Map)
        .cast<String, dynamic>();
    if ((raw['version'] as num?)?.toInt() != 1) {
      throw const FormatException(
          'La versión del manifiesto no es compatible.');
    }
    final batchId = _safeId(raw['batchId'] as String? ?? _timestampId());
    final batchName = raw['name'] as String? ?? 'Importación de ropa';
    final entries = raw['items'] as List<dynamic>? ?? const <dynamic>[];
    if (entries.isEmpty) {
      throw const FormatException('El manifiesto no contiene prendas.');
    }
    final wardrobe = await wardrobeDirectory();
    final destination = Directory(
      '${wardrobe.path}${Platform.pathSeparator}imports${Platform.pathSeparator}$batchId',
    );
    if (await destination.exists()) {
      throw const FileSystemException(
          'Ya existe un lote con ese identificador.');
    }
    await destination.create(recursive: true);
    final staged = <WardrobeImportItem>[];
    try {
      for (var index = 0; index < entries.length; index++) {
        final value = (entries[index] as Map).cast<String, dynamic>();
        final fileName = value['file'] as String? ?? '';
        final sourceFile = _safeChildFile(source, fileName);
        final errors = <String>[];
        if (!await sourceFile.exists()) {
          errors.add('No se encuentra el archivo PNG.');
        }
        var digest = '';
        if (errors.isEmpty) {
          final bytes = await sourceFile.readAsBytes();
          final decoded = img.decodePng(bytes);
          if (decoded == null || !fileName.toLowerCase().endsWith('.png')) {
            errors.add('El archivo no es un PNG válido.');
          } else if (!_hasTransparency(decoded)) {
            errors.add('El PNG no contiene transparencia.');
          } else {
            digest = sha256.convert(bytes).toString();
            await sourceFile.copy(
              '${destination.path}${Platform.pathSeparator}${_safeFileName(fileName)}',
            );
          }
        }
        final duplicate = existingItems
            .where((item) => digest.isNotEmpty && item.imageSha256 == digest)
            .map((item) => item.id)
            .cast<String?>()
            .firstOrNull;
        staged.add(WardrobeImportItem(
          id: value['id'] as String? ?? 'import-$index',
          fileName: _safeFileName(fileName),
          name: value['name'] as String? ?? 'Prenda ${index + 1}',
          category: value['category'] as String? ?? 'Sin categoría',
          imageSha256: digest,
          colors: _strings(value['colors']),
          material: value['material'] as String? ?? '',
          seasons: _strings(value['seasons']),
          occasions: _strings(value['occasions']),
          tags: _strings(value['tags']),
          confidence: value['confidence'] as String? ?? 'media',
          sourceReferences: _strings(value['sourceReferences']),
          errors: errors,
          duplicateItemId: duplicate,
        ));
      }
      await File('${destination.path}${Platform.pathSeparator}manifest.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(raw));
      return WardrobeImportBatch(
        id: batchId,
        name: batchName,
        createdAt: DateTime.now(),
        status: WardrobeImportStatus.pending,
        items: staged,
      );
    } catch (_) {
      if (await destination.exists()) await destination.delete(recursive: true);
      rethrow;
    }
  }

  Future<List<WardrobeApprovedAsset>> approveBatch(
    WardrobeImportBatch batch,
  ) async {
    final invalid = batch.items.where((item) => item.errors.isNotEmpty);
    if (invalid.isNotEmpty) {
      throw StateError('El lote contiene prendas con errores.');
    }
    final wardrobe = await wardrobeDirectory();
    final importDirectory = Directory(
      '${wardrobe.path}${Platform.pathSeparator}imports${Platform.pathSeparator}${_safeId(batch.id)}',
    );
    final itemsDirectory = Directory(
      '${wardrobe.path}${Platform.pathSeparator}items',
    );
    final thumbnailsDirectory = Directory(
      '${wardrobe.path}${Platform.pathSeparator}thumbnails',
    );
    await itemsDirectory.create(recursive: true);
    await thumbnailsDirectory.create(recursive: true);
    final temporaryFiles = <File>[];
    final finalFiles = <File>[];
    final results = <WardrobeApprovedAsset>[];
    try {
      for (final item in batch.items) {
        if (item.duplicateItemId != null) continue;
        final source = _safeChildFile(importDirectory, item.fileName);
        final bytes = await source.readAsBytes();
        final category = item.category;
        final (normalizedBytes, thumbnailBytes) =
            await _prepararEnCola(bytes, category, lote: true);
        final digest = sha256.convert(normalizedBytes).toString();
        final fileStem = '${_safeId(item.id)}-${digest.substring(0, 12)}';
        final relativeImage = 'items/$fileStem.png';
        final relativeThumbnail = 'thumbnails/$fileStem.png';
        final imageFile = File(
            '${itemsDirectory.path}${Platform.pathSeparator}$fileStem.png');
        final thumbFile = File(
            '${thumbnailsDirectory.path}${Platform.pathSeparator}$fileStem.png');
        if (await imageFile.exists() || await thumbFile.exists()) {
          throw FileSystemException('Ya existe un recurso para ${item.name}.');
        }
        final tempImage = File('${imageFile.path}.tmp');
        final tempThumb = File('${thumbFile.path}.tmp');
        await tempImage.writeAsBytes(normalizedBytes, flush: true);
        await tempThumb.writeAsBytes(thumbnailBytes, flush: true);
        temporaryFiles.addAll(<File>[tempImage, tempThumb]);
        finalFiles.addAll(<File>[imageFile, thumbFile]);
        results.add(WardrobeApprovedAsset(
          importItem: item,
          imagePath: relativeImage,
          thumbnailPath: relativeThumbnail,
          sha256: digest,
        ));
      }
      for (var index = 0; index < temporaryFiles.length; index++) {
        await temporaryFiles[index].rename(finalFiles[index].path);
      }
      return results;
    } catch (_) {
      for (final file in <File>[...temporaryFiles, ...finalFiles]) {
        if (await file.exists()) await file.delete();
      }
      rethrow;
    }
  }

  Future<void> deleteImportBatch(String batchId) async {
    final wardrobe = await wardrobeDirectory();
    final directory = Directory(
      '${wardrobe.path}${Platform.pathSeparator}imports${Platform.pathSeparator}${_safeId(batchId)}',
    );
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> rollbackApprovedAssets(
    Iterable<WardrobeApprovedAsset> assets,
  ) async {
    for (final asset in assets) {
      for (final relativePath in <String>[
        asset.imagePath,
        asset.thumbnailPath,
      ]) {
        final path = await absolutePath(relativePath);
        if (path.isEmpty) continue;
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
  }

  Future<void> _atomicWrite(File destination, List<int> bytes) async {
    final temporary = File('${destination.path}.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      if (await destination.exists()) await destination.delete();
      await temporary.rename(destination.path);
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  File _safeChildFile(Directory directory, String name) {
    final safe = _safeFileName(name);
    if (safe != name.replaceAll('\\', '/').split('/').last) {
      throw const FormatException('El manifiesto contiene una ruta insegura.');
    }
    return File('${directory.path}${Platform.pathSeparator}$safe');
  }

  String _safeFileName(String value) => value
      .replaceAll('\\', '/')
      .split('/')
      .last
      .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '-');

  String _safeId(String value) {
    final safe = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
    return safe.isEmpty ? _timestampId() : safe;
  }

  String _timestampId() => 'ropa-${DateTime.now().microsecondsSinceEpoch}';
  List<String> _strings(Object? value) =>
      (value as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

  bool _hasTransparency(img.Image image) {
    for (final pixel in image) {
      if (pixel.a < 255) return true;
    }
    return false;
  }

  (int, int, int, int) _visibleBounds(img.Image image) {
    var left = image.width;
    var top = image.height;
    var right = -1;
    var bottom = -1;
    for (final pixel in image) {
      if (pixel.a <= 8) continue;
      left = min(left, pixel.x);
      top = min(top, pixel.y);
      right = max(right, pixel.x);
      bottom = max(bottom, pixel.y);
    }
    if (right < left || bottom < top) {
      throw const FormatException('La prenda no contiene píxeles visibles.');
    }
    return (left, top, right - left + 1, bottom - top + 1);
  }

  (double, double) _catalogTargets(String category) {
    final value = category.toLowerCase();
    if (<String>['calzado', 'zapat', 'zapato', 'bota', 'sandalia', 'tenis']
        .any(value.contains)) {
      return (.86, .52);
    }
    if (<String>['pantalones cortos', 'short', 'bermuda'].any(value.contains)) {
      return (.92, .72);
    }
    if (<String>['pantal', 'vaquero', 'falda'].any(value.contains)) {
      return (.76, .86);
    }
    if (<String>['accesorio', 'gorra', 'gorro', 'sombrero', 'reloj', 'bolso']
        .any(value.contains)) {
      return (.68, .62);
    }
    return (.90, .80);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Valida y vuelve a codificar el render de un conjunto fuera del hilo de la
/// interfaz, porque decodificar y codificar un PNG grande es costoso.
Uint8List _prepararRenderConjunto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('La imagen del conjunto no es válida.');
  }
  if (decoded.width < 600 || decoded.height < 600) {
    throw const FormatException(
        'La imagen del conjunto debe medir al menos 600 × 600 píxeles.');
  }
  return Uint8List.fromList(img.encodePng(decoded));
}
