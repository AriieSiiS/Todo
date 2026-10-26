import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';
import 'package:todo/services/recipe_asset_service.dart';
import 'package:todo/services/recipe_import_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('el snapshot conserva recetas y migra snapshots antiguos', () {
    final instant = DateTime.utc(2026, 9, 1);
    final snapshot = AppStateSnapshot(
      tasks: const [],
      categories: const [],
      projects: const [],
      notes: const [],
      recipes: [
        Recipe(
          id: 'papas-1',
          title: 'Papas arrugadas',
          category: 'Guarniciones',
          servings: 4,
          prepMinutes: 5,
          cookMinutes: 25,
          ingredients: const [
            RecipeIngredient(text: '1 kg de papas bonitas'),
            RecipeIngredient(
              text: '250 g de sal gruesa',
              kind: RecipeIngredientKind.condiment,
            ),
          ],
          instructions: const ['Lava las papas.', 'Cuécelas con la sal.'],
          createdAt: instant,
          updatedAt: instant,
        ),
      ],
      weeklyMenus: [
        WeeklyMenu(
          id: 'menu-1',
          title: 'Menú semanal 01',
          people: 1,
          totalPriceCents: 2200,
          recipeIds: const ['papas-1'],
          shoppingItems: const [
            WeeklyMenuShoppingItem(
              name: 'Papas bonitas',
              group: 'Frutas y verduras',
              priceCents: 120,
            ),
          ],
          createdAt: instant,
          updatedAt: instant,
        ),
      ],
      daySettings: const DaySettings(),
      notificationSettings: const DeviceNotificationSettings(),
      calendarSettings: const CalendarIntegrationSettings(),
      section: AppSection.recipes,
      todaySort: TodaySort.manual,
    );

    final decoded = AppStateSnapshot.fromEncodedJson(snapshot.toEncodedJson());
    final legacy = AppStateSnapshot.fromJson(<String, dynamic>{});

    expect(decoded.recipes.single.title, 'Papas arrugadas');
    expect(decoded.recipes.single.totalMinutes, 30);
    expect(decoded.recipes.single.ingredients.last.isCondiment, isTrue);
    expect(decoded.weeklyMenus.single.totalPriceCents, 2200);
    expect(decoded.weeklyMenus.single.recipeIds, ['papas-1']);
    expect(decoded.weeklyMenus.single.mealEntries.single.day,
        WeeklyMenuDay.monday);
    expect(decoded.weeklyMenus.single.mealEntries.single.mealType,
        WeeklyMealType.lunch);
    expect(decoded.section, AppSection.recipes);
    expect(legacy.recipes, isEmpty);
    expect(legacy.weeklyMenus, isEmpty);
  });

  test('un menú semanal genera una única tarea de compra agrupada', () {
    final controller = TodoWorkspace.createForTest();
    final recipe = controller.createRecipe(
      title: 'Bowl de salmón',
      ingredients: const [
        RecipeIngredient(text: '500 g de salmón'),
        RecipeIngredient(text: '½ cucharadita de sal'),
      ],
    );
    final secondRecipe = controller.createRecipe(
      title: 'Ensalada de aguacate',
      ingredients: const [RecipeIngredient(text: '2 aguacates')],
    );
    final menu = controller.createWeeklyMenu(
      title: 'Menú semanal 01',
      people: 1,
      totalPriceCents: 2200,
      recipeIds: [recipe.id, secondRecipe.id],
      shoppingItems: const [
        WeeklyMenuShoppingItem(
          name: 'Salmón congelado',
          group: 'Proteínas',
          priceCents: 540,
        ),
        WeeklyMenuShoppingItem(
          name: 'Aguacate',
          group: 'Frutas y verduras',
          priceCents: 88,
        ),
      ],
    );

    final task = controller.createWeeklyMenuShoppingTask(menu.id);
    final partialTask = controller.createWeeklyMenuShoppingTask(
      menu.id,
      selectedEntryIds: [menu.mealEntries.first.id],
    );

    expect(task.title, 'Comprar Menú semanal 01');
    expect(task.origin, TaskOrigin.shoppingList);
    expect(controller.subtasksOf(task).map((item) => item.title),
        ['Salmón congelado', 'Aguacate']);
    expect(partialTask.title, 'Comprar selección de Menú semanal 01');
    expect(controller.subtasksOf(partialTask).map((item) => item.title),
        ['500 g de salmón', 'Sal']);
    expect(controller.recipesForWeeklyMenu(menu), hasLength(2));
    expect(
      controller.weeklyMenuSelectionUsesCuratedList(
        menu.id,
        menu.mealEntries.map((entry) => entry.id),
      ),
      isTrue,
    );

    controller.setWeeklyMenuMeal(
      menu.id,
      day: WeeklyMenuDay.wednesday,
      mealType: WeeklyMealType.breakfast,
      recipeId: secondRecipe.id,
    );
    expect(
      controller.weeklyMenuById(menu.id)!.mealEntries,
      contains(predicate<WeeklyMenuEntry>((entry) =>
          entry.day == WeeklyMenuDay.wednesday &&
          entry.mealType == WeeklyMealType.breakfast &&
          entry.recipeId == secondRecipe.id)),
    );
    final editedMenu = controller.weeklyMenuById(menu.id)!;
    expect(
      controller.weeklyMenuSelectionUsesCuratedList(
        menu.id,
        editedMenu.mealEntries.map((entry) => entry.id),
      ),
      isFalse,
    );
  });

  test('una lista manual conserva sus productos como subtareas', () {
    final controller = TodoWorkspace.createForTest();
    final list = controller.createManualShoppingList(
      title: 'Compra del sábado',
      items: [' Pan ', '', 'Leche'],
    );
    expect(list.origin, TaskOrigin.shoppingList);
    expect(list.title, 'Compra del sábado');
    expect(controller.subtasksOf(list).map((item) => item.title),
        ['Pan', 'Leche']);
    expect(
      () => controller.createManualShoppingList(title: '', items: ['Pan']),
      throwsStateError,
    );
  });

  test('una receta genera tareas de compra y cocina con subtareas', () {
    final controller = TodoWorkspace.createForTest();
    final recipe = controller.createRecipe(
      title: 'Pasta al tomate',
      servings: 2,
      ingredients: const [
        RecipeIngredient(text: '250 g de pasta'),
        RecipeIngredient(text: '2 tomates'),
        RecipeIngredient(text: '½ cebolla'),
        RecipeIngredient(text: '½ cucharadita de comino'),
        RecipeIngredient(text: 'Un trocito de jengibre y cúrcuma'),
        RecipeIngredient(text: 'Sal y pimienta al gusto'),
        RecipeIngredient(text: 'Salmón'),
      ],
      instructions: const ['Cuece la pasta.', 'Prepara la salsa.'],
    );

    final shopping = controller.createRecipeShoppingTask(recipe.id);
    final cooking = controller.createRecipeCookingTask(recipe.id);

    expect(shopping.title, 'Comprar ingredientes para Pasta al tomate');
    expect(controller.subtasksOf(shopping).map((task) => task.title), [
      '250 g de pasta',
      '2 tomates',
      '½ cebolla',
      'Comino',
      'Jengibre',
      'Cúrcuma',
      'Sal',
      'Pimienta',
      'Salmón',
    ]);
    expect(controller.subtasksOf(cooking).map((task) => task.title),
        ['1. Cuece la pasta.', '2. Prepara la salsa.']);
    expect(controller.categories.map((category) => category.name),
        containsAll(['Compras', 'Cocina']));
  });

  test('el clasificador solo elimina medidas de condimentos reconocidos', () {
    const classifier = RecipeIngredientClassifier();

    expect(
      classifier.shoppingLabels(
        const RecipeIngredient(text: '2 cucharaditas de comino molido'),
      ),
      const ['Comino'],
    );
    expect(
      classifier.shoppingLabels(
        const RecipeIngredient(text: 'Un trocito de jengibre y cúrcuma'),
      ),
      const ['Jengibre', 'Cúrcuma'],
    );
    expect(
      classifier.shoppingLabels(
        const RecipeIngredient(text: '½ cebolla blanca'),
      ),
      const ['½ cebolla blanca'],
    );
    expect(
      classifier.shoppingLabels(
        const RecipeIngredient(text: '2 dientes de ajo'),
      ),
      const ['2 dientes de ajo'],
    );
    expect(
      classifier.shoppingLabels(
        const RecipeIngredient(text: 'Salmón'),
      ),
      const ['Salmón'],
    );
  });

  test('el importador interpreta una receta schema.org', () {
    final imported = RecipeImportService().importJson(jsonEncode({
      '@context': 'https://schema.org',
      '@type': 'Recipe',
      'name': 'Tortilla española',
      'description': '<p>Una receta sencilla.</p>',
      'prepTime': 'PT15M',
      'cookTime': 'PT30M',
      'recipeYield': '4 raciones',
      'recipeCategory': 'Cena',
      'recipeCuisine': 'Española',
      'recipeIngredient': ['5 huevos', '700 g de papas'],
      'recipeInstructions': [
        {'@type': 'HowToStep', 'text': 'Fríe las papas.'},
        {'@type': 'HowToStep', 'text': 'Cuaja la tortilla.'},
      ],
      'keywords': 'fácil, tradicional',
      'image': {'url': 'https://example.com/tortilla.jpg'},
    }));

    expect(imported.title, 'Tortilla española');
    expect(imported.prepMinutes, 15);
    expect(imported.cookMinutes, 30);
    expect(imported.servings, 4);
    expect(imported.ingredients, hasLength(2));
    expect(imported.instructions.last, 'Cuaja la tortilla.');
    expect(imported.tags, contains('tradicional'));
  });

  test('el servicio guarda la imagen y su miniatura', () async {
    final temp = await Directory.systemTemp.createTemp('todo-recipes-test-');
    addTearDown(() => temp.delete(recursive: true));
    final source = File('${temp.path}${Platform.pathSeparator}plato.png');
    final picture = img.Image(width: 800, height: 500);
    img.fill(picture, color: img.ColorRgb8(180, 90, 40));
    await source.writeAsBytes(img.encodePng(picture));
    final service = RecipeAssetService(
      rootOverride: Directory('${temp.path}${Platform.pathSeparator}recipes'),
    );

    final imported = await service.importImage('plato-1', source.path);
    final pasted = await service.importImageBytes(
      'plato-pegado',
      Uint8List.fromList(img.encodePng(picture)),
    );

    expect(File(await service.absolutePath(imported.imagePath)).existsSync(),
        isTrue);
    expect(
      File(await service.absolutePath(imported.thumbnailPath)).existsSync(),
      isTrue,
    );
    expect(File(await service.absolutePath(pasted.imagePath)).existsSync(),
        isTrue);
  });

  testWidgets('Recetas muestra el catálogo visual y sus filtros',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    final potaje = controller.createRecipe(
      title: 'Potaje de berros',
      category: 'Cuchara',
      cuisine: 'Canaria',
      servings: 6,
      prepMinutes: 20,
      cookMinutes: 60,
      ingredients: const [RecipeIngredient(text: '1 manojo de berros')],
      instructions: const ['Cuece todos los ingredientes.'],
    );
    final weeklyRecipes = <Recipe>[
      potaje,
      for (var index = 2; index <= 7; index++)
        controller.createRecipe(
          title: 'Plato $index',
          category: 'Comida',
          servings: 2,
          ingredients: [RecipeIngredient(text: 'Ingrediente $index')],
        ),
    ];
    final weeklyMenu = controller.createWeeklyMenu(
      title: 'Menú semanal 01',
      totalPriceCents: 2200,
      recipeIds: weeklyRecipes.map((recipe) => recipe.id).toList(),
      shoppingItems: const [
        WeeklyMenuShoppingItem(name: 'Berros', group: 'Frutas y verduras'),
      ],
    );
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(body: RecipesPage(controller: controller)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Recetas'), findsNWidgets(2));
    expect(find.text('Añadir receta'), findsOneWidget);
    expect(find.text('Potaje de berros'), findsOneWidget);
    expect(find.text('Todo (7)'), findsOneWidget);
    expect(find.text('Favoritos (0)'), findsOneWidget);
    expect(find.text('Cuchara (1)'), findsOneWidget);
    expect(find.text('Menús semanales'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('recipes-search')),
      'Canaria',
    );
    await tester.pump();
    expect(find.text('Potaje de berros'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Potaje de berros'));
    await tester.pumpAndSettle();
    expect(find.text('Ficha de receta'), findsOneWidget);
    expect(find.text('Crear compra'), findsOneWidget);
    expect(find.text('Planificar cocina'), findsOneWidget);
    expect(find.text('Editar receta'), findsOneWidget);
    expect(find.byKey(const ValueKey('recipe-detail-more')), findsOneWidget);

    await tester.tap(find.text('Editar receta'));
    await tester.pumpAndSettle();
    expect(find.text('Editar receta'), findsOneWidget);
    expect(find.text('Información básica'), findsOneWidget);
    expect(find.text('Tiempo y raciones'), findsOneWidget);
    expect(find.text('Ingredientes y preparación'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('recipe-editor-category')), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Menús semanales'));
    await tester.pumpAndSettle();
    expect(find.text('Menú semanal 01'), findsOneWidget);
    for (final recipe in weeklyRecipes) {
      expect(
        find.byKey(
          ValueKey('weekly-menu-recipe-${weeklyMenu.id}-${recipe.id}'),
        ),
        findsOneWidget,
      );
    }

    await tester.tap(
      find.byKey(
        ValueKey('weekly-menu-recipe-${weeklyMenu.id}-${potaje.id}'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ficha de receta'), findsOneWidget);
    expect(find.text('Planificación semanal'), findsNothing);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey('weekly-menu-cover-${weeklyMenu.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Toda la semana'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('recipe-section-count-Elige qué vas a comprar'),
      ),
      findsNothing,
    );
    expect(find.text('Comprar semana completa'), findsOneWidget);

    await tester.tap(find.text('Editar semana'));
    await tester.pumpAndSettle();
    expect(find.text('Editar planificación semanal'), findsOneWidget);
    expect(find.text('Desayuno'), findsOneWidget);
    expect(find.text('Comida'), findsWidgets);
    expect(find.text('Merienda'), findsOneWidget);
    expect(find.text('Cena'), findsOneWidget);
  });

  testWidgets(
      'las tarjetas mantienen imagen y metadatos alineados con títulos de dos líneas',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    final short = controller.createRecipe(
      title: 'Arroz negro',
      category: 'Comida',
      prepMinutes: 30,
      ingredients: const [RecipeIngredient(text: 'Arroz')],
    );
    final long = controller.createRecipe(
      title: 'Albóndigas con salsa de zanahoria y curry',
      category: 'Comida',
      prepMinutes: 40,
      ingredients: const [
        RecipeIngredient(text: 'Albóndigas'),
        RecipeIngredient(text: 'Zanahoria'),
      ],
    );
    tester.view.physicalSize = const Size(1000, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(body: RecipesPage(controller: controller)),
    ));
    await tester.pumpAndSettle();

    final shortImage = tester.getRect(
      find.byKey(ValueKey('recipe-card-image-${short.id}')),
    );
    final longImage = tester.getRect(
      find.byKey(ValueKey('recipe-card-image-${long.id}')),
    );
    final shortMetadata = tester.getRect(
      find.byKey(ValueKey('recipe-card-metadata-${short.id}')),
    );
    final longMetadata = tester.getRect(
      find.byKey(ValueKey('recipe-card-metadata-${long.id}')),
    );

    expect(shortImage.height, closeTo(longImage.height, .1));
    expect(shortImage.bottom, closeTo(longImage.bottom, .1));
    expect(shortMetadata.top, closeTo(longMetadata.top, .1));
    await tester.pump(const Duration(milliseconds: 300));
  });
}
