import 'entities/recipe.dart';

class RecipeIngredientClassifier {
  const RecipeIngredientClassifier();

  RecipeIngredient classify(RecipeIngredient ingredient) {
    final matches = detectedCondiments(ingredient.text);
    return ingredient.copyWith(
      kind: matches.isNotEmpty && _containsOnlyCondiments(ingredient.text)
          ? RecipeIngredientKind.condiment
          : RecipeIngredientKind.ingredient,
    );
  }

  List<String> shoppingLabels(RecipeIngredient ingredient) {
    final classified = classify(ingredient);
    if (!classified.isCondiment) return <String>[ingredient.text.trim()];
    final detected = detectedCondiments(ingredient.text);
    return detected.isEmpty
        ? <String>[_stripMeasurement(ingredient.text)]
        : detected;
  }

  List<String> detectedCondiments(String value) {
    final normalized = _normalize(value);
    final result = <String>[];
    for (final definition in _definitions) {
      if (definition.aliases.any(
        (alias) => _aliasPattern(alias).hasMatch(normalized),
      )) {
        result.add(definition.name);
      }
    }
    if (result.contains('Pimienta negra') ||
        result.contains('Pimienta blanca') ||
        result.contains('Cayena')) {
      result.remove('Pimienta');
    }
    if (result.any((value) => value.startsWith('Vinagre de')) ||
        result.contains('Vinagre balsámico')) {
      result.remove('Vinagre');
    }
    return result;
  }

  bool _containsOnlyCondiments(String value) {
    var remainder = _normalize(value);
    for (final definition in _definitions) {
      final aliases = definition.aliases.toList()
        ..sort((left, right) => right.length.compareTo(left.length));
      for (final alias in aliases) {
        remainder = remainder.replaceAll(_aliasPattern(alias), ' ');
      }
    }
    remainder = remainder
        .replaceAll(RegExp(r'\d+(?:[\.,/]\d+)?'), ' ')
        .replaceAll(RegExp(r'[¼½¾⅓⅔⅛⅜⅝⅞]'), ' ')
        .replaceAll(RegExp(r'[^a-z]+'), ' ');
    final meaningful = remainder
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty && !_measurementNoise.contains(word));
    return meaningful.isEmpty;
  }

  String _stripMeasurement(String value) {
    var result = value.trim();
    result = result.replaceFirst(
      RegExp(
        r'^\s*(?:\d+(?:[\.,/]\d+)?|[¼½¾⅓⅔⅛⅜⅝⅞]|un(?:a|os|as)?|media?|medio|dos|tres|cuatro)\s*',
        caseSensitive: false,
      ),
      '',
    );
    result = result.replaceFirst(
      RegExp(
        r'^(?:cucharaditas?|cucharadas?|cdas?|cdtas?|cds|gramos?|g|kg|ml|litros?|l|pizcas?|pellizcos?|chorritos?|trocitos?|manojos?)\s+(?:de\s+)?',
        caseSensitive: false,
      ),
      '',
    );
    return result.trim().isEmpty ? value.trim() : _capitalize(result.trim());
  }

  RegExp _aliasPattern(String alias) => RegExp(
        '\\b${RegExp.escape(_normalize(alias))}\\b',
        caseSensitive: false,
      );

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');

  String _capitalize(String value) => value.isEmpty
      ? value
      : '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';

  static const Set<String> _measurementNoise = <String>{
    'a',
    'al',
    'aprox',
    'aproximadamente',
    'cda',
    'cdas',
    'cds',
    'cdta',
    'cdtas',
    'chorrito',
    'chorritos',
    'cocinar',
    'cucharada',
    'cucharadas',
    'cucharadita',
    'cucharaditas',
    'cuatro',
    'de',
    'decorar',
    'del',
    'dos',
    'el',
    'en',
    'fina',
    'fino',
    'fresca',
    'fresco',
    'g',
    'gr',
    'gramo',
    'gramos',
    'gruesa',
    'grueso',
    'gusto',
    'hoja',
    'hojas',
    'kg',
    'la',
    'las',
    'l',
    'litro',
    'litros',
    'los',
    'manojo',
    'manojos',
    'media',
    'medio',
    'ml',
    'molida',
    'molido',
    'o',
    'para',
    'pellizco',
    'pellizcos',
    'picada',
    'picado',
    'pizca',
    'pizcas',
    'polvo',
    'rallada',
    'rallado',
    'rama',
    'ramas',
    'ramita',
    'ramitas',
    'seca',
    'seco',
    'servir',
    'taza',
    'tazas',
    'tres',
    'trocito',
    'trocitos',
    'un',
    'una',
    'unas',
    'unos',
    'y',
  };

  static const List<_CondimentDefinition> _definitions = <_CondimentDefinition>[
    _CondimentDefinition('Sal', <String>[
      'flor de sal',
      'escamas de sal',
      'sal marina',
      'sal gruesa',
      'sal fina',
      'sal',
    ]),
    _CondimentDefinition('Pimienta negra', <String>['pimienta negra']),
    _CondimentDefinition('Pimienta blanca', <String>['pimienta blanca']),
    _CondimentDefinition('Pimienta', <String>['pimienta']),
    _CondimentDefinition('Comino', <String>['comino', 'comino en polvo']),
    _CondimentDefinition('Jengibre', <String>['jengibre']),
    _CondimentDefinition('Cúrcuma', <String>['curcuma']),
    _CondimentDefinition('Pimentón', <String>[
      'pimenton de la vera',
      'pimenton dulce',
      'pimenton picante',
      'pimenton',
      'paprika',
    ]),
    _CondimentDefinition('Orégano', <String>['oregano']),
    _CondimentDefinition('Tomillo', <String>['tomillo']),
    _CondimentDefinition('Romero', <String>['romero']),
    _CondimentDefinition('Albahaca', <String>['albahaca']),
    _CondimentDefinition('Perejil', <String>['perejil']),
    _CondimentDefinition('Cilantro', <String>['cilantro']),
    _CondimentDefinition('Eneldo', <String>['eneldo']),
    _CondimentDefinition('Laurel', <String>['hoja de laurel', 'laurel']),
    _CondimentDefinition('Canela', <String>['canela']),
    _CondimentDefinition('Nuez moscada', <String>['nuez moscada']),
    _CondimentDefinition('Clavo', <String>['clavo de olor', 'clavos de olor']),
    _CondimentDefinition('Cardamomo', <String>['cardamomo']),
    _CondimentDefinition('Curry', <String>['curry en polvo', 'curry']),
    _CondimentDefinition('Garam masala', <String>['garam masala']),
    _CondimentDefinition('Ras el hanout', <String>['ras el hanout']),
    _CondimentDefinition('Chile', <String>[
      'copos de chile',
      'chile en polvo',
      'chili flakes',
      'chile',
      'guindilla',
    ]),
    _CondimentDefinition('Cayena', <String>['pimienta de cayena', 'cayena']),
    _CondimentDefinition('Ajo en polvo', <String>['ajo en polvo']),
    _CondimentDefinition('Cebolla en polvo', <String>['cebolla en polvo']),
    _CondimentDefinition('Aceite de oliva', <String>[
      'aceite de oliva virgen extra',
      'aceite de oliva',
      'aove',
    ]),
    _CondimentDefinition('Aceite de sésamo', <String>['aceite de sesamo']),
    _CondimentDefinition('Aceite de girasol', <String>['aceite de girasol']),
    _CondimentDefinition('Aceite de coco', <String>['aceite de coco']),
    _CondimentDefinition('Vinagre de manzana', <String>['vinagre de manzana']),
    _CondimentDefinition('Vinagre balsámico', <String>[
      'vinagre balsamico',
      'aceto balsamico',
    ]),
    _CondimentDefinition('Vinagre de arroz', <String>['vinagre de arroz']),
    _CondimentDefinition('Vinagre', <String>['vinagre de vino', 'vinagre']),
    _CondimentDefinition('Mostaza', <String>['mostaza dijon', 'mostaza']),
    _CondimentDefinition('Salsa de soja', <String>['salsa de soja', 'soja']),
    _CondimentDefinition('Tamari', <String>['tamari']),
    _CondimentDefinition('Sriracha', <String>['sriracha']),
    _CondimentDefinition('Tabasco', <String>['tabasco']),
    _CondimentDefinition('Salsa Worcestershire', <String>[
      'salsa worcestershire',
      'salsa perrins',
    ]),
    _CondimentDefinition('Salsa de pescado', <String>['salsa de pescado']),
    _CondimentDefinition('Tahini', <String>['tahini']),
    _CondimentDefinition('Crema de cacahuete', <String>[
      'mantequilla de cacahuete',
      'crema de cacahuete',
    ]),
    _CondimentDefinition('Miel', <String>['miel']),
    _CondimentDefinition('Sirope de arce', <String>['sirope de arce']),
    _CondimentDefinition('Esencia de vainilla', <String>[
      'extracto de vainilla',
      'esencia de vainilla',
    ]),
    _CondimentDefinition('Levadura química', <String>[
      'polvo de hornear',
      'levadura quimica',
    ]),
    _CondimentDefinition(
        'Bicarbonato', <String>['bicarbonato sodico', 'bicarbonato']),
  ];
}

class _CondimentDefinition {
  const _CondimentDefinition(this.name, this.aliases);

  final String name;
  final List<String> aliases;
}
