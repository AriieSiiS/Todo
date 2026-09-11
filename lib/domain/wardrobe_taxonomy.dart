class WardrobeTaxonomy {
  const WardrobeTaxonomy._();

  static const List<String> categories = <String>[
    'Camisetas',
    'Camisas',
    'Pantalones',
    'Vaqueros',
    'Pantalones cortos',
    'Calzado',
    'Sudaderas',
    'Jerséis y cárdigans',
    'Chaquetas',
    'Abrigos',
    'Polos',
    'Vestidos',
    'Faldas',
    'Ropa interior',
    'Pijamas',
    'Bañadores',
    'Trajes y americanas',
    'Chalecos',
    'Monos',
    'Accesorios',
    'Otros',
  ];

  static const List<String> colors = <String>[
    'negro',
    'blanco',
    'gris',
    'azul',
    'azul marino',
    'celeste',
    'verde',
    'verde oliva',
    'rojo',
    'granate',
    'rosa',
    'morado',
    'lila',
    'amarillo',
    'naranja',
    'beige',
    'crema',
    'marrón',
    'dorado',
    'plateado',
    'multicolor',
  ];

  static const List<String> seasons = <String>[
    'todo el año',
    'primavera',
    'verano',
    'otoño',
    'invierno',
  ];

  static const List<String> occasions = <String>[
    'diario',
    'informal',
    'trabajo',
    'formal',
    'fiesta',
    'deporte',
    'casa',
    'viaje',
    'playa',
  ];

  static const List<String> materialSuggestions = <String>[
    'algodón',
    'poliéster',
    'lana',
    'lino',
    'denim',
    'cuero',
    'sintético',
    'viscosa',
    'seda',
    'nylon',
    'elastano',
    'ante',
    'punto',
  ];

  static const Map<String, String> _categoryAliases = <String, String>{
    'camiseta': 'Camisetas',
    'camisetas': 'Camisetas',
    't-shirt': 'Camisetas',
    't-shirts': 'Camisetas',
    'tee': 'Camisetas',
    'camisa': 'Camisas',
    'camisas': 'Camisas',
    'pantalón': 'Pantalones',
    'pantalones': 'Pantalones',
    'jean': 'Vaqueros',
    'jeans': 'Vaqueros',
    'vaquero': 'Vaqueros',
    'vaqueros': 'Vaqueros',
    'bermuda': 'Pantalones cortos',
    'bermudas': 'Pantalones cortos',
    'short': 'Pantalones cortos',
    'shorts': 'Pantalones cortos',
    'zapatilla': 'Calzado',
    'zapatillas': 'Calzado',
    'zapato': 'Calzado',
    'zapatos': 'Calzado',
    'bota': 'Calzado',
    'botas': 'Calzado',
    'sudadera': 'Sudaderas',
    'sudaderas': 'Sudaderas',
    'hoodie': 'Sudaderas',
    'jersey': 'Jerséis y cárdigans',
    'jerseys': 'Jerséis y cárdigans',
    'suéter': 'Jerséis y cárdigans',
    'cárdigan': 'Jerséis y cárdigans',
    'chaqueta': 'Chaquetas',
    'chaquetas': 'Chaquetas',
    'jacket': 'Chaquetas',
    'jackets': 'Chaquetas',
    'cazadora': 'Chaquetas',
    'bomber': 'Chaquetas',
    'abrigo': 'Abrigos',
    'abrigos': 'Abrigos',
    'parka': 'Abrigos',
    'polo': 'Polos',
    'polos': 'Polos',
    'vestido': 'Vestidos',
    'vestidos': 'Vestidos',
    'falda': 'Faldas',
    'faldas': 'Faldas',
    'pijama': 'Pijamas',
    'pijamas': 'Pijamas',
    'bañador': 'Bañadores',
    'bañadores': 'Bañadores',
    'traje': 'Trajes y americanas',
    'americana': 'Trajes y americanas',
    'chaleco': 'Chalecos',
    'chalecos': 'Chalecos',
    'mono': 'Monos',
    'monos': 'Monos',
    'accesorio': 'Accesorios',
    'accesorios': 'Accesorios',
    'otro': 'Otros',
    'otros': 'Otros',
  };

  static const Map<String, String> _colorAliases = <String, String>{
    'burdeos': 'granate',
    'borgoña': 'granate',
    'lavanda': 'lila',
    'oliva': 'verde oliva',
    'gris carbón': 'gris',
    'gris carbon': 'gris',
    'caramelo': 'marrón',
    'taupe': 'marrón',
  };

  static String normalizeCategory(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Otros';
    for (final category in categories) {
      if (_key(category) == _key(trimmed)) return category;
    }
    return _categoryAliases[_key(trimmed)] ?? trimmed;
  }

  static String normalizeColor(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) return '';
    final alias = _colorAliases[_key(trimmed)];
    if (alias != null) return alias;
    for (final color in colors) {
      if (_key(color) == _key(trimmed)) return color;
    }
    return trimmed;
  }

  static List<String> normalizeColors(Iterable<String> values) =>
      _unique(values.map(normalizeColor));

  static List<String> normalizeSeasons(Iterable<String> values) =>
      _normalizeControlled(values, seasons);

  static List<String> normalizeOccasions(Iterable<String> values) =>
      _normalizeControlled(values, occasions);

  static List<String> categoriesWithLegacy(String? current) {
    final value = current?.trim() ?? '';
    if (value.isEmpty || categories.contains(normalizeCategory(value))) {
      return categories;
    }
    return <String>[...categories.take(categories.length - 1), value, 'Otros'];
  }

  static int categoryIndex(String value) {
    final index = categories.indexOf(normalizeCategory(value));
    return index == -1 ? categories.length - 1 : index;
  }

  static int compareCategories(String left, String right) {
    final order = categoryIndex(left).compareTo(categoryIndex(right));
    return order != 0
        ? order
        : left.toLowerCase().compareTo(right.toLowerCase());
  }

  static List<String> _normalizeControlled(
    Iterable<String> values,
    List<String> allowed,
  ) {
    return _unique(values.map((value) {
      final trimmed = value.trim().toLowerCase();
      for (final option in allowed) {
        if (_key(option) == _key(trimmed)) return option;
      }
      return trimmed;
    }));
  }

  static List<String> _unique(Iterable<String> values) {
    final result = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || !seen.add(_key(trimmed))) continue;
      result.add(trimmed);
    }
    return result;
  }

  static String _key(String value) => value.trim().toLowerCase();
}
