import 'dart:convert';
import 'dart:io';

/// Carpeta de Platino, la web local de guías de logros que no forma parte de
/// Todo. Es el único sitio donde se indica su ruta.
const String rutaPlatino =
    r'C:\Users\aries\Documents\Ale\Programacion\Proyectos\Platino';

/// Appid de Steam a partir del enlace de la tienda de un elemento.
int? appIdDeEnlaceSteam(String? enlace) {
  final coincidencia =
      RegExp(r'store\.steampowered\.com/app/(\d+)').firstMatch(enlace ?? '');
  return coincidencia == null ? null : int.tryParse(coincidencia.group(1)!);
}

/// Dirección `file://` de la guía de Platino del juego con ese appid, o `null`
/// si Platino no existe o el juego no tiene guía. Lee `juegos.js` en cada
/// llamada para que las guías nuevas aparezcan sin recompilar.
Future<Uri?> guiaPlatinoDe(int appId, {String carpeta = rutaPlatino}) async {
  try {
    final indice = File('$carpeta${Platform.pathSeparator}juegos.js');
    if (!await indice.exists()) return null;
    var texto = (await indice.readAsString()).trim();
    texto = texto.replaceFirst(RegExp(r'^window\.JUEGOS\s*='), '').trim();
    if (texto.endsWith(';')) texto = texto.substring(0, texto.length - 1);
    final juegos = jsonDecode(texto);
    if (juegos is! List) return null;
    for (final juego in juegos) {
      if (juego is! Map || juego['appid'].toString() != '$appId') continue;
      final id = juego['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final guia = File(
          '$carpeta${Platform.pathSeparator}$id${Platform.pathSeparator}index.html');
      if (await guia.exists()) return Uri.file(guia.path, windows: true);
    }
  } catch (_) {
    // Sin Platino o con un índice ilegible, simplemente no hay botón.
  }
  return null;
}
