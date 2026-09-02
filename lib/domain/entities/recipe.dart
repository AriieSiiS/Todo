import 'json_helpers.dart';

enum RecipeIngredientKind { ingredient, condiment }

class RecipeIngredient {
  const RecipeIngredient({
    required this.text,
    this.group = '',
    this.kind = RecipeIngredientKind.ingredient,
  });

  final String text;
  final String group;
  final RecipeIngredientKind kind;

  bool get isCondiment => kind == RecipeIngredientKind.condiment;

  RecipeIngredient copyWith({
    String? text,
    String? group,
    RecipeIngredientKind? kind,
  }) =>
      RecipeIngredient(
        text: text ?? this.text,
        group: group ?? this.group,
        kind: kind ?? this.kind,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        'group': group,
        'kind': kind.name,
      };

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        text: json['text'] as String? ?? '',
        group: json['group'] as String? ?? '',
        kind: enumByName(
          RecipeIngredientKind.values,
          json['kind'] as String?,
          RecipeIngredientKind.ingredient,
        ),
      );
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
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
    this.imagePath = '',
    this.thumbnailPath = '',
    this.imageSha256 = '',
    this.favorite = false,
    this.archived = false,
  });

  final String id;
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
  final String imagePath;
  final String thumbnailPath;
  final String imageSha256;
  final bool favorite;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalMinutes => prepMinutes + cookMinutes;

  Recipe copyWith({
    String? title,
    String? description,
    String? category,
    String? cuisine,
    int? servings,
    int? prepMinutes,
    int? cookMinutes,
    List<RecipeIngredient>? ingredients,
    List<String>? instructions,
    List<String>? tags,
    String? sourceUrl,
    String? imageSourceUrl,
    String? imagePath,
    String? thumbnailPath,
    String? imageSha256,
    bool? favorite,
    bool? archived,
    DateTime? updatedAt,
  }) {
    return Recipe(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      cuisine: cuisine ?? this.cuisine,
      servings: servings ?? this.servings,
      prepMinutes: prepMinutes ?? this.prepMinutes,
      cookMinutes: cookMinutes ?? this.cookMinutes,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      tags: tags ?? this.tags,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      imageSourceUrl: imageSourceUrl ?? this.imageSourceUrl,
      imagePath: imagePath ?? this.imagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      imageSha256: imageSha256 ?? this.imageSha256,
      favorite: favorite ?? this.favorite,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'cuisine': cuisine,
        'servings': servings,
        'prepMinutes': prepMinutes,
        'cookMinutes': cookMinutes,
        'ingredients': ingredients.map((value) => value.toJson()).toList(),
        'instructions': instructions,
        'tags': tags,
        'sourceUrl': sourceUrl,
        'imageSourceUrl': imageSourceUrl,
        'imagePath': imagePath,
        'thumbnailPath': thumbnailPath,
        'imageSha256': imageSha256,
        'favorite': favorite,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Receta sin nombre',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'Sin categoría',
        cuisine: json['cuisine'] as String? ?? '',
        servings: (json['servings'] as num?)?.toInt() ?? 1,
        prepMinutes: (json['prepMinutes'] as num?)?.toInt() ?? 0,
        cookMinutes: (json['cookMinutes'] as num?)?.toInt() ?? 0,
        ingredients: (json['ingredients'] as List<dynamic>? ?? const [])
            .map((value) => value is String
                ? RecipeIngredient(text: value)
                : RecipeIngredient.fromJson(
                    (value as Map<dynamic, dynamic>).cast<String, dynamic>()))
            .where((value) => value.text.trim().isNotEmpty)
            .toList(),
        instructions: stringList(json['instructions']),
        tags: stringList(json['tags']),
        sourceUrl: json['sourceUrl'] as String? ?? '',
        imageSourceUrl: json['imageSourceUrl'] as String? ?? '',
        imagePath: json['imagePath'] as String? ?? '',
        thumbnailPath: json['thumbnailPath'] as String? ?? '',
        imageSha256: json['imageSha256'] as String? ?? '',
        favorite: json['favorite'] as bool? ?? false,
        archived: json['archived'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class WeeklyMenuShoppingItem {
  const WeeklyMenuShoppingItem({
    required this.name,
    this.group = '',
    this.priceCents = 0,
  });

  final String name;
  final String group;
  final int priceCents;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'group': group,
        'priceCents': priceCents,
      };

  factory WeeklyMenuShoppingItem.fromJson(Map<String, dynamic> json) =>
      WeeklyMenuShoppingItem(
        name: json['name'] as String? ?? '',
        group: json['group'] as String? ?? '',
        priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
      );
}

enum WeeklyMenuDay {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday
}

enum WeeklyMealType { breakfast, lunch, snack, dinner }

class WeeklyMenuEntry {
  const WeeklyMenuEntry({
    required this.id,
    required this.day,
    required this.mealType,
    required this.recipeId,
  });

  final String id;
  final WeeklyMenuDay day;
  final WeeklyMealType mealType;
  final String recipeId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'day': day.name,
        'mealType': mealType.name,
        'recipeId': recipeId,
      };

  factory WeeklyMenuEntry.fromJson(Map<String, dynamic> json) =>
      WeeklyMenuEntry(
        id: json['id'] as String? ?? '',
        day: enumByName(
          WeeklyMenuDay.values,
          json['day'] as String?,
          WeeklyMenuDay.monday,
        ),
        mealType: enumByName(
          WeeklyMealType.values,
          json['mealType'] as String?,
          WeeklyMealType.lunch,
        ),
        recipeId: json['recipeId'] as String? ?? '',
      );
}

class WeeklyMenu {
  const WeeklyMenu({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.people = 1,
    this.totalPriceCents = 0,
    this.recipeIds = const <String>[],
    this.shoppingListRecipeIds = const <String>[],
    this.mealEntries = const <WeeklyMenuEntry>[],
    this.shoppingItems = const <WeeklyMenuShoppingItem>[],
    this.sourceUrl = '',
    this.imageSourceUrl = '',
    this.imagePath = '',
    this.thumbnailPath = '',
    this.imageSha256 = '',
    this.archived = false,
  });

  final String id;
  final String title;
  final String description;
  final int people;
  final int totalPriceCents;
  final List<String> recipeIds;
  final List<String> shoppingListRecipeIds;
  final List<WeeklyMenuEntry> mealEntries;
  final List<WeeklyMenuShoppingItem> shoppingItems;
  final String sourceUrl;
  final String imageSourceUrl;
  final String imagePath;
  final String thumbnailPath;
  final String imageSha256;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  List<String> get allRecipeIds => mealEntries.isEmpty
      ? recipeIds
      : mealEntries.map((entry) => entry.recipeId).toSet().toList();

  WeeklyMenu copyWith({
    String? title,
    String? description,
    int? people,
    int? totalPriceCents,
    List<String>? recipeIds,
    List<String>? shoppingListRecipeIds,
    List<WeeklyMenuEntry>? mealEntries,
    List<WeeklyMenuShoppingItem>? shoppingItems,
    String? sourceUrl,
    String? imageSourceUrl,
    String? imagePath,
    String? thumbnailPath,
    String? imageSha256,
    bool? archived,
    DateTime? updatedAt,
  }) =>
      WeeklyMenu(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        people: people ?? this.people,
        totalPriceCents: totalPriceCents ?? this.totalPriceCents,
        recipeIds: recipeIds ?? this.recipeIds,
        shoppingListRecipeIds:
            shoppingListRecipeIds ?? this.shoppingListRecipeIds,
        mealEntries: mealEntries ?? this.mealEntries,
        shoppingItems: shoppingItems ?? this.shoppingItems,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        imageSourceUrl: imageSourceUrl ?? this.imageSourceUrl,
        imagePath: imagePath ?? this.imagePath,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        imageSha256: imageSha256 ?? this.imageSha256,
        archived: archived ?? this.archived,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'description': description,
        'people': people,
        'totalPriceCents': totalPriceCents,
        'recipeIds': recipeIds,
        'shoppingListRecipeIds': shoppingListRecipeIds,
        'mealEntries': mealEntries.map((entry) => entry.toJson()).toList(),
        'shoppingItems': shoppingItems.map((item) => item.toJson()).toList(),
        'sourceUrl': sourceUrl,
        'imageSourceUrl': imageSourceUrl,
        'imagePath': imagePath,
        'thumbnailPath': thumbnailPath,
        'imageSha256': imageSha256,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WeeklyMenu.fromJson(Map<String, dynamic> json) {
    final recipeIds = stringList(json['recipeIds']);
    var entries = (json['mealEntries'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => WeeklyMenuEntry.fromJson(
            (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
        .where((entry) => entry.recipeId.trim().isNotEmpty)
        .toList();
    if (entries.isEmpty) {
      entries = <WeeklyMenuEntry>[
        for (var index = 0; index < recipeIds.length; index++)
          WeeklyMenuEntry(
            id: 'legacy-${index + 1}',
            day: WeeklyMenuDay.values[index % WeeklyMenuDay.values.length],
            mealType: WeeklyMealType.lunch,
            recipeId: recipeIds[index],
          ),
      ];
    }
    final resolvedRecipeIds = recipeIds.isEmpty
        ? entries.map((entry) => entry.recipeId).toSet().toList()
        : recipeIds;
    final shoppingListRecipeIds = stringList(json['shoppingListRecipeIds']);
    return WeeklyMenu(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Menú semanal',
      description: json['description'] as String? ?? '',
      people: (json['people'] as num?)?.toInt() ?? 1,
      totalPriceCents: (json['totalPriceCents'] as num?)?.toInt() ?? 0,
      recipeIds: resolvedRecipeIds,
      shoppingListRecipeIds: shoppingListRecipeIds.isEmpty
          ? resolvedRecipeIds
          : shoppingListRecipeIds,
      mealEntries: entries,
      shoppingItems:
          (json['shoppingItems'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => WeeklyMenuShoppingItem.fromJson(
                  (item as Map<dynamic, dynamic>).cast<String, dynamic>()))
              .where((item) => item.name.trim().isNotEmpty)
              .toList(),
      sourceUrl: json['sourceUrl'] as String? ?? '',
      imageSourceUrl: json['imageSourceUrl'] as String? ?? '',
      imagePath: json['imagePath'] as String? ?? '',
      thumbnailPath: json['thumbnailPath'] as String? ?? '',
      imageSha256: json['imageSha256'] as String? ?? '',
      archived: json['archived'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
