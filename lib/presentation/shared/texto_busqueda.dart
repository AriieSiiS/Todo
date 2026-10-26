/// Utilidades para que las búsquedas de la app ignoren mayúsculas y tildes.
library;

const Map<String, String> _equivalencias = <String, String>{
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ñ': 'n',
  'ç': 'c',
  'ý': 'y',
  'ÿ': 'y',
};

/// Devuelve el texto en minúsculas y sin tildes ni diéresis, de modo que
/// «Canción» y «cancion» se comparen igual.
String normalizarBusqueda(String texto) {
  final minusculas = texto.toLowerCase();
  final resultado = StringBuffer();
  for (final caracter in minusculas.split('')) {
    resultado.write(_equivalencias[caracter] ?? caracter);
  }
  return resultado.toString();
}

/// Indica si [texto] contiene [consulta] sin tener en cuenta mayúsculas ni
/// tildes. Una consulta vacía coincide siempre.
bool coincideBusqueda(String texto, String consulta) {
  final normalizada = normalizarBusqueda(consulta.trim());
  if (normalizada.isEmpty) return true;
  return normalizarBusqueda(texto).contains(normalizada);
}

extension TextoBusqueda on String {
  /// El texto preparado para buscar: en minúsculas y sin tildes.
  String get paraBuscar => normalizarBusqueda(this);
}
