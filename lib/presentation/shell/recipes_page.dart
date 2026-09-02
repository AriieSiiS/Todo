part of 'app_shell.dart';

enum _RecipesArea { recipes, weeklyMenus }

class RecipesPage extends StatefulWidget {
  const RecipesPage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  String _query = '';
  String _category = 'Todas';
  bool _favoritesOnly = false;
  bool _importing = false;
  _RecipesArea _area = _RecipesArea.recipes;

  TodoWorkspace get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final active =
        controller.recipes.where((recipe) => !recipe.archived).toList();
    final weeklyMenus = controller.weeklyMenus
        .where((menu) => !menu.archived)
        .toList()
      ..sort((left, right) => right.title.compareTo(left.title));
    final categories = active
        .map((recipe) => recipe.category.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    categories.insert(0, 'Todas');
    final selectedCategory =
        categories.contains(_category) ? _category : 'Todas';
    final query = _query.trim().toLowerCase();
    final recipes = active.where((recipe) {
      if (_favoritesOnly && !recipe.favorite) return false;
      if (selectedCategory != 'Todas' && recipe.category != selectedCategory) {
        return false;
      }
      if (query.isEmpty) return true;
      return <String>[
        recipe.title,
        recipe.description,
        recipe.category,
        recipe.cuisine,
        ...recipe.tags,
        ...recipe.ingredients.map((ingredient) => ingredient.text),
      ].join(' ').toLowerCase().contains(query);
    }).toList()
      ..sort((left, right) {
        if (left.favorite != right.favorite) return left.favorite ? -1 : 1;
        return left.title.toLowerCase().compareTo(right.title.toLowerCase());
      });
    final favoriteCount = active.where((recipe) => recipe.favorite).length;
    final averageMinutes = active.isEmpty
        ? 0
        : active.fold<int>(0, (sum, recipe) => sum + recipe.totalMinutes) ~/
            active.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recetas',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      _area == _RecipesArea.recipes
                          ? '${active.length} ${active.length == 1 ? 'receta' : 'recetas'} · '
                              '$favoriteCount ${favoriteCount == 1 ? 'favorita' : 'favoritas'}'
                          : '${weeklyMenus.length} '
                              '${weeklyMenus.length == 1 ? 'menú planificado' : 'menús planificados'}',
                      style: TextStyle(color: context.visuals.textMuted),
                    ),
                  ],
                ),
              ),
              if (_area == _RecipesArea.recipes)
                PopupMenuButton<String>(
                  enabled: !_importing,
                  tooltip: 'Importar receta',
                  onSelected: (value) {
                    if (value == 'url') {
                      _importFromUrl();
                    } else {
                      _importFromFile();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'url',
                      child: ListTile(
                        leading: Icon(Icons.link_rounded),
                        title: Text('Desde una dirección web'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'file',
                      child: ListTile(
                        leading: Icon(Icons.data_object_rounded),
                        title: Text('Desde un archivo JSON'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.visuals.pageBorder),
                      borderRadius: BorderRadius.circular(
                        context.visuals.isPhantom ? 0 : 20,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_importing)
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(Icons.file_download_outlined, size: 19),
                        const SizedBox(width: 8),
                        const Text('Importar'),
                      ],
                    ),
                  ),
                ),
              if (_area == _RecipesArea.recipes) ...[
                const SizedBox(width: 9),
                FilledButton.icon(
                  onPressed: () => _showRecipeEditor(context, controller),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nueva receta'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SegmentedButton<_RecipesArea>(
            key: const ValueKey('recipes-area-selector'),
            segments: [
              ButtonSegment(
                value: _RecipesArea.recipes,
                icon: const Icon(Icons.menu_book_rounded),
                label: Text('Recetas (${active.length})'),
              ),
              ButtonSegment(
                value: _RecipesArea.weeklyMenus,
                icon: const Icon(Icons.calendar_view_week_rounded),
                label: Text('Menús semanales (${weeklyMenus.length})'),
              ),
            ],
            selected: <_RecipesArea>{_area},
            onSelectionChanged: (selection) =>
                setState(() => _area = selection.first),
          ),
          const SizedBox(height: 16),
          if (_area == _RecipesArea.weeklyMenus)
            Expanded(
              child: _WeeklyMenusCatalog(
                controller: controller,
                menus: weeklyMenus,
                onOpenRecipe: _openRecipe,
                onCreateShoppingTask: (menu, selectedEntryIds) => _createTask(
                  () => controller.createWeeklyMenuShoppingTask(
                    menu.id,
                    selectedEntryIds: selectedEntryIds,
                  ),
                ),
              ),
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _RecipeSummaryChip(
                  icon: Icons.menu_book_rounded,
                  label: '${active.length} guardadas',
                ),
                _RecipeSummaryChip(
                  icon: Icons.favorite_rounded,
                  label: '$favoriteCount favoritas',
                ),
                _RecipeSummaryChip(
                  icon: Icons.schedule_rounded,
                  label: averageMinutes == 0
                      ? 'Tiempo por completar'
                      : '$averageMinutes min de media',
                ),
                _RecipeSummaryChip(
                  icon: Icons.shopping_cart_outlined,
                  label: 'Ingredientes → tareas',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('recipes-search'),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      labelText: 'Buscar recetas',
                      hintText: 'Pasta, vegetariana, tomate, cena…',
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                const SizedBox(width: 10),
                FilterChip(
                  avatar: const Icon(Icons.favorite_rounded, size: 17),
                  label: const Text('Solo favoritas'),
                  selected: _favoritesOnly,
                  onSelected: (value) => setState(() => _favoritesOnly = value),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final value = categories[index];
                  final count = value == 'Todas'
                      ? active.length
                      : active
                          .where((recipe) => recipe.category == value)
                          .length;
                  return FilterChip(
                    label: Text('$value ($count)'),
                    selected: selectedCategory == value,
                    onSelected: (_) => setState(() => _category = value),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: recipes.isEmpty
                  ? _RecipesEmpty(filtered: active.isNotEmpty)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns =
                            max(2, (constraints.maxWidth / 285).floor());
                        return GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            childAspectRatio: .82,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: recipes.length,
                          itemBuilder: (context, index) => _RecipeCard(
                            controller: controller,
                            recipe: recipes[index],
                            onOpen: () => _openRecipe(recipes[index]),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openRecipe(Recipe recipe) async {
    final action = await _showRecipeDetail(context, controller, recipe);
    if (!mounted) return;
    if (action == 'edit') {
      await _showRecipeEditor(context, controller, recipe: recipe);
    } else if (action == 'shopping') {
      _createTask(() => controller.createRecipeShoppingTask(recipe.id));
    } else if (action == 'cooking') {
      _createTask(() => controller.createRecipeCookingTask(recipe.id));
    } else if (action == 'archive') {
      controller.archiveRecipe(recipe.id);
    }
  }

  void _createTask(TaskModel Function() create) {
    try {
      final task = create();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Tarea creada: ${task.title}'),
        action: SnackBarAction(
          label: 'Ver en Hoy',
          onPressed: () => controller.setSection(AppSection.today),
        ),
      ));
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _importFromFile() async {
    final selected = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Receta JSON', extensions: ['json']),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() => _importing = true);
    try {
      final recipe = controller
          .importRecipeFromJson(await File(selected.path).readAsString());
      if (mounted) _showImported(recipe);
    } catch (error) {
      if (mounted) _showImportError(error);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _importFromUrl() async {
    final field = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importar receta de internet'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: field,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Dirección de la receta',
              hintText: 'https://…',
              helperText:
                  'La página debe publicar datos de receta compatibles con schema.org.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, field.text.trim()),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    field.dispose();
    if (value == null || value.isEmpty || !mounted) return;
    setState(() => _importing = true);
    try {
      final recipe = await controller.importRecipeFromUrl(value);
      if (mounted) _showImported(recipe);
    } catch (error) {
      if (mounted) _showImportError(error);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showImported(Recipe recipe) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('«${recipe.title}» se ha importado correctamente.')),
    );
  }

  void _showImportError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'No se pudo importar la receta: '
        '${error.toString().replaceFirst('FormatException: ', '')}',
      ),
    ));
  }
}

class _RecipeSummaryChip extends StatelessWidget {
  const _RecipeSummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: context.visuals.panelAlt,
          borderRadius:
              BorderRadius.circular(context.visuals.isPhantom ? 0 : 16),
          border: Border.all(color: context.visuals.pageBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: context.visuals.accent),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _WeeklyMenusCatalog extends StatelessWidget {
  const _WeeklyMenusCatalog({
    required this.controller,
    required this.menus,
    required this.onOpenRecipe,
    required this.onCreateShoppingTask,
  });

  final TodoWorkspace controller;
  final List<WeeklyMenu> menus;
  final Future<void> Function(Recipe recipe) onOpenRecipe;
  final void Function(WeeklyMenu menu, List<String> selectedEntryIds)
      onCreateShoppingTask;

  @override
  Widget build(BuildContext context) {
    if (menus.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_view_week_outlined,
                size: 58, color: context.visuals.textMuted),
            const SizedBox(height: 12),
            Text('Todavía no hay menús semanales',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Aquí aparecerán las semanas completas, separadas de las recetas individuales.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.visuals.textMuted),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = max(1, (constraints.maxWidth / 360).floor());
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: 1.08,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: menus.length,
          itemBuilder: (context, index) {
            final menu = menus[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('weekly-menu-${menu.id}'),
                onTap: () => _showWeeklyMenuDetail(
                  context,
                  controller,
                  menu,
                  onOpenRecipe: onOpenRecipe,
                  onCreateShoppingTask: onCreateShoppingTask,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _WeeklyMenuImage(
                            controller: controller,
                            menu: menu,
                          ),
                          const Positioned(
                            left: 10,
                            top: 10,
                            child: _RecipeImageBadge(label: 'Menú semanal'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            menu.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              const Icon(Icons.restaurant_rounded, size: 17),
                              const SizedBox(width: 5),
                              Text('${menu.allRecipeIds.length} recetas'),
                              const Spacer(),
                              const Icon(Icons.person_outline_rounded,
                                  size: 17),
                              const SizedBox(width: 4),
                              Text('${menu.people}'),
                              if (menu.totalPriceCents > 0) ...[
                                const SizedBox(width: 12),
                                Text(
                                  _weeklyMenuPrice(menu.totalPriceCents),
                                  style: TextStyle(
                                    color: context.visuals.accent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _WeeklyMenuImage extends StatelessWidget {
  const _WeeklyMenuImage({
    required this.controller,
    required this.menu,
    this.thumbnail = true,
  });

  final TodoWorkspace controller;
  final WeeklyMenu menu;
  final bool thumbnail;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFF1E7D9),
        child: FutureBuilder<String>(
          future: controller.weeklyMenuImageAbsolutePath(
            menu,
            thumbnail: thumbnail,
          ),
          builder: (context, snapshot) {
            final path = snapshot.data ?? '';
            if (path.isNotEmpty && File(path).existsSync()) {
              return Image.file(File(path), fit: BoxFit.cover);
            }
            if (menu.imageSourceUrl.isNotEmpty) {
              return Image.network(
                menu.imageSourceUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _MissingRecipeImage(),
              );
            }
            return const _MissingRecipeImage();
          },
        ),
      );
}

Future<void> _showWeeklyMenuDetail(
  BuildContext context,
  TodoWorkspace controller,
  WeeklyMenu initialMenu, {
  required Future<void> Function(Recipe recipe) onOpenRecipe,
  required void Function(WeeklyMenu menu, List<String> selectedEntryIds)
      onCreateShoppingTask,
}) async {
  var menu = controller.weeklyMenuById(initialMenu.id) ?? initialMenu;
  final selectedEntryIds = menu.mealEntries.map((entry) => entry.id).toSet();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        menu = controller.weeklyMenuById(initialMenu.id) ?? menu;
        final entries = menu.mealEntries
            .where((entry) => controller.recipeById(entry.recipeId) != null)
            .toList();
        selectedEntryIds.retainWhere(
          (id) => entries.any((entry) => entry.id == id),
        );
        final completeSelection =
            entries.isNotEmpty && selectedEntryIds.length == entries.length;
        final curatedSelection = controller.weeklyMenuSelectionUsesCuratedList(
          menu.id,
          selectedEntryIds,
        );
        final shoppingItems = controller.weeklyMenuShoppingItemsForSelection(
          menu.id,
          selectedEntryIds,
        );
        final groupedItems = <String, List<WeeklyMenuShoppingItem>>{};
        for (final item in shoppingItems) {
          groupedItems
              .putIfAbsent(
                item.group.trim().isEmpty ? 'Otros' : item.group.trim(),
                () => <WeeklyMenuShoppingItem>[],
              )
              .add(item);
        }

        void toggleEntries(Iterable<WeeklyMenuEntry> target) {
          final targetIds = target.map((entry) => entry.id).toSet();
          final allSelected = targetIds.isNotEmpty &&
              targetIds.every(selectedEntryIds.contains);
          setDialogState(() {
            if (allSelected) {
              selectedEntryIds.removeAll(targetIds);
            } else {
              selectedEntryIds.addAll(targetIds);
            }
          });
        }

        return Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180, maxHeight: 860),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cover = Stack(
                  fit: StackFit.expand,
                  children: [
                    _WeeklyMenuImage(
                      controller: controller,
                      menu: menu,
                      thumbnail: false,
                    ),
                    const Positioned(
                      left: 14,
                      top: 14,
                      child: _RecipeImageBadge(label: 'Menú semanal'),
                    ),
                  ],
                );
                final details = Material(
                  color: context.visuals.panel,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Planificación semanal',
                                  style: TextStyle(
                                      color: context.visuals.textMuted)),
                            ),
                            IconButton(
                              tooltip: 'Cerrar',
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        Text(menu.title,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SoftChip(
                              label: '${entries.length} comidas planificadas',
                              icon: Icons.restaurant_menu_rounded,
                            ),
                            _SoftChip(
                              label:
                                  '${menu.people} ${menu.people == 1 ? 'persona' : 'personas'}',
                              icon: Icons.people_alt_outlined,
                            ),
                            if (menu.totalPriceCents > 0)
                              _SoftChip(
                                label:
                                    'Semana completa: ${_weeklyMenuPrice(menu.totalPriceCents)}',
                                icon: Icons.euro_rounded,
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: ListView(
                            children: [
                              if (menu.description.isNotEmpty) ...[
                                Text(menu.description,
                                    style: const TextStyle(height: 1.45)),
                                const SizedBox(height: 18),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: _RecipeSectionTitle(
                                      icon: Icons.calendar_view_week_rounded,
                                      title: 'Elige qué vas a comprar',
                                      count: selectedEntryIds.length,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      await _showWeeklyMenuPlannerEditor(
                                        context,
                                        controller,
                                        menu,
                                      );
                                      final refreshed =
                                          controller.weeklyMenuById(menu.id);
                                      if (refreshed == null) return;
                                      setDialogState(() {
                                        menu = refreshed;
                                        selectedEntryIds
                                          ..clear()
                                          ..addAll(refreshed.mealEntries
                                              .map((entry) => entry.id));
                                      });
                                    },
                                    icon:
                                        const Icon(Icons.edit_calendar_rounded),
                                    label: const Text('Editar semana'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  FilterChip(
                                    label: const Text('Toda la semana'),
                                    selected: completeSelection,
                                    onSelected: (_) => toggleEntries(entries),
                                  ),
                                  for (final day in WeeklyMenuDay.values)
                                    if (entries
                                        .any((entry) => entry.day == day))
                                      FilterChip(
                                        label: Text(_weeklyDayLabel(day)),
                                        selected: entries
                                            .where((entry) => entry.day == day)
                                            .every((entry) => selectedEntryIds
                                                .contains(entry.id)),
                                        onSelected: (_) => toggleEntries(
                                            entries.where(
                                                (entry) => entry.day == day)),
                                      ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  for (final mealType in WeeklyMealType.values)
                                    if (entries.any(
                                        (entry) => entry.mealType == mealType))
                                      FilterChip(
                                        avatar: Icon(
                                          _weeklyMealIcon(mealType),
                                          size: 16,
                                        ),
                                        label: Text(_weeklyMealLabel(mealType)),
                                        selected: entries
                                            .where((entry) =>
                                                entry.mealType == mealType)
                                            .every((entry) => selectedEntryIds
                                                .contains(entry.id)),
                                        onSelected: (_) => toggleEntries(
                                          entries.where((entry) =>
                                              entry.mealType == mealType),
                                        ),
                                      ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              for (final day in WeeklyMenuDay.values)
                                if (entries
                                    .any((entry) => entry.day == day)) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 8, bottom: 4),
                                    child: Text(
                                      _weeklyDayLabel(day),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  for (final entry in entries
                                      .where((entry) => entry.day == day))
                                    Card(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      child: CheckboxListTile(
                                        value:
                                            selectedEntryIds.contains(entry.id),
                                        onChanged: (_) =>
                                            toggleEntries(<WeeklyMenuEntry>[
                                          entry,
                                        ]),
                                        secondary: IconButton(
                                          tooltip: 'Abrir receta',
                                          icon: const Icon(
                                              Icons.open_in_new_rounded),
                                          onPressed: () {
                                            final recipe = controller
                                                .recipeById(entry.recipeId);
                                            if (recipe == null) return;
                                            Navigator.pop(dialogContext);
                                            onOpenRecipe(recipe);
                                          },
                                        ),
                                        title: Text(controller
                                                .recipeById(entry.recipeId)
                                                ?.title ??
                                            'Receta no disponible'),
                                        subtitle: Text(
                                            _weeklyMealLabel(entry.mealType)),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                      ),
                                    ),
                                ],
                              const SizedBox(height: 18),
                              _RecipeSectionTitle(
                                icon: Icons.shopping_basket_outlined,
                                title: curatedSelection
                                    ? 'Compra consolidada del menú original'
                                    : 'Compra calculada para la selección',
                                count: shoppingItems.length,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                curatedSelection
                                    ? 'Se usa la lista consolidada del menú, con sus precios orientativos.'
                                    : 'Se combinan los ingredientes de las recetas marcadas y se normalizan los condimentos.',
                                style: TextStyle(
                                  color: context.visuals.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (shoppingItems.isEmpty)
                                Text('Marca al menos una comida.',
                                    style: TextStyle(
                                        color: context.visuals.textMuted))
                              else
                                for (final group in groupedItems.entries) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 8, bottom: 6),
                                    child: Text(group.key,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                  ),
                                  for (final item in group.value)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 7),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.circle, size: 6),
                                          const SizedBox(width: 9),
                                          Expanded(child: Text(item.name)),
                                          if (item.priceCents > 0)
                                            Text(
                                              _weeklyMenuPrice(item.priceCents),
                                              style: TextStyle(
                                                  color: context
                                                      .visuals.textMuted),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              if (menu.sourceUrl.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () => launchUrl(
                                    Uri.parse(menu.sourceUrl),
                                    mode: LaunchMode.externalApplication,
                                  ),
                                  icon: const Icon(Icons.open_in_new_rounded),
                                  label: const Text('Abrir menú original'),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed:
                              selectedEntryIds.isEmpty || shoppingItems.isEmpty
                                  ? null
                                  : () {
                                      Navigator.pop(dialogContext);
                                      onCreateShoppingTask(
                                        menu,
                                        selectedEntryIds.toList(),
                                      );
                                    },
                          icon: const Icon(Icons.shopping_cart_rounded),
                          label: Text(completeSelection
                              ? 'Comprar semana completa'
                              : 'Comprar selección (${selectedEntryIds.length})'),
                        ),
                      ],
                    ),
                  ),
                );
                if (constraints.maxWidth < 780) {
                  return Column(
                    children: [
                      SizedBox(
                          height: 220, width: double.infinity, child: cover),
                      Expanded(child: details),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 4, child: cover),
                    Expanded(flex: 6, child: details),
                  ],
                );
              },
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _showWeeklyMenuPlannerEditor(
  BuildContext context,
  TodoWorkspace controller,
  WeeklyMenu initialMenu,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final menu = controller.weeklyMenuById(initialMenu.id) ?? initialMenu;
        return AlertDialog(
          title: const Text('Editar planificación semanal'),
          content: SizedBox(
            width: 760,
            height: 650,
            child: ListView(
              children: [
                Text(
                  'Asigna una receta a cada momento del día. Puedes dejar huecos sin planificar.',
                  style: TextStyle(color: context.visuals.textMuted),
                ),
                const SizedBox(height: 12),
                for (final day in WeeklyMenuDay.values)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ExpansionTile(
                      initiallyExpanded: day == WeeklyMenuDay.monday,
                      title: Text(_weeklyDayLabel(day),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        '${menu.mealEntries.where((entry) => entry.day == day).length} comidas planificadas',
                      ),
                      children: [
                        for (final mealType in WeeklyMealType.values)
                          Builder(builder: (context) {
                            final entry = menu.mealEntries
                                .where((entry) =>
                                    entry.day == day &&
                                    entry.mealType == mealType)
                                .firstOrNull;
                            final recipe = entry == null
                                ? null
                                : controller.recipeById(entry.recipeId);
                            return ListTile(
                              leading: Icon(_weeklyMealIcon(mealType)),
                              title: Text(_weeklyMealLabel(mealType)),
                              subtitle: Text(
                                recipe?.title ?? 'Sin receta asignada',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (recipe != null)
                                    IconButton(
                                      tooltip: 'Quitar',
                                      onPressed: () {
                                        controller.setWeeklyMenuMeal(
                                          menu.id,
                                          day: day,
                                          mealType: mealType,
                                        );
                                        setDialogState(() {});
                                      },
                                      icon: const Icon(Icons.clear_rounded),
                                    ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                              onTap: () async {
                                final selected = await _pickWeeklyMenuRecipe(
                                  context,
                                  controller,
                                  mealType,
                                );
                                if (selected == null) return;
                                controller.setWeeklyMenuMeal(
                                  menu.id,
                                  day: day,
                                  mealType: mealType,
                                  recipeId: selected.id,
                                );
                                setDialogState(() {});
                              },
                            );
                          }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Listo'),
            ),
          ],
        );
      },
    ),
  );
}

Future<Recipe?> _pickWeeklyMenuRecipe(
  BuildContext context,
  TodoWorkspace controller,
  WeeklyMealType mealType,
) {
  var query = '';
  return showDialog<Recipe>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final normalizedQuery = query.trim().toLowerCase();
        final recipes = controller.recipes
            .where((recipe) => !recipe.archived)
            .where((recipe) =>
                normalizedQuery.isEmpty ||
                <String>[
                  recipe.title,
                  recipe.category,
                  ...recipe.tags,
                ].join(' ').toLowerCase().contains(normalizedQuery))
            .toList()
          ..sort((left, right) {
            final leftSuggested = _recipeFitsMeal(left, mealType);
            final rightSuggested = _recipeFitsMeal(right, mealType);
            if (leftSuggested != rightSuggested) return leftSuggested ? -1 : 1;
            return left.title.compareTo(right.title);
          });
        return AlertDialog(
          title: Text('Elegir ${_weeklyMealLabel(mealType).toLowerCase()}'),
          content: SizedBox(
            width: 620,
            height: 560,
            child: Column(
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    labelText: 'Buscar receta',
                  ),
                  onChanged: (value) => setDialogState(() => query = value),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: recipes.length,
                    itemBuilder: (context, index) {
                      final recipe = recipes[index];
                      return ListTile(
                        leading: Icon(_recipeFitsMeal(recipe, mealType)
                            ? Icons.auto_awesome_rounded
                            : Icons.restaurant_menu_rounded),
                        title: Text(recipe.title),
                        subtitle: Text(
                            '${recipe.category} · ${_recipeDuration(recipe)}'),
                        onTap: () => Navigator.pop(dialogContext, recipe),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    ),
  );
}

bool _recipeFitsMeal(Recipe recipe, WeeklyMealType mealType) {
  final category = recipe.category.toLowerCase();
  return switch (mealType) {
    WeeklyMealType.breakfast => category.contains('desayuno'),
    WeeklyMealType.lunch => category.contains('comida'),
    WeeklyMealType.snack =>
      category.contains('snack') || category.contains('postre'),
    WeeklyMealType.dinner => category.contains('cena'),
  };
}

String _weeklyDayLabel(WeeklyMenuDay day) => switch (day) {
      WeeklyMenuDay.monday => 'Lunes',
      WeeklyMenuDay.tuesday => 'Martes',
      WeeklyMenuDay.wednesday => 'Miércoles',
      WeeklyMenuDay.thursday => 'Jueves',
      WeeklyMenuDay.friday => 'Viernes',
      WeeklyMenuDay.saturday => 'Sábado',
      WeeklyMenuDay.sunday => 'Domingo',
    };

String _weeklyMealLabel(WeeklyMealType mealType) => switch (mealType) {
      WeeklyMealType.breakfast => 'Desayuno',
      WeeklyMealType.lunch => 'Comida',
      WeeklyMealType.snack => 'Merienda',
      WeeklyMealType.dinner => 'Cena',
    };

IconData _weeklyMealIcon(WeeklyMealType mealType) => switch (mealType) {
      WeeklyMealType.breakfast => Icons.free_breakfast_rounded,
      WeeklyMealType.lunch => Icons.lunch_dining_rounded,
      WeeklyMealType.snack => Icons.cookie_outlined,
      WeeklyMealType.dinner => Icons.dinner_dining_rounded,
    };

String _weeklyMenuPrice(int cents) =>
    '${(cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2).replaceAll('.', ',')} €';

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.controller,
    required this.recipe,
    required this.onOpen,
  });

  final TodoWorkspace controller;
  final Recipe recipe;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                key: ValueKey('recipe-card-image-${recipe.id}'),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _RecipeImage(controller: controller, recipe: recipe),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _RecipeImageBadge(label: recipe.category),
                    ),
                    Positioned(
                      right: 7,
                      top: 7,
                      child: Material(
                        color: Colors.black.withValues(alpha: .55),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: recipe.favorite
                              ? 'Quitar de favoritas'
                              : 'Marcar como favorita',
                          onPressed: () =>
                              controller.toggleRecipeFavorite(recipe.id),
                          icon: Icon(
                            recipe.favorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: recipe.favorite
                                ? const Color(0xFFFF8A80)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      key: ValueKey('recipe-card-title-${recipe.id}'),
                      height: 40,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          recipe.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      key: ValueKey('recipe-card-metadata-${recipe.id}'),
                      children: [
                        const Icon(Icons.schedule_rounded, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _recipeDuration(recipe),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.people_alt_outlined, size: 16),
                        const SizedBox(width: 4),
                        Text('${recipe.servings}'),
                        const SizedBox(width: 8),
                        Text(
                          '${recipe.ingredients.length} ing.',
                          style: TextStyle(color: context.visuals.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _RecipeImage extends StatelessWidget {
  const _RecipeImage({
    required this.controller,
    required this.recipe,
    this.thumbnail = true,
  });

  final TodoWorkspace controller;
  final Recipe recipe;
  final bool thumbnail;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFF1E7D9),
        child: FutureBuilder<String>(
          future: controller.recipeImageAbsolutePath(
            recipe,
            thumbnail: thumbnail,
          ),
          builder: (context, snapshot) {
            final path = snapshot.data ?? '';
            if (path.isNotEmpty && File(path).existsSync()) {
              return Image.file(File(path), fit: BoxFit.cover);
            }
            if (recipe.imageSourceUrl.isNotEmpty) {
              return Image.network(
                recipe.imageSourceUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _MissingRecipeImage(),
              );
            }
            return const _MissingRecipeImage();
          },
        ),
      );
}

class _RecipeImageBadge extends StatelessWidget {
  const _RecipeImageBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .64),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _MissingRecipeImage extends StatelessWidget {
  const _MissingRecipeImage();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu_rounded,
                size: 52, color: context.visuals.textMuted),
            const SizedBox(height: 8),
            Text('Imagen pendiente',
                style:
                    TextStyle(color: context.visuals.textMuted, fontSize: 12)),
          ],
        ),
      );
}

class _RecipesEmpty extends StatelessWidget {
  const _RecipesEmpty({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                filtered
                    ? Icons.search_off_rounded
                    : Icons.soup_kitchen_outlined,
                size: 56,
                color: context.visuals.textMuted),
            const SizedBox(height: 12),
            Text(
              filtered
                  ? 'No hay recetas con estos filtros'
                  : 'Tu recetario está vacío',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              filtered
                  ? 'Prueba otra categoría, cambia la búsqueda o muestra todas.'
                  : 'Crea una receta o impórtala desde una web o un archivo JSON.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.visuals.textMuted),
            ),
          ],
        ),
      );
}

Future<String?> _showRecipeDetail(
  BuildContext context,
  TodoWorkspace controller,
  Recipe initialRecipe,
) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final recipe = controller.recipeById(initialRecipe.id) ?? initialRecipe;
      return Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 820),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final image = Stack(
                fit: StackFit.expand,
                children: [
                  _RecipeImage(
                    controller: controller,
                    recipe: recipe,
                    thumbnail: false,
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: _RecipeImageBadge(label: recipe.category),
                  ),
                ],
              );
              final details = _RecipeDetailPanel(
                recipe: recipe,
                onClose: () => Navigator.pop(dialogContext),
                onAction: (action) => Navigator.pop(dialogContext, action),
              );
              if (constraints.maxWidth < 780) {
                return Column(
                  children: [
                    SizedBox(height: 260, width: double.infinity, child: image),
                    Expanded(child: details),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 4, child: image),
                  Expanded(flex: 5, child: details),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

class _RecipeDetailPanel extends StatelessWidget {
  const _RecipeDetailPanel({
    required this.recipe,
    required this.onClose,
    required this.onAction,
  });

  final Recipe recipe;
  final VoidCallback onClose;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => Material(
        color: context.visuals.panel,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Ficha de receta',
                        style: TextStyle(color: context.visuals.textMuted)),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(recipe.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SoftChip(
                    label: _recipeDuration(recipe),
                    icon: Icons.schedule_rounded,
                  ),
                  _SoftChip(
                    label:
                        '${recipe.servings} ${recipe.servings == 1 ? 'ración' : 'raciones'}',
                    icon: Icons.people_alt_outlined,
                  ),
                  if (recipe.cuisine.isNotEmpty)
                    _SoftChip(
                      label: recipe.cuisine,
                      icon: Icons.public_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: [
                    if (recipe.description.isNotEmpty) ...[
                      Text(recipe.description,
                          style: const TextStyle(height: 1.45)),
                      const SizedBox(height: 18),
                    ],
                    _RecipeSectionTitle(
                      icon: Icons.shopping_basket_outlined,
                      title: 'Ingredientes',
                      count: recipe.ingredients.length,
                    ),
                    const SizedBox(height: 8),
                    if (recipe.ingredients.any((item) => item.isCondiment))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.spa_outlined,
                              size: 16,
                              color: context.visuals.accent,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'Los condimentos se añadirán a Compras sin la medida de la receta.',
                                style: TextStyle(
                                  color: context.visuals.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (recipe.ingredients.isEmpty)
                      Text('Ingredientes pendientes.',
                          style: TextStyle(color: context.visuals.textMuted))
                    else
                      ...recipe.ingredients.map(
                        (ingredient) => Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 7),
                                child: Icon(Icons.circle, size: 6),
                              ),
                              const SizedBox(width: 9),
                              Expanded(child: Text(ingredient.text)),
                              if (ingredient.isCondiment)
                                Tooltip(
                                  message:
                                      'Condimento · se comprará sin indicar la medida',
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(left: 8, top: 1),
                                    child: Icon(
                                      Icons.spa_outlined,
                                      size: 17,
                                      color: context.visuals.accent,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 17),
                    _RecipeSectionTitle(
                      icon: Icons.format_list_numbered_rounded,
                      title: 'Preparación',
                      count: recipe.instructions.length,
                    ),
                    const SizedBox(height: 8),
                    if (recipe.instructions.isEmpty)
                      Text('Pasos pendientes.',
                          style: TextStyle(color: context.visuals.textMuted))
                    else
                      for (var index = 0;
                          index < recipe.instructions.length;
                          index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: context.visuals.panelAlt,
                                child: Text('${index + 1}',
                                    style: const TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(recipe.instructions[index],
                                    style: const TextStyle(height: 1.4)),
                              ),
                            ],
                          ),
                        ),
                    if (recipe.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: recipe.tags
                            .map((tag) => Chip(label: Text(tag)))
                            .toList(),
                      ),
                    ],
                    if (recipe.sourceUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse(recipe.sourceUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Abrir receta original'),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: recipe.ingredients.isEmpty
                        ? null
                        : () => onAction('shopping'),
                    icon: const Icon(Icons.shopping_cart_rounded),
                    label: const Text('Comprar ingredientes'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => onAction('cooking'),
                    icon: const Icon(Icons.event_available_rounded),
                    label: const Text('Crear tarea de cocina'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onAction('edit'),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Editar'),
                  ),
                  IconButton(
                    tooltip: 'Archivar',
                    onPressed: () => onAction('archive'),
                    icon: const Icon(Icons.archive_outlined),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _RecipeSectionTitle extends StatelessWidget {
  const _RecipeSectionTitle({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: context.visuals.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text('$count', style: TextStyle(color: context.visuals.textMuted)),
        ],
      );
}

Future<void> _showRecipeEditor(
  BuildContext context,
  TodoWorkspace controller, {
  Recipe? recipe,
}) async {
  final current =
      recipe == null ? null : controller.recipeById(recipe.id) ?? recipe;
  final title = TextEditingController(text: current?.title ?? '');
  final category = TextEditingController(text: current?.category ?? '');
  final cuisine = TextEditingController(text: current?.cuisine ?? '');
  final servings = TextEditingController(text: '${current?.servings ?? 2}');
  final prep = TextEditingController(
      text: current == null || current.prepMinutes == 0
          ? ''
          : '${current.prepMinutes}');
  final cook = TextEditingController(
      text: current == null || current.cookMinutes == 0
          ? ''
          : '${current.cookMinutes}');
  final description = TextEditingController(text: current?.description ?? '');
  final ingredients = TextEditingController(
    text: current?.ingredients.map((value) => value.text).join('\n') ?? '',
  );
  final instructions = TextEditingController(
    text: current?.instructions.join('\n') ?? '',
  );
  final tags = TextEditingController(text: current?.tags.join(', ') ?? '');
  final sourceUrl = TextEditingController(text: current?.sourceUrl ?? '');
  XFile? imageFile;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(current == null ? 'Nueva receta' : 'Editar receta'),
        content: SizedBox(
          width: 760,
          height: 700,
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: title,
                      autofocus: true,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(labelText: 'Título'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: category,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        hintText: 'Cena, postre, desayuno…',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cuisine,
                      decoration: const InputDecoration(
                        labelText: 'Cocina',
                        hintText: 'Canaria, italiana, asiática…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: servings,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Raciones'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: prep,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Preparación (min)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: cook,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Cocción (min)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText:
                      'Qué hace especial esta receta o cuándo prepararla…',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ingredients,
                minLines: 5,
                maxLines: 9,
                decoration: const InputDecoration(
                  labelText: 'Ingredientes · uno por línea',
                  hintText:
                      '250 g de pasta\n2 tomates maduros\n1 diente de ajo',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: instructions,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Preparación · un paso por línea',
                  hintText:
                      'Cuece la pasta.\nPrepara la salsa.\nMezcla y sirve.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tags,
                decoration: const InputDecoration(
                  labelText: 'Etiquetas',
                  hintText: 'rápida, vegetariana, para invitados',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sourceUrl,
                decoration: const InputDecoration(
                  labelText: 'Fuente original',
                  hintText: 'https://…',
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await openFile(
                      acceptedTypeGroups: const [
                        XTypeGroup(
                          label: 'Imágenes',
                          extensions: ['png', 'jpg', 'jpeg', 'webp'],
                        ),
                      ],
                    );
                    if (selected != null) {
                      setDialogState(() => imageFile = selected);
                    }
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(imageFile?.name ??
                      (current?.imagePath.isNotEmpty == true
                          ? 'Cambiar imagen'
                          : 'Elegir imagen')),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: title.text.trim().isEmpty
                ? null
                : () => Navigator.pop(dialogContext, true),
            child: Text(current == null ? 'Crear receta' : 'Guardar'),
          ),
        ],
      ),
    ),
  );

  if (result == true && context.mounted) {
    final parsedIngredients = ingredients.text
        .split(RegExp(r'\r?\n'))
        .map((value) => RecipeIngredient(text: value.trim()))
        .where((value) => value.text.isNotEmpty)
        .toList();
    final parsedInstructions = instructions.text
        .split(RegExp(r'\r?\n'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final parsedTags = tags.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final saved = current ??
        controller.createRecipe(
          title: title.text,
          category: category.text,
          cuisine: cuisine.text,
          servings: int.tryParse(servings.text) ?? 1,
          prepMinutes: int.tryParse(prep.text) ?? 0,
          cookMinutes: int.tryParse(cook.text) ?? 0,
          description: description.text,
          ingredients: parsedIngredients,
          instructions: parsedInstructions,
          tags: parsedTags,
          sourceUrl: sourceUrl.text,
        );
    if (current != null) {
      controller.updateRecipe(
        current.id,
        title: title.text,
        category: category.text,
        cuisine: cuisine.text,
        servings: int.tryParse(servings.text) ?? 1,
        prepMinutes: int.tryParse(prep.text) ?? 0,
        cookMinutes: int.tryParse(cook.text) ?? 0,
        description: description.text,
        ingredients: parsedIngredients,
        instructions: parsedInstructions,
        tags: parsedTags,
        sourceUrl: sourceUrl.text,
      );
    }
    if (imageFile != null) {
      try {
        await controller.importRecipeImage(saved.id, imageFile!.path);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo importar la imagen: $error')),
          );
        }
      }
    }
  }

  for (final field in <TextEditingController>[
    title,
    category,
    cuisine,
    servings,
    prep,
    cook,
    description,
    ingredients,
    instructions,
    tags,
    sourceUrl,
  ]) {
    field.dispose();
  }
}

String _recipeDuration(Recipe recipe) {
  if (recipe.totalMinutes <= 0) return 'Tiempo pendiente';
  if (recipe.totalMinutes < 60) return '${recipe.totalMinutes} min';
  final hours = recipe.totalMinutes ~/ 60;
  final minutes = recipe.totalMinutes % 60;
  return minutes == 0 ? '$hours h' : '$hours h $minutes min';
}
