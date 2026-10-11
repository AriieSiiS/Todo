part of 'todo_workspace.dart';

extension TodoWorkspaceRecetas on TodoWorkspace {
  Recipe? recipeById(String id) {
    for (final recipe in _recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  WeeklyMenu? weeklyMenuById(String id) {
    for (final menu in _weeklyMenus) {
      if (menu.id == id) return menu;
    }
    return null;
  }

  List<Recipe> recipesForWeeklyMenu(WeeklyMenu menu) => menu.allRecipeIds
      .map(recipeById)
      .whereType<Recipe>()
      .toList(growable: false);

  Future<String> weeklyMenuImageAbsolutePath(
    WeeklyMenu menu, {
    bool thumbnail = true,
  }) {
    final path = thumbnail && menu.thumbnailPath.isNotEmpty
        ? menu.thumbnailPath
        : menu.imagePath;
    return _recipeAssets.absolutePath(path);
  }

  WeeklyMenu createWeeklyMenu({
    required String title,
    String description = '',
    int people = 1,
    int totalPriceCents = 0,
    List<String> recipeIds = const <String>[],
    List<WeeklyMenuEntry> mealEntries = const <WeeklyMenuEntry>[],
    List<WeeklyMenuShoppingItem> shoppingItems =
        const <WeeklyMenuShoppingItem>[],
    String sourceUrl = '',
    String imageSourceUrl = '',
  }) {
    final instant = DateTime.now();
    final validRecipeIds =
        recipeIds.where((id) => recipeById(id) != null).toSet().toList();
    final validEntries = mealEntries
        .where((entry) => recipeById(entry.recipeId) != null)
        .toList();
    final resolvedEntries = validEntries.isNotEmpty
        ? validEntries
        : <WeeklyMenuEntry>[
            for (var index = 0; index < validRecipeIds.length; index++)
              WeeklyMenuEntry(
                id: _id('weekly-meal'),
                day: WeeklyMenuDay.values[index % WeeklyMenuDay.values.length],
                mealType: WeeklyMealType.lunch,
                recipeId: validRecipeIds[index],
              ),
          ];
    final menu = WeeklyMenu(
      id: _id('weekly-menu'),
      title: title.trim().isEmpty ? 'Menú semanal' : title.trim(),
      description: description.trim(),
      people: people.clamp(1, 1000),
      totalPriceCents: totalPriceCents.clamp(0, 100000000),
      recipeIds:
          resolvedEntries.map((entry) => entry.recipeId).toSet().toList(),
      shoppingListRecipeIds: shoppingItems.isEmpty
          ? const <String>[]
          : resolvedEntries.map((entry) => entry.recipeId).toSet().toList(),
      mealEntries: resolvedEntries,
      shoppingItems:
          shoppingItems.where((item) => item.name.trim().isNotEmpty).toList(),
      sourceUrl: sourceUrl.trim(),
      imageSourceUrl: imageSourceUrl.trim(),
      createdAt: instant,
      updatedAt: instant,
    );
    _weeklyMenus.add(menu);
    _commit();
    return menu;
  }

  void setWeeklyMenuMeal(
    String menuId, {
    required WeeklyMenuDay day,
    required WeeklyMealType mealType,
    String? recipeId,
  }) {
    final index = _weeklyMenus.indexWhere((menu) => menu.id == menuId);
    if (index == -1) return;
    final entries = _weeklyMenus[index]
        .mealEntries
        .where((entry) => entry.day != day || entry.mealType != mealType)
        .toList();
    if (recipeId != null && recipeById(recipeId) != null) {
      entries.add(WeeklyMenuEntry(
        id: _id('weekly-meal'),
        day: day,
        mealType: mealType,
        recipeId: recipeId,
      ));
    }
    entries.sort((left, right) {
      final dayOrder = left.day.index.compareTo(right.day.index);
      return dayOrder != 0
          ? dayOrder
          : left.mealType.index.compareTo(right.mealType.index);
    });
    _weeklyMenus[index] = _weeklyMenus[index].copyWith(
      recipeIds: entries.map((entry) => entry.recipeId).toSet().toList(),
      mealEntries: entries,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  TaskModel createWeeklyMenuShoppingTask(
    String menuId, {
    DateTime? scheduledAt,
    List<String> selectedEntryIds = const <String>[],
  }) {
    final menu = weeklyMenuById(menuId);
    if (menu == null) throw StateError('No se encuentra el menú semanal.');
    final availableEntries = menu.mealEntries
        .where((entry) => recipeById(entry.recipeId) != null)
        .toList();
    final requestedIds = selectedEntryIds.toSet();
    final selectedEntries = requestedIds.isEmpty
        ? availableEntries
        : availableEntries
            .where((entry) => requestedIds.contains(entry.id))
            .toList();
    if (selectedEntries.isEmpty) {
      throw StateError('Selecciona al menos una comida del menú.');
    }
    final selectedIds = selectedEntries.map((entry) => entry.id).toSet();
    final completeMenu = availableEntries.isNotEmpty &&
        selectedIds.length == availableEntries.length &&
        availableEntries.every((entry) => selectedIds.contains(entry.id));
    final curatedSelection =
        _weeklyMenuSelectionUsesCuratedList(menu, selectedEntries);
    final shoppingItems = curatedSelection
        ? menu.shoppingItems
        : _shoppingItemsForWeeklyMenuEntries(selectedEntries);
    if (shoppingItems.isEmpty) {
      throw StateError('Las recetas elegidas no tienen ingredientes.');
    }
    final category = _ensureTaskCategory(
      'Compras',
      const Color(0xFFDBA62D),
      Icons.shopping_cart_rounded,
    );
    final date = scheduledAt ?? logicalDate();
    final price = curatedSelection && menu.totalPriceCents > 0
        ? ' · Presupuesto aproximado: ${_formatEuroCents(menu.totalPriceCents)}.'
        : '';
    final selectedDays = selectedEntries.map((entry) => entry.day).toSet();
    final scope = completeMenu
        ? 'semana completa'
        : '${selectedEntries.length} ${selectedEntries.length == 1 ? 'comida' : 'comidas'} · '
            '${selectedDays.length} ${selectedDays.length == 1 ? 'día' : 'días'}';
    final task = createTask(
      title: completeMenu
          ? 'Comprar ${menu.title}'
          : 'Comprar selección de ${menu.title}',
      description: 'Lista de compra del menú para ${menu.people} '
          '${menu.people == 1 ? 'persona' : 'personas'} · $scope$price',
      categoryIds: <String>[category.id],
      scheduledAt: date,
    );
    final seen = <String>{};
    for (final item in shoppingItems) {
      final key = item.name.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) continue;
      createTask(
        title: item.name.trim(),
        description: <String>[
          if (item.group.trim().isNotEmpty) item.group.trim(),
          if (item.priceCents > 0)
            'Precio orientativo: ${_formatEuroCents(item.priceCents)}',
        ].join(' · '),
        categoryIds: <String>[category.id],
        scheduledAt: date,
        parentTaskId: task.id,
      );
    }
    return taskById(task.id) ?? task;
  }

  List<WeeklyMenuShoppingItem> weeklyMenuShoppingItemsForSelection(
    String menuId,
    Iterable<String> selectedEntryIds,
  ) {
    final menu = weeklyMenuById(menuId);
    if (menu == null) return const <WeeklyMenuShoppingItem>[];
    final selectedIds = selectedEntryIds.toSet();
    if (selectedIds.isEmpty) return const <WeeklyMenuShoppingItem>[];
    final available = menu.mealEntries
        .where((entry) => recipeById(entry.recipeId) != null)
        .toList();
    final selected =
        available.where((entry) => selectedIds.contains(entry.id)).toList();
    final curatedSelection =
        _weeklyMenuSelectionUsesCuratedList(menu, selected);
    return curatedSelection
        ? List<WeeklyMenuShoppingItem>.unmodifiable(menu.shoppingItems)
        : List<WeeklyMenuShoppingItem>.unmodifiable(
            _shoppingItemsForWeeklyMenuEntries(selected),
          );
  }

  bool weeklyMenuSelectionUsesCuratedList(
    String menuId,
    Iterable<String> selectedEntryIds,
  ) {
    final menu = weeklyMenuById(menuId);
    if (menu == null) return false;
    final selectedIds = selectedEntryIds.toSet();
    final selected = menu.mealEntries
        .where((entry) => selectedIds.contains(entry.id))
        .toList();
    return _weeklyMenuSelectionUsesCuratedList(menu, selected);
  }

  bool _weeklyMenuSelectionUsesCuratedList(
    WeeklyMenu menu,
    List<WeeklyMenuEntry> selectedEntries,
  ) {
    if (menu.shoppingItems.isEmpty || menu.shoppingListRecipeIds.isEmpty) {
      return false;
    }
    final selectedRecipeIds =
        selectedEntries.map((entry) => entry.recipeId).toList();
    final selectedSet = selectedRecipeIds.toSet();
    final curatedSet = menu.shoppingListRecipeIds.toSet();
    return selectedRecipeIds.length == selectedSet.length &&
        selectedSet.length == curatedSet.length &&
        selectedSet.containsAll(curatedSet);
  }

  List<WeeklyMenuShoppingItem> _shoppingItemsForWeeklyMenuEntries(
    Iterable<WeeklyMenuEntry> entries,
  ) {
    final items = <WeeklyMenuShoppingItem>[];
    final seen = <String>{};
    final recipeIds = entries.map((entry) => entry.recipeId).toSet();
    for (final recipeId in recipeIds) {
      final recipe = recipeById(recipeId);
      if (recipe == null) continue;
      for (final ingredient in recipe.ingredients) {
        for (final label
            in _recipeIngredientClassifier.shoppingLabels(ingredient)) {
          final key = label.trim().toLowerCase();
          if (key.isEmpty || !seen.add(key)) continue;
          items.add(WeeklyMenuShoppingItem(
            name: label.trim(),
            group: recipe.title,
          ));
        }
      }
    }
    return items;
  }

  String _formatEuroCents(int cents) {
    final euros = cents / 100;
    return '${euros.toStringAsFixed(cents % 100 == 0 ? 0 : 2).replaceAll('.', ',')} €';
  }

  Future<String> recipeImageAbsolutePath(
    Recipe recipe, {
    bool thumbnail = true,
  }) {
    final path = thumbnail && recipe.thumbnailPath.isNotEmpty
        ? recipe.thumbnailPath
        : recipe.imagePath;
    return _recipeAssets.absolutePath(path);
  }

  Recipe createRecipe({
    required String title,
    String description = '',
    String category = 'Sin categoría',
    String cuisine = '',
    int servings = 1,
    int prepMinutes = 0,
    int cookMinutes = 0,
    List<RecipeIngredient> ingredients = const <RecipeIngredient>[],
    List<String> instructions = const <String>[],
    List<String> tags = const <String>[],
    String sourceUrl = '',
    String imageSourceUrl = '',
  }) {
    final instant = DateTime.now();
    final recipe = Recipe(
      id: _id('recipe'),
      title: title.trim().isEmpty ? 'Receta sin nombre' : title.trim(),
      description: description.trim(),
      category: category.trim().isEmpty ? 'Sin categoría' : category.trim(),
      cuisine: cuisine.trim(),
      servings: servings.clamp(1, 1000),
      prepMinutes: prepMinutes.clamp(0, 10080),
      cookMinutes: cookMinutes.clamp(0, 10080),
      ingredients: _normalizedRecipeIngredients(ingredients),
      instructions: instructions
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      tags: tags
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(),
      sourceUrl: sourceUrl.trim(),
      imageSourceUrl: imageSourceUrl.trim(),
      createdAt: instant,
      updatedAt: instant,
    );
    _recipes.add(recipe);
    _commit();
    return recipe;
  }

  void updateRecipe(
    String id, {
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
  }) {
    final index = _recipes.indexWhere((recipe) => recipe.id == id);
    if (index == -1) return;
    _recipes[index] = _recipes[index].copyWith(
      title: title?.trim(),
      description: description?.trim(),
      category:
          category?.trim().isEmpty == true ? 'Sin categoría' : category?.trim(),
      cuisine: cuisine?.trim(),
      servings: servings?.clamp(1, 1000),
      prepMinutes: prepMinutes?.clamp(0, 10080),
      cookMinutes: cookMinutes?.clamp(0, 10080),
      ingredients: ingredients == null
          ? null
          : _normalizedRecipeIngredients(ingredients),
      instructions: instructions
          ?.map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      tags: tags
          ?.map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(),
      sourceUrl: sourceUrl?.trim(),
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  Future<void> importRecipeImage(String id, String sourcePath) async {
    if (recipeById(id) == null) {
      throw StateError('No se encuentra la receta.');
    }
    await _importRecipeStoredImage(
      id,
      await _recipeAssets.importImage(id, sourcePath),
    );
  }

  Future<void> importRecipeImageBytes(String id, Uint8List bytes) async {
    if (recipeById(id) == null) {
      throw StateError('No se encuentra la receta.');
    }
    await _importRecipeStoredImage(
      id,
      await _recipeAssets.importImageBytes(id, bytes),
    );
  }

  Future<void> _importRecipeStoredImage(
    String id,
    RecipeImportedImage imported,
  ) async {
    final index = _recipes.indexWhere((recipe) => recipe.id == id);
    if (index == -1) throw StateError('No se encuentra la receta.');
    final previousImage = _recipes[index].imagePath;
    final previousThumbnail = _recipes[index].thumbnailPath;
    _recipes[index] = _recipes[index].copyWith(
      imagePath: imported.imagePath,
      thumbnailPath: imported.thumbnailPath,
      imageSha256: imported.sha256,
      updatedAt: DateTime.now(),
    );
    _commit();
    for (final path in <String>[previousImage, previousThumbnail]) {
      if (path.isNotEmpty &&
          path != imported.imagePath &&
          path != imported.thumbnailPath) {
        await _recipeAssets.deleteAsset(path);
      }
    }
  }

  Future<void> importRecipeImageFromUrl(String id, String sourceUrl) async {
    final index = _recipes.indexWhere((recipe) => recipe.id == id);
    if (index == -1) throw StateError('No se encuentra la receta.');
    final imported = await _recipeAssets.importImageFromUrl(id, sourceUrl);
    _recipes[index] = _recipes[index].copyWith(
      imagePath: imported.imagePath,
      thumbnailPath: imported.thumbnailPath,
      imageSha256: imported.sha256,
      imageSourceUrl: sourceUrl,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  Future<Recipe> importRecipeFromUrl(String sourceUrl) async {
    final imported = await _recipeImporter.importUrl(sourceUrl);
    final recipe = _createImportedRecipe(imported);
    if (imported.imageSourceUrl.isNotEmpty) {
      try {
        await importRecipeImageFromUrl(recipe.id, imported.imageSourceUrl);
      } catch (_) {
        // La receta sigue siendo útil aunque la página bloquee su imagen.
      }
    }
    return recipeById(recipe.id) ?? recipe;
  }

  Recipe importRecipeFromJson(String source) {
    return _createImportedRecipe(_recipeImporter.importJson(source));
  }

  Recipe _createImportedRecipe(ImportedRecipeData imported) => createRecipe(
        title: imported.title,
        description: imported.description,
        category: imported.category,
        cuisine: imported.cuisine,
        servings: imported.servings,
        prepMinutes: imported.prepMinutes,
        cookMinutes: imported.cookMinutes,
        ingredients: imported.ingredients,
        instructions: imported.instructions,
        tags: imported.tags,
        sourceUrl: imported.sourceUrl,
        imageSourceUrl: imported.imageSourceUrl,
      );

  void toggleRecipeFavorite(String id) {
    final index = _recipes.indexWhere((recipe) => recipe.id == id);
    if (index == -1) return;
    _recipes[index] = _recipes[index].copyWith(
      favorite: !_recipes[index].favorite,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void archiveRecipe(String id) {
    final index = _recipes.indexWhere((recipe) => recipe.id == id);
    if (index == -1) return;
    _recipes[index] = _recipes[index].copyWith(
      archived: true,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void deleteRecipe(String id) {
    final recipe = recipeById(id);
    if (recipe == null) return;
    _recipes.removeWhere((value) => value.id == id);
    _commit();
    for (final path in <String>[recipe.imagePath, recipe.thumbnailPath]) {
      if (path.isNotEmpty) unawaited(_recipeAssets.deleteAsset(path));
    }
  }

  TaskModel createRecipeShoppingTask(
    String recipeId, {
    DateTime? scheduledAt,
  }) {
    final recipe = recipeById(recipeId);
    if (recipe == null) throw StateError('No se encuentra la receta.');
    if (recipe.ingredients.isEmpty) {
      throw StateError('La receta no tiene ingredientes.');
    }
    final category = _ensureTaskCategory(
      'Compras',
      const Color(0xFFDBA62D),
      Icons.shopping_cart_rounded,
    );
    final date = scheduledAt ?? logicalDate();
    final task = createTask(
      title: 'Comprar ingredientes para ${recipe.title}',
      description: 'Lista generada desde Recetas · ${recipe.servings} '
          '${recipe.servings == 1 ? 'ración' : 'raciones'}.',
      categoryIds: <String>[category.id],
      scheduledAt: date,
    );
    final shoppingLabels = <String>[];
    final seenLabels = <String>{};
    for (final ingredient in recipe.ingredients) {
      for (final label
          in _recipeIngredientClassifier.shoppingLabels(ingredient)) {
        final key = label.trim().toLowerCase();
        if (key.isNotEmpty && seenLabels.add(key)) shoppingLabels.add(label);
      }
    }
    for (final label in shoppingLabels) {
      createTask(
        title: label,
        categoryIds: <String>[category.id],
        scheduledAt: date,
        parentTaskId: task.id,
      );
    }
    return taskById(task.id) ?? task;
  }

  List<RecipeIngredient> _normalizedRecipeIngredients(
    Iterable<RecipeIngredient> ingredients,
  ) {
    return ingredients
        .map((value) => value.copyWith(
              text: value.text.trim(),
              group: value.group.trim(),
            ))
        .where((value) => value.text.isNotEmpty)
        .map(_recipeIngredientClassifier.classify)
        .toList();
  }

  TaskModel createRecipeCookingTask(
    String recipeId, {
    DateTime? scheduledAt,
  }) {
    final recipe = recipeById(recipeId);
    if (recipe == null) throw StateError('No se encuentra la receta.');
    final category = _ensureTaskCategory(
      'Cocina',
      const Color(0xFFC7744E),
      Icons.restaurant_rounded,
    );
    final date = scheduledAt ?? logicalDate();
    final time = recipe.totalMinutes > 0
        ? 'Tiempo estimado: ${recipe.totalMinutes} min.'
        : 'Tiempo estimado pendiente.';
    final task = createTask(
      title: 'Preparar ${recipe.title}',
      description: '$time · ${recipe.servings} '
          '${recipe.servings == 1 ? 'ración' : 'raciones'}.',
      categoryIds: <String>[category.id],
      scheduledAt: date,
    );
    for (var index = 0; index < recipe.instructions.length; index++) {
      createTask(
        title: '${index + 1}. ${recipe.instructions[index]}',
        categoryIds: <String>[category.id],
        scheduledAt: date,
        parentTaskId: task.id,
      );
    }
    return taskById(task.id) ?? task;
  }
}
