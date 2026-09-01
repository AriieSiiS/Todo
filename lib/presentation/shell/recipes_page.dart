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
                      '${active.length} ${active.length == 1 ? 'receta' : 'recetas'} · '
                      '$favoriteCount ${favoriteCount == 1 ? 'favorita' : 'favoritas'}',
                      style: TextStyle(color: context.visuals.textMuted),
                    ),
                  ],
                ),
              ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
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
              const SizedBox(width: 9),
              FilledButton.icon(
                onPressed: () => _showRecipeEditor(context, controller),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nueva receta'),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                    : active.where((recipe) => recipe.category == value).length;
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
          Text(title, style: Theme.of(context).textTheme.titleMedium),
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
