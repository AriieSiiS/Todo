part of 'app_shell.dart';

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
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: _PageHeader(
                title: 'Recetas',
                subtitle: '',
                compact: true,
                pinTrailingToEdge: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      child: IgnorePointer(
                        child: _HeaderSecondaryButton(
                          label: _importing ? 'Importando…' : 'Importar',
                          icon: Icons.file_download_outlined,
                          onPressed: () {},
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _HeaderActionButton(
                      label: 'Añadir receta',
                      icon: Icons.add_rounded,
                      onPressed: () => _showRecipeEditor(context, controller),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const _SectionTabBar(labels: ['Recetas', 'Menús semanales']),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _recipesCatalog(
                    active: active,
                    categories: categories,
                    selectedCategory: selectedCategory,
                    recipes: recipes,
                    favoriteCount: favoriteCount,
                  ),
                  _WeeklyMenusCatalog(
                    controller: controller,
                    menus: weeklyMenus,
                    onOpenRecipe: _openRecipe,
                    onCreateShoppingTask: (menu, selectedEntryIds) =>
                        _createTask(
                      () => controller.createWeeklyMenuShoppingTask(
                        menu.id,
                        selectedEntryIds: selectedEntryIds,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recipesCatalog({
    required List<Recipe> active,
    required List<String> categories,
    required String selectedCategory,
    required List<Recipe> recipes,
    required int favoriteCount,
  }) {
    return Column(
      children: [
        _CatalogSearchField(
          key: const ValueKey('recipes-search'),
          label: 'Buscar recetas',
          hint: 'Pasta, vegetariana, tomate, cena…',
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            key: const ValueKey('recipes-category-filters'),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _FilterPill(
                  label: 'Todo (${active.length})',
                  selected: selectedCategory == 'Todas' && !_favoritesOnly,
                  onTap: () => setState(() {
                    _category = 'Todas';
                    _favoritesOnly = false;
                  }),
                );
              }
              if (index == 1) {
                return _FilterPill(
                  key: const ValueKey('recipes-favorites-filter'),
                  label: 'Favoritos ($favoriteCount)',
                  icon: Icons.favorite_rounded,
                  selected: _favoritesOnly,
                  onTap: () => setState(() {
                    _category = 'Todas';
                    _favoritesOnly = true;
                  }),
                );
              }
              final value = categories[index - 1];
              final count =
                  active.where((recipe) => recipe.category == value).length;
              return _FilterPill(
                label: '$value ($count)',
                selected: selectedCategory == value && !_favoritesOnly,
                onTap: () => setState(() {
                  _category = value;
                  _favoritesOnly = false;
                }),
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
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
        final columns = min(4, max(1, (constraints.maxWidth / 280).floor()));
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 920,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: menus.length,
          itemBuilder: (context, index) {
            final menu = menus[index];
            final recipes =
                controller.recipesForWeeklyMenu(menu).take(7).toList();
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
                    SizedBox(
                      key: ValueKey('weekly-menu-cover-${menu.id}'),
                      height: 250,
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
                    Divider(height: 1, color: context.visuals.pageBorder),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu_rounded,
                            size: 18,
                            color: context.visuals.accent,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Platos de la semana',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: recipes.isEmpty
                            ? Center(
                                child: Text(
                                  'No hay recetas enlazadas.',
                                  style: TextStyle(
                                    color: context.visuals.textMuted,
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  for (var recipeIndex = 0;
                                      recipeIndex < recipes.length;
                                      recipeIndex++) ...[
                                    if (recipeIndex > 0)
                                      const SizedBox(height: 7),
                                    Expanded(
                                      child: _WeeklyMenuRecipeRow(
                                        menu: menu,
                                        controller: controller,
                                        recipe: recipes[recipeIndex],
                                        onOpen: () =>
                                            onOpenRecipe(recipes[recipeIndex]),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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

class _WeeklyMenuRecipeRow extends StatelessWidget {
  const _WeeklyMenuRecipeRow({
    required this.menu,
    required this.controller,
    required this.recipe,
    required this.onOpen,
  });

  final WeeklyMenu menu;
  final TodoWorkspace controller;
  final Recipe recipe;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.visuals.pageBorder),
      ),
      child: Material(
        color: context.visuals.panelAlt,
        child: InkWell(
          key: ValueKey('weekly-menu-recipe-${menu.id}-${recipe.id}'),
          mouseCursor: SystemMouseCursors.click,
          hoverColor: context.visuals.accent.withValues(alpha: .08),
          onTap: onOpen,
          child: Row(
            children: [
              AspectRatio(
                aspectRatio: 1.15,
                child: _WeeklyMenuRecipeThumbnail(
                  controller: controller,
                  recipe: recipe,
                ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${recipe.category} · ${_recipeDuration(recipe)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.visuals.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 9),
                child: Tooltip(
                  message: 'Abrir receta',
                  child: Icon(
                    Icons.arrow_outward_rounded,
                    size: 16,
                    color: context.visuals.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyMenuRecipeThumbnail extends StatelessWidget {
  const _WeeklyMenuRecipeThumbnail({
    required this.controller,
    required this.recipe,
  });

  final TodoWorkspace controller;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFFF1E7D9),
      child: Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: 25,
          color: context.visuals.textMuted,
        ),
      ),
    );
    return FutureBuilder<String>(
      future: controller.recipeImageAbsolutePath(recipe),
      builder: (context, snapshot) {
        final path = snapshot.data ?? '';
        if (path.isNotEmpty && File(path).existsSync()) {
          return Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          );
        }
        if (recipe.imageSourceUrl.isNotEmpty) {
          return Image.network(
            recipe.imageSourceUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          );
        }
        return fallback;
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
                  PopupMenuButton<String>(
                    key: const ValueKey('recipe-detail-more'),
                    tooltip: 'Más opciones',
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: onAction,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined),
                            SizedBox(width: 10),
                            Text('Archivar receta'),
                          ],
                        ),
                      ),
                    ],
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
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: recipe.ingredients.isEmpty
                          ? null
                          : () => onAction('shopping'),
                      icon: const Icon(Icons.shopping_cart_rounded),
                      label: const Text('Crear compra'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => onAction('cooking'),
                      icon: const Icon(Icons.event_available_rounded),
                      label: const Text('Planificar cocina'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => onAction('edit'),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar receta'),
                ),
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
    this.count,
  });

  final IconData icon;
  final String title;
  final int? count;

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
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              '$count',
              key: ValueKey('recipe-section-count-$title'),
              style: TextStyle(color: context.visuals.textMuted),
            ),
          ],
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
      builder: (context, setDialogState) => _RecipeEditorDialog(
        controller: controller,
        current: current,
        title: title,
        category: category,
        cuisine: cuisine,
        servings: servings,
        prep: prep,
        cook: cook,
        description: description,
        ingredients: ingredients,
        instructions: instructions,
        tags: tags,
        sourceUrl: sourceUrl,
        imageFile: imageFile,
        onTitleChanged: () => setDialogState(() {}),
        onSelectImage: () async {
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
        onCancel: () => Navigator.pop(dialogContext, false),
        onSave: () => Navigator.pop(dialogContext, true),
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 250));

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

class _RecipeEditorDialog extends StatelessWidget {
  const _RecipeEditorDialog({
    required this.controller,
    required this.current,
    required this.title,
    required this.category,
    required this.cuisine,
    required this.servings,
    required this.prep,
    required this.cook,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.tags,
    required this.sourceUrl,
    required this.imageFile,
    required this.onTitleChanged,
    required this.onSelectImage,
    required this.onCancel,
    required this.onSave,
  });

  final TodoWorkspace controller;
  final Recipe? current;
  final TextEditingController title;
  final TextEditingController category;
  final TextEditingController cuisine;
  final TextEditingController servings;
  final TextEditingController prep;
  final TextEditingController cook;
  final TextEditingController description;
  final TextEditingController ingredients;
  final TextEditingController instructions;
  final TextEditingController tags;
  final TextEditingController sourceUrl;
  final XFile? imageFile;
  final VoidCallback onTitleChanged;
  final Future<void> Function() onSelectImage;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  bool get editing => current != null;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 820),
        child: Material(
          color: visuals.panel,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 22, 18, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            editing ? 'Editar receta' : 'Nueva receta',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            editing
                                ? 'Actualiza la receta, sus tiempos y todos los pasos.'
                                : 'Guarda ingredientes, preparación e imagen en una sola ficha.',
                            style: TextStyle(color: visuals.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: visuals.pageBorder),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 780) {
                      return Column(
                        children: [
                          SizedBox(height: 240, child: _imagePanel(context)),
                          Divider(height: 1, color: visuals.pageBorder),
                          Expanded(child: _form(context)),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 390, child: _imagePanel(context)),
                        VerticalDivider(width: 1, color: visuals.pageBorder),
                        Expanded(child: _form(context)),
                      ],
                    );
                  },
                ),
              ),
              Divider(height: 1, color: visuals.pageBorder),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 15, 22, 17),
                child: Row(
                  children: [
                    const Spacer(),
                    OutlinedButton(
                      onPressed: onCancel,
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: title.text.trim().isEmpty ? null : onSave,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        editing ? 'Guardar cambios' : 'Crear receta',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePanel(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3EEE5),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: imageFile != null
                    ? Image.file(
                        File(imageFile!.path),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const _MissingRecipeImage(),
                      )
                    : current == null
                        ? const _MissingRecipeImage()
                        : _RecipeImage(
                            controller: controller,
                            recipe: current!,
                            thumbnail: false,
                          ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSelectImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  imageFile?.name ??
                      (current?.imagePath.isNotEmpty == true
                          ? 'Cambiar imagen'
                          : 'Elegir imagen'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final categories = controller.recipes
        .where((recipe) => !recipe.archived)
        .map((recipe) => recipe.category.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (current?.category.trim().isNotEmpty == true) {
      categories.add(current!.category.trim());
    }
    final availableCategories = categories.toList()..sort();
    return ListView(
      key: const ValueKey('recipe-editor-form'),
      padding: const EdgeInsets.all(24),
      children: [
        _sectionTitle(context, 'Información básica'),
        const SizedBox(height: 14),
        TextField(
          controller: title,
          autofocus: true,
          onChanged: (_) => onTitleChanged(),
          decoration: const InputDecoration(labelText: 'Título'),
        ),
        const SizedBox(height: 12),
        _pairedFields(
          editing && availableCategories.contains(category.text)
              ? DropdownButtonFormField<String>(
                  key: const ValueKey('recipe-editor-category'),
                  initialValue: category.text,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: availableCategories
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => category.text = value ?? category.text,
                )
              : TextField(
                  key: const ValueKey('recipe-editor-category'),
                  controller: category,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    hintText: 'Cena, postre, desayuno…',
                  ),
                ),
          TextField(
            controller: cuisine,
            decoration: const InputDecoration(
              labelText: 'Cocina',
              hintText: 'Canaria, italiana, asiática…',
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Descripción',
            hintText: 'Qué hace especial esta receta o cuándo prepararla…',
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle(context, 'Tiempo y raciones'),
        const SizedBox(height: 14),
        _pairedFields(
          TextField(
            controller: servings,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Raciones'),
          ),
          TextField(
            controller: prep,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Preparación (min)'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: cook,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Cocción (min)'),
        ),
        const SizedBox(height: 24),
        _sectionTitle(context, 'Ingredientes y preparación'),
        const SizedBox(height: 14),
        TextField(
          controller: ingredients,
          minLines: 5,
          maxLines: 9,
          decoration: const InputDecoration(
            labelText: 'Ingredientes · uno por línea',
            hintText: '250 g de pasta\n2 tomates maduros\n1 diente de ajo',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: instructions,
          minLines: 5,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: 'Preparación · un paso por línea',
            hintText: 'Cuece la pasta.\nPrepara la salsa.\nMezcla y sirve.',
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle(context, 'Organización y origen'),
        const SizedBox(height: 14),
        TextField(
          controller: tags,
          decoration: const InputDecoration(
            labelText: 'Etiquetas',
            hintText: 'rápida, vegetariana, para invitados',
            helperText: 'Separa varias etiquetas con comas',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: sourceUrl,
          decoration: const InputDecoration(
            labelText: 'Fuente original',
            hintText: 'https://…',
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String value) =>
      Text(value, style: Theme.of(context).textTheme.titleMedium);

  Widget _pairedFields(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [first, const SizedBox(height: 12), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

String _recipeDuration(Recipe recipe) {
  if (recipe.totalMinutes <= 0) return 'Tiempo pendiente';
  if (recipe.totalMinutes < 60) return '${recipe.totalMinutes} min';
  final hours = recipe.totalMinutes ~/ 60;
  final minutes = recipe.totalMinutes % 60;
  return minutes == 0 ? '$hours h' : '$hours h $minutes min';
}
