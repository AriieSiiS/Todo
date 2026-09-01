import 'dart:convert';
import 'dart:io';

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
    expect(decoded.section, AppSection.recipes);
    expect(legacy.recipes, isEmpty);
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

    expect(File(await service.absolutePath(imported.imagePath)).existsSync(),
        isTrue);
    expect(
      File(await service.absolutePath(imported.thumbnailPath)).existsSync(),
      isTrue,
    );
  });

  testWidgets('Recetas muestra el catálogo visual y sus filtros',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    controller.createRecipe(
      title: 'Potaje de berros',
      category: 'Cuchara',
      cuisine: 'Canaria',
      servings: 6,
      prepMinutes: 20,
      cookMinutes: 60,
      ingredients: const [RecipeIngredient(text: '1 manojo de berros')],
      instructions: const ['Cuece todos los ingredientes.'],
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

    expect(find.text('Recetas'), findsOneWidget);
    expect(find.text('Nueva receta'), findsOneWidget);
    expect(find.text('Potaje de berros'), findsOneWidget);
    expect(find.text('Cuchara (1)'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('recipes-search')),
      'Canaria',
    );
    await tester.pump();
    expect(find.text('Potaje de berros'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
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
