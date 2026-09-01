import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

class ImportedRecipeData {
  const ImportedRecipeData({
    required this.title,
    this.description = '',
    this.category = 'Sin categoría',
    this.cuisine = '',
    this.servings = 1,
    this.prepMinutes = 0,
    this.cookMinutes = 0,
    this.ingredients = const <RecipeIngredient>[],
    this.instructions = const <String>[],
    this.tags = const <String>[],
    this.sourceUrl = '',
    this.imageSourceUrl = '',
  });

  final String title;
  final String description;
  final String category;
  final String cuisine;
  final int servings;
  final int prepMinutes;
  final int cookMinutes;
  final List<RecipeIngredient> ingredients;
  final List<String> instructions;
  final List<String> tags;
  final String sourceUrl;
  final String imageSourceUrl;
}

class RecipeImportService {
  Future<ImportedRecipeData> importUrl(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !<String>{'http', 'https'}.contains(uri.scheme)) {
      throw const FormatException('La dirección de la receta no es válida.');
    }
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(
        'No se pudo abrir la receta (${response.statusCode}).',
      );
    }
    final scripts = RegExp(
      r'''<script[^>]*type\s*=\s*["']application/ld\+json["'][^>]*>([\s\S]*?)</script>''',
      caseSensitive: false,
    ).allMatches(response.body);
    for (final script in scripts) {
      try {
        final decoded = jsonDecode(_decodeHtml(script.group(1)!.trim()));
        final recipe = _findRecipe(decoded);
        if (recipe != null) {
          return _fromSchema(recipe, sourceUrl: uri.toString());
        }
      } catch (_) {
        // Algunas páginas incluyen bloques JSON-LD auxiliares no válidos.
      }
    }
    throw const FormatException(
      'La página no contiene una receta compatible con schema.org.',
    );
  }

  ImportedRecipeData importJson(String source, {String sourceUrl = ''}) {
    final decoded = jsonDecode(source);
    final schemaRecipe = _findRecipe(decoded);
    if (schemaRecipe != null) {
      return _fromSchema(schemaRecipe, sourceUrl: sourceUrl);
    }
    if (decoded is! Map) {
      throw const FormatException('El JSON no contiene una receta válida.');
    }
    final map = decoded.cast<String, dynamic>();
    final recipe = Recipe.fromJson(map);
    if (recipe.title.trim().isEmpty) {
      throw const FormatException('La receta no tiene título.');
    }
    return ImportedRecipeData(
      title: recipe.title,
      description: recipe.description,
      category: recipe.category,
      cuisine: recipe.cuisine,
      servings: recipe.servings,
      prepMinutes: recipe.prepMinutes,
      cookMinutes: recipe.cookMinutes,
      ingredients: recipe.ingredients,
      instructions: recipe.instructions,
      tags: recipe.tags,
      sourceUrl: sourceUrl.isEmpty ? recipe.sourceUrl : sourceUrl,
      imageSourceUrl: recipe.imageSourceUrl,
    );
  }

  Map<String, dynamic>? _findRecipe(Object? value) {
    if (value is List) {
      for (final item in value) {
        final found = _findRecipe(item);
        if (found != null) return found;
      }
      return null;
    }
    if (value is! Map) return null;
    final map = value.cast<String, dynamic>();
    final type = map['@type'];
    if (type == 'Recipe' ||
        type is List &&
            type.map((item) => item.toString()).contains('Recipe')) {
      return map;
    }
    final graph = map['@graph'];
    if (graph != null) return _findRecipe(graph);
    return null;
  }

  ImportedRecipeData _fromSchema(
    Map<String, dynamic> json, {
    required String sourceUrl,
  }) {
    final title = _plainText(json['name']?.toString() ?? '');
    if (title.isEmpty) {
      throw const FormatException('La receta importada no tiene título.');
    }
    final total = _durationMinutes(json['totalTime']);
    final prep = _durationMinutes(json['prepTime']);
    var cook = _durationMinutes(json['cookTime']);
    if (cook == 0 && total > prep) cook = total - prep;
    return ImportedRecipeData(
      title: title,
      description: _plainText(json['description']?.toString() ?? ''),
      category: _firstText(json['recipeCategory'], fallback: 'Sin categoría'),
      cuisine: _firstText(json['recipeCuisine']),
      servings: _servings(json['recipeYield']),
      prepMinutes: prep,
      cookMinutes: cook,
      ingredients: _strings(json['recipeIngredient'])
          .map((value) => RecipeIngredient(text: _plainText(value)))
          .where((value) => value.text.isNotEmpty)
          .toList(),
      instructions: _instructions(json['recipeInstructions']),
      tags: <String>{
        ..._keywords(json['keywords']),
        ..._strings(json['suitableForDiet'])
            .map((value) => value.split('/').last.replaceAll('Diet', '')),
      }.where((value) => value.trim().isNotEmpty).toList(),
      sourceUrl: sourceUrl,
      imageSourceUrl: _imageUrl(json['image']),
    );
  }

  List<String> _instructions(Object? value) {
    final result = <String>[];
    void visit(Object? node) {
      if (node is String) {
        final text = _plainText(node);
        if (text.isNotEmpty) result.add(text);
      } else if (node is List) {
        for (final item in node) {
          visit(item);
        }
      } else if (node is Map) {
        final map = node.cast<String, dynamic>();
        if (map['itemListElement'] != null) {
          visit(map['itemListElement']);
        } else {
          visit(map['text'] ?? map['name']);
        }
      }
    }

    visit(value);
    return result;
  }

  List<String> _strings(Object? value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    if (value is String && value.trim().isNotEmpty) return <String>[value];
    return const <String>[];
  }

  List<String> _keywords(Object? value) {
    if (value is List) return _strings(value);
    return value
            ?.toString()
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList() ??
        const <String>[];
  }

  String _firstText(Object? value, {String fallback = ''}) {
    final values = _strings(value);
    return values.isEmpty ? fallback : _plainText(values.first);
  }

  int _servings(Object? value) {
    final match = RegExp(r'\d+').firstMatch(_firstText(value));
    return int.tryParse(match?.group(0) ?? '') ?? 1;
  }

  int _durationMinutes(Object? value) {
    final source = value?.toString().toUpperCase() ?? '';
    final match =
        RegExp(r'^P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?').firstMatch(source);
    if (match == null) return 0;
    return (int.tryParse(match.group(1) ?? '') ?? 0) * 1440 +
        (int.tryParse(match.group(2) ?? '') ?? 0) * 60 +
        (int.tryParse(match.group(3) ?? '') ?? 0);
  }

  String _imageUrl(Object? value) {
    if (value is String) return value;
    if (value is List && value.isNotEmpty) return _imageUrl(value.first);
    if (value is Map) {
      return (value['url'] ?? value['contentUrl'] ?? '').toString();
    }
    return '';
  }

  String _plainText(String value) => _decodeHtml(
        value.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(
              RegExp(r'\s+'),
              ' ',
            ),
      ).trim();

  String _decodeHtml(String value) => value
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
}
