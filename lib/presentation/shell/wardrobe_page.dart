part of 'app_shell.dart';

class WardrobePage extends StatefulWidget {
  const WardrobePage({required this.controller, super.key});

  final TodoWorkspace controller;

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  String _query = '';
  final Set<String> _excludedCategories = <String>{};
  bool _favoritesOnly = false;

  TodoWorkspace get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: _PageHeader(
                title: 'Ropa',
                subtitle: '',
                compact: true,
                pinTrailingToEdge: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HeaderSecondaryButton(
                      label: 'Importar',
                      icon: Icons.file_download_outlined,
                      onPressed: () =>
                          _showWardrobeImports(context, controller),
                    ),
                    const SizedBox(width: 10),
                    _HeaderActionButton(
                      label: 'Añadir prenda',
                      icon: Icons.add_rounded,
                      onPressed: () =>
                          _showCreateWardrobeItem(context, controller),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const _SectionTabBar(
              labels: [
                'Armario',
                'Conjuntos',
                'Planificador',
                'Lavandería',
                'Maletas',
                'Estadísticas',
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _wardrobeGrid(),
                  _WardrobeOutfitsTab(controller: controller),
                  _WardrobePlannerTab(controller: controller),
                  _WardrobeLaundryTab(controller: controller),
                  _WardrobePackingTab(controller: controller),
                  _WardrobeStatsTab(controller: controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wardrobeGrid() {
    final categories = controller.wardrobeItems
        .where((item) => !item.archived)
        .map((item) => item.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort(WardrobeTaxonomy.compareCategories);
    final categorySet = categories.toSet();
    final excludedCategories =
        _excludedCategories.where(categorySet.contains).toSet();
    final allCategoriesSelected = excludedCategories.isEmpty;
    final normalizedQuery = _query.trim().toLowerCase();
    final items = controller.wardrobeItems.where((item) {
      if (item.archived) return false;
      if (_favoritesOnly && !item.favorite) return false;
      if (!_favoritesOnly && excludedCategories.contains(item.category)) {
        return false;
      }
      if (normalizedQuery.isEmpty) return true;
      final searchable = <String>[
        item.name,
        item.category,
        item.material,
        ...item.colors,
        ...item.tags,
        ...item.seasons,
        ...item.occasions,
      ].join(' ').toLowerCase();
      return searchable.contains(normalizedQuery);
    }).toList()
      ..sort((left, right) {
        if (left.favorite != right.favorite) return left.favorite ? -1 : 1;
        final categoryOrder = WardrobeTaxonomy.compareCategories(
          left.category,
          right.category,
        );
        if (categoryOrder != 0) return categoryOrder;
        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _CatalogSearchField(
                key: const ValueKey('wardrobe-search'),
                label: 'Buscar en el armario',
                hint: 'Pantalón beige, zapatillas, camiseta granate…',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            key: const ValueKey('wardrobe-category-filters'),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length + 2,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              if (index == 0) {
                final count = controller.wardrobeItems
                    .where((item) => !item.archived)
                    .length;
                return _FilterPill(
                  key: const ValueKey('wardrobe-all-filter'),
                  label: 'Todo ($count)',
                  selected: allCategoriesSelected && !_favoritesOnly,
                  onTap: () => setState(() {
                    if (allCategoriesSelected && !_favoritesOnly) {
                      _excludedCategories
                        ..clear()
                        ..addAll(categories);
                    } else {
                      _excludedCategories.clear();
                    }
                    _favoritesOnly = false;
                  }),
                );
              }
              if (index == 1) {
                final count = controller.wardrobeItems
                    .where((item) => !item.archived && item.favorite)
                    .length;
                return _FilterPill(
                  key: const ValueKey('wardrobe-favorites-filter'),
                  label: 'Favoritos ($count)',
                  icon: Icons.favorite_rounded,
                  selected: _favoritesOnly,
                  onTap: () => setState(() {
                    _favoritesOnly = true;
                  }),
                );
              }
              final value = categories[index - 2];
              final count = controller.wardrobeItems
                  .where((item) => !item.archived && item.category == value)
                  .length;
              return _FilterPill(
                key: ValueKey('wardrobe-category-filter-$value'),
                label: '$value ($count)',
                selected:
                    !excludedCategories.contains(value) && !_favoritesOnly,
                onTap: () => setState(() {
                  _favoritesOnly = false;
                  if (_excludedCategories.contains(value)) {
                    _excludedCategories.remove(value);
                  } else {
                    _excludedCategories.add(value);
                  }
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: items.isEmpty
              ? _WardrobeEmpty(
                  icon: normalizedQuery.isEmpty &&
                          allCategoriesSelected &&
                          !_favoritesOnly
                      ? Icons.checkroom_outlined
                      : Icons.search_off_rounded,
                  title: normalizedQuery.isEmpty &&
                          allCategoriesSelected &&
                          !_favoritesOnly
                      ? 'Tu armario está vacío'
                      : 'No hay prendas con estos filtros',
                  subtitle: normalizedQuery.isEmpty &&
                          allCategoriesSelected &&
                          !_favoritesOnly
                      ? 'Añade una prenda o importa un lote preparado por Codex.'
                      : 'Prueba otra categoría o cambia la búsqueda.',
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        max(2, (constraints.maxWidth / 220).floor());
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        childAspectRatio: .72,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) => _WardrobeItemCard(
                          controller: controller, item: items[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _WardrobeItemCard extends StatelessWidget {
  const _WardrobeItemCard({required this.controller, required this.item});
  final TodoWorkspace controller;
  final WardrobeItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showWardrobeItemDetail(context, controller, item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: const Color(0xFFF3EEE5),
                    child: FutureBuilder<String>(
                      future: controller.wardrobeImageAbsolutePath(item),
                      builder: (context, snapshot) {
                        final path = snapshot.data ?? '';
                        if (path.isEmpty || !File(path).existsSync()) {
                          return const _MissingWardrobeImage();
                        }
                        return Image.file(File(path),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const _MissingWardrobeImage());
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filledTonal(
                      tooltip: item.favorite
                          ? 'Quitar de favoritos'
                          : 'Añadir a favoritos',
                      onPressed: () =>
                          controller.toggleWardrobeFavorite(item.id),
                      icon: Icon(item.favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                      '${item.category} · ${_laundryLabel(item.laundryStatus)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.visuals.textMuted, fontSize: 12)),
                  if (controller.wardrobeDisplaySettings.showUsageCount) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${item.useCount} usos${item.price == null || item.useCount == 0 ? '' : ' · ${(item.price! / item.useCount).toStringAsFixed(2)} €/uso'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WardrobeOutfitsTab extends StatelessWidget {
  const _WardrobeOutfitsTab({required this.controller});
  final TodoWorkspace controller;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
              onPressed: controller.wardrobeItems.isEmpty
                  ? null
                  : () => _showCreateOutfit(context, controller),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo conjunto'))),
      const SizedBox(height: 12),
      Expanded(
          child: controller.wardrobeOutfits.isEmpty
              ? const _WardrobeEmpty(
                  icon: Icons.style_outlined,
                  title: 'Aún no hay conjuntos',
                  subtitle:
                      'Combina varias prendas y guarda tus looks habituales.')
              : LayoutBuilder(builder: (context, constraints) {
                  final columns = max(2, (constraints.maxWidth / 300).floor());
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: .73,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: controller.wardrobeOutfits.length,
                    itemBuilder: (context, index) => _WardrobeOutfitCard(
                      controller: controller,
                      outfit: controller.wardrobeOutfits[index],
                    ),
                  );
                }))
    ]);
  }
}

class _WardrobeOutfitCard extends StatefulWidget {
  const _WardrobeOutfitCard({required this.controller, required this.outfit});
  final TodoWorkspace controller;
  final WardrobeOutfit outfit;

  @override
  State<_WardrobeOutfitCard> createState() => _WardrobeOutfitCardState();
}

class _WardrobeOutfitCardState extends State<_WardrobeOutfitCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final outfit = widget.outfit;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showWardrobeOutfit(context, widget.controller, outfit),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _WardrobeOutfitArtwork(
                  controller: widget.controller, outfit: outfit),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 44, 14, 14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Colors.transparent, Color(0xD9141714)],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(outfit.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17)),
                      const SizedBox(height: 3),
                      Text(
                        '${outfit.itemIds.length} prendas${outfit.occasion.isEmpty ? '' : ' · ${outfit.occasion}'}',
                        style: const TextStyle(color: Color(0xFFD9DDD8)),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: _hovered ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: .16),
                  child: const Center(
                    child: Chip(
                      avatar: Icon(Icons.visibility_outlined, size: 18),
                      label: Text('Ver conjunto'),
                    ),
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

class _WardrobeOutfitArtwork extends StatelessWidget {
  const _WardrobeOutfitArtwork(
      {required this.controller, required this.outfit});
  final TodoWorkspace controller;
  final WardrobeOutfit outfit;

  @override
  Widget build(BuildContext context) {
    if (outfit.renderImagePath.isNotEmpty) {
      return FutureBuilder<String>(
        future: controller.wardrobeOutfitRenderAbsolutePath(outfit),
        builder: (context, snapshot) {
          final path = snapshot.data ?? '';
          if (path.isNotEmpty && File(path).existsSync()) {
            return Image.file(File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _WardrobeOutfitComposition(controller, outfit));
          }
          return _WardrobeOutfitComposition(controller, outfit);
        },
      );
    }
    return _WardrobeOutfitComposition(controller, outfit);
  }
}

class _WardrobeOutfitComposition extends StatelessWidget {
  const _WardrobeOutfitComposition(this.controller, this.outfit);
  final TodoWorkspace controller;
  final WardrobeOutfit outfit;

  @override
  Widget build(BuildContext context) {
    final items = outfit.itemIds
        .map(controller.wardrobeItemById)
        .whereType<WardrobeItem>()
        .toList();
    final upper = items
        .where((item) => _outfitVisualRole(item) == _OutfitVisualRole.upper)
        .toList();
    final lower = items
        .where((item) => _outfitVisualRole(item) == _OutfitVisualRole.lower)
        .toList();
    final footwear = items
        .where((item) => _outfitVisualRole(item) == _OutfitVisualRole.footwear)
        .toList();
    final accessories = items
        .where((item) => _outfitVisualRole(item) == _OutfitVisualRole.accessory)
        .toList();
    final usesShortBottom =
        lower.isNotEmpty && lower.every(_isShortOutfitBottom);
    return ColoredBox(
      color: const Color(0xFFF1EADF),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 82),
        child: Column(
          children: [
            if (upper.isNotEmpty)
              Expanded(
                flex: 7,
                child: _WardrobeOutfitSlot(
                  controller: controller,
                  items: upper,
                  widthFactor: 1,
                ),
              ),
            if (lower.isNotEmpty)
              Expanded(
                flex: usesShortBottom ? 4 : 7,
                child: _WardrobeOutfitSlot(
                  controller: controller,
                  items: lower,
                  widthFactor: usesShortBottom ? .58 : .7,
                ),
              ),
            if (footwear.isNotEmpty)
              Expanded(
                flex: 2,
                child: _WardrobeOutfitSlot(
                  controller: controller,
                  items: footwear,
                  widthFactor: .5,
                ),
              ),
            if (accessories.isNotEmpty)
              Expanded(
                flex: 2,
                child: _WardrobeOutfitSlot(
                  controller: controller,
                  items: accessories,
                  widthFactor: .42,
                ),
              ),
            if (items.isEmpty)
              const Expanded(
                child: Center(child: Icon(Icons.style_outlined, size: 58)),
              ),
          ],
        ),
      ),
    );
  }
}

enum _OutfitVisualRole { upper, lower, footwear, accessory }

_OutfitVisualRole _outfitVisualRole(WardrobeItem item) {
  final value = '${item.category} ${item.name}'.toLowerCase();
  if (<String>[
    'calzado',
    'zapat',
    'zapato',
    'bota',
    'sandalia',
    'mocasín',
    'tenis'
  ].any(value.contains)) {
    return _OutfitVisualRole.footwear;
  }
  if (<String>['pantal', 'short', 'vaquero', 'falda', 'bermuda']
      .any(value.contains)) {
    return _OutfitVisualRole.lower;
  }
  if (<String>[
    'accesorio',
    'cinturón',
    'gorra',
    'sombrero',
    'bolso',
    'mochila',
    'bufanda',
    'corbata',
    'reloj'
  ].any(value.contains)) {
    return _OutfitVisualRole.accessory;
  }
  return _OutfitVisualRole.upper;
}

bool _isShortOutfitBottom(WardrobeItem item) {
  final value = '${item.category} ${item.name}'.toLowerCase();
  return <String>['short', 'pantalón corto', 'pantalones cortos', 'bermuda']
      .any(value.contains);
}

class _WardrobeOutfitSlot extends StatelessWidget {
  const _WardrobeOutfitSlot({
    required this.controller,
    required this.items,
    required this.widthFactor,
  });
  final TodoWorkspace controller;
  final List<WardrobeItem> items;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items
          .take(3)
          .map((item) => Expanded(
                child: FractionallySizedBox(
                  widthFactor: widthFactor,
                  heightFactor: 1,
                  child: FutureBuilder<String>(
                    future: controller.wardrobeImageAbsolutePath(item),
                    builder: (context, snapshot) {
                      final path = snapshot.data ?? '';
                      if (path.isEmpty || !File(path).existsSync()) {
                        return const Icon(Icons.checkroom_outlined, size: 42);
                      }
                      return Image.file(File(path), fit: BoxFit.contain);
                    },
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _WardrobePlannerTab extends StatelessWidget {
  const _WardrobePlannerTab({required this.controller});
  final TodoWorkspace controller;
  @override
  Widget build(BuildContext context) {
    final start =
        DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    return ListView.separated(
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final day = DateTime(start.year, start.month, start.day + index);
          final planned = controller.wardrobePlanEntries
              .where((entry) =>
                  entry.date.year == day.year &&
                  entry.date.month == day.month &&
                  entry.date.day == day.day)
              .firstOrNull;
          return ListTile(
              tileColor: Colors.white.withValues(alpha: .58),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              leading: CircleAvatar(child: Text('${day.day}')),
              title: Text(_wardrobeWeekdayLabel(day.weekday)),
              subtitle: Text(planned == null
                  ? 'Sin conjunto planificado'
                  : '${_weatherLabel(planned.weather)} · ${planned.itemIds.length} prendas${planned.occasion.isEmpty ? '' : ' · ${planned.occasion}'}'),
              trailing: IconButton(
                  icon: const Icon(Icons.edit_calendar_rounded),
                  tooltip: 'Planificar',
                  onPressed: controller.wardrobeItems.isEmpty
                      ? null
                      : () => _showPlanDay(context, controller, day)));
        });
  }
}

class _WardrobeLaundryTab extends StatelessWidget {
  const _WardrobeLaundryTab({required this.controller});
  final TodoWorkspace controller;
  @override
  Widget build(BuildContext context) {
    if (controller.wardrobeItems.isEmpty) {
      return const _WardrobeEmpty(
          icon: Icons.local_laundry_service_outlined,
          title: 'No hay prendas',
          subtitle: 'Las prendas aparecerán aquí para gestionar su lavado.');
    }
    return ListView(
        children: WardrobeLaundryStatus.values.map((status) {
      final items = controller.wardrobeItems
          .where((item) => !item.archived && item.laundryStatus == status)
          .toList();
      return ExpansionTile(
          initiallyExpanded: status != WardrobeLaundryStatus.available,
          title: Text(_laundryLabel(status)),
          subtitle: Text('${items.length} prendas'),
          children: items
              .map((item) => ListTile(
                  title: Text(item.name),
                  subtitle: Text(item.category),
                  trailing: PopupMenuButton<WardrobeLaundryStatus>(
                      tooltip: 'Cambiar estado',
                      onSelected: (value) =>
                          controller.setWardrobeLaundryStatus([item.id], value),
                      itemBuilder: (_) => WardrobeLaundryStatus.values
                          .map((value) => PopupMenuItem(
                              value: value, child: Text(_laundryLabel(value))))
                          .toList())))
              .toList());
    }).toList());
  }
}

class _WardrobePackingTab extends StatelessWidget {
  const _WardrobePackingTab({required this.controller});
  final TodoWorkspace controller;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
              onPressed: () => _showCreatePackingList(context, controller),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva maleta'))),
      const SizedBox(height: 12),
      Expanded(
          child: controller.wardrobePackingLists.isEmpty
              ? const _WardrobeEmpty(
                  icon: Icons.luggage_outlined,
                  title: 'No hay viajes preparados',
                  subtitle:
                      'Crea una maleta y añade las prendas que quieres llevar.')
              : ListView(
                  children: controller.wardrobePackingLists
                      .map((list) => ExpansionTile(
                          title: Text(list.name),
                          subtitle: Text(
                              '${list.startDate.day}/${list.startDate.month} – ${list.endDate.day}/${list.endDate.month} · ${list.entries.where((entry) => entry.packed).length}/${list.entries.length} preparadas'),
                          trailing: IconButton(
                              icon: const Icon(Icons.add_rounded),
                              tooltip: 'Añadir prenda',
                              onPressed: controller.wardrobeItems.isEmpty
                                  ? null
                                  : () => _showAddPackingItem(
                                      context, controller, list)),
                          children: list.entries.map((entry) {
                            final item =
                                controller.wardrobeItemById(entry.itemId);
                            return CheckboxListTile(
                                value: entry.packed,
                                onChanged: (_) =>
                                    controller.toggleWardrobePackingItem(
                                        list.id, entry.itemId),
                                title: Text(item?.name ?? 'Prenda eliminada'),
                                subtitle: Text('Cantidad: ${entry.quantity}'));
                          }).toList()))
                      .toList()))
    ]);
  }
}

class _WardrobeStatsTab extends StatelessWidget {
  const _WardrobeStatsTab({required this.controller});
  final TodoWorkspace controller;
  @override
  Widget build(BuildContext context) {
    final active =
        controller.wardrobeItems.where((item) => !item.archived).toList();
    final totalUses = active.fold<int>(0, (sum, item) => sum + item.useCount);
    final neverUsed = active.where((item) => item.useCount == 0).length;
    final favorites = active.where((item) => item.favorite).length;
    final categories = <String, int>{};
    for (final item in active) {
      categories[item.category] = (categories[item.category] ?? 0) + 1;
    }
    return ListView(children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        _WardrobeMetric(
            label: 'Prendas',
            value: '${active.length}',
            icon: Icons.checkroom_rounded),
        _WardrobeMetric(
            label: 'Usos registrados',
            value: '$totalUses',
            icon: Icons.event_available_rounded),
        _WardrobeMetric(
            label: 'Sin estrenar',
            value: '$neverUsed',
            icon: Icons.new_releases_outlined),
        _WardrobeMetric(
            label: 'Favoritas',
            value: '$favorites',
            icon: Icons.favorite_rounded),
      ]),
      const SizedBox(height: 20),
      Text('Por categoría', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      ...categories.entries.map((entry) =>
          ListTile(title: Text(entry.key), trailing: Text('${entry.value}'))),
    ]);
  }
}

Future<void> _showWardrobeImports(
  BuildContext context,
  TodoWorkspace controller,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: Material(
          color: context.visuals.panel,
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
                            'Importar ropa',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Añade un lote desde una carpeta y revísalo antes de incorporarlo al armario.',
                            style: TextStyle(color: context.visuals.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.visuals.pageBorder),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: _WardrobeImportsTab(controller: controller),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WardrobeImportsTab extends StatelessWidget {
  const _WardrobeImportsTab({required this.controller});
  final TodoWorkspace controller;
  @override
  Widget build(BuildContext context) {
    final pending = controller.wardrobeImportBatches
        .where((batch) => batch.status == WardrobeImportStatus.pending)
        .toList();
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        OutlinedButton.icon(
            onPressed: controller.reloadWardrobeImports,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualizar')),
        const SizedBox(width: 8),
        FilledButton.icon(
            onPressed: () => _importWardrobeDirectory(context, controller),
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('Importar lote desde carpeta')),
      ]),
      const SizedBox(height: 12),
      Expanded(
          child: pending.isEmpty
              ? const _WardrobeEmpty(
                  icon: Icons.inventory_2_outlined,
                  title: 'No hay importaciones pendientes',
                  subtitle:
                      'Cuando Codex prepare un lote, aparecerá aquí para revisarlo.')
              : ListView.separated(
                  itemCount: pending.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _ImportBatchCard(
                      controller: controller, batch: pending[index])))
    ]);
  }
}

class _ImportBatchCard extends StatelessWidget {
  const _ImportBatchCard({required this.controller, required this.batch});
  final TodoWorkspace controller;
  final WardrobeImportBatch batch;
  @override
  Widget build(BuildContext context) {
    final errors = batch.items.where((item) => item.errors.isNotEmpty).length;
    final duplicates =
        batch.items.where((item) => item.duplicateItemId != null).length;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(batch.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(
                          '${batch.items.length} prendas · $errors con errores · $duplicates duplicadas')
                    ])),
                TextButton(
                    onPressed: () => controller.discardWardrobeImport(batch.id),
                    child: const Text('Descartar')),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: errors > 0
                        ? null
                        : () => _approveBatch(context, controller, batch.id),
                    child: const Text('Aprobar lote'))
              ]),
              const Divider(height: 24),
              ...batch.items.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(item.errors.isNotEmpty
                      ? Icons.error_outline_rounded
                      : item.duplicateItemId != null
                          ? Icons.copy_rounded
                          : Icons.check_circle_outline_rounded),
                  title: Text(item.name),
                  subtitle: Text(
                      '${item.category}${item.errors.isEmpty ? '' : ' · ${item.errors.join(' ')}'}${item.duplicateItemId == null ? '' : ' · Duplicado exacto'}'),
                  trailing: IconButton(
                      tooltip: 'Editar metadatos',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showEditImportItem(
                          context, controller, batch, item))))
            ])));
  }
}

class _WardrobeMetric extends StatelessWidget {
  const _WardrobeMetric(
      {required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 210,
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Icon(icon),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  Text(label)
                ])
              ]))));
}

class _WardrobeEmpty extends StatelessWidget {
  const _WardrobeEmpty(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 54, color: context.visuals.textMuted),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.visuals.textMuted))
      ]));
}

class _MissingWardrobeImage extends StatelessWidget {
  const _MissingWardrobeImage();
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.image_not_supported_outlined, size: 38),
            SizedBox(height: 8),
            Text('Imagen no disponible en este dispositivo',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11))
          ])));
}

Future<void> _showCreateWardrobeItem(
    BuildContext context, TodoWorkspace controller) async {
  await showDialog<_WardrobeEditAction>(
    context: context,
    builder: (context) => _WardrobeItemEditorDialog(
      controller: controller,
    ),
  );
}

Future<void> _showWardrobeItemDetail(
    BuildContext context, TodoWorkspace controller, WardrobeItem item) async {
  final action = await showDialog<String>(
    context: context,
    builder: (dialogContext) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final image = ColoredBox(
              color: const Color(0xFFF3EEE5),
              child: FutureBuilder<String>(
                future: controller.wardrobeImageAbsolutePath(
                  item,
                  thumbnail: false,
                ),
                builder: (context, snapshot) {
                  final path = snapshot.data ?? '';
                  if (path.isEmpty || !File(path).existsSync()) {
                    return const _MissingWardrobeImage();
                  }
                  return InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const _MissingWardrobeImage(),
                    ),
                  );
                },
              ),
            );
            final details = _WardrobeItemDetailPanel(
              controller: controller,
              item: item,
              onClose: () => Navigator.pop(dialogContext),
              onEdit: () => Navigator.pop(dialogContext, 'edit'),
            );
            if (compact) {
              return Column(
                children: [
                  SizedBox(height: 390, width: double.infinity, child: image),
                  Expanded(child: details),
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: image),
                SizedBox(width: 350, child: details),
              ],
            );
          },
        ),
      ),
    ),
  );
  if (action == 'edit' && context.mounted) {
    await _showEditWardrobeItem(context, controller, item);
  }
}

class _WardrobeItemDetailPanel extends StatelessWidget {
  const _WardrobeItemDetailPanel({
    required this.controller,
    required this.item,
    required this.onClose,
    required this.onEdit,
  });

  final TodoWorkspace controller;
  final WardrobeItem item;
  final VoidCallback onClose;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final metadata = <({String label, String value})>[
      (label: 'Categoría', value: item.category),
      (label: 'Lavandería', value: _laundryLabel(item.laundryStatus)),
      if (item.material.trim().isNotEmpty)
        (label: 'Material', value: item.material),
      if (item.colors.isNotEmpty)
        (label: 'Colores', value: item.colors.join(', ')),
      if (item.seasons.isNotEmpty)
        (label: 'Temporadas', value: item.seasons.join(', ')),
      if (item.occasions.isNotEmpty)
        (label: 'Ocasiones', value: item.occasions.join(', ')),
      if (controller.wardrobeDisplaySettings.showUsageCount)
        (label: 'Usos', value: '${item.useCount}'),
      if (item.price != null)
        (label: 'Precio', value: '${item.price!.toStringAsFixed(2)} €'),
    ];
    return Material(
      color: context.visuals.panel,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Detalle de prenda',
                    style: TextStyle(color: context.visuals.textMuted),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  ...metadata.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.label,
                                style: TextStyle(
                                    color: context.visuals.textMuted,
                                    fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(entry.value,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                  if (item.tags.isNotEmpty) ...[
                    Text('Etiquetas',
                        style: TextStyle(
                            color: context.visuals.textMuted, fontSize: 12)),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: item.tags
                          .map((tag) => Chip(label: Text(tag)))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: item.favorite
                      ? 'Quitar de favoritos'
                      : 'Añadir a favoritos',
                  onPressed: () {
                    controller.toggleWardrobeFavorite(item.id);
                    Navigator.pop(context);
                  },
                  icon: Icon(item.favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showEditWardrobeItem(
    BuildContext context, TodoWorkspace controller, WardrobeItem item) async {
  final action = await showDialog<_WardrobeEditAction>(
    context: context,
    builder: (context) => _WardrobeItemEditorDialog(
      controller: controller,
      item: item,
    ),
  );
  if (action == _WardrobeEditAction.delete && context.mounted) {
    final confirmed = await _confirm(context, 'Eliminar prenda',
        'Se quitará de conjuntos, planes y maletas. El historial conservará su referencia.');
    if (confirmed) controller.deleteWardrobeItem(item.id);
  }
}

enum _WardrobeEditAction { saved, delete }

class _WardrobeItemEditorDialog extends StatefulWidget {
  const _WardrobeItemEditorDialog({
    required this.controller,
    this.item,
  });

  final TodoWorkspace controller;
  final WardrobeItem? item;

  @override
  State<_WardrobeItemEditorDialog> createState() =>
      _WardrobeItemEditorDialogState();
}

class _WardrobeItemEditorDialogState extends State<_WardrobeItemEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late String _category;
  late String _material;
  late List<String> _colors;
  late List<String> _seasons;
  late List<String> _occasions;
  late List<String> _tags;
  final TextEditingController _tagInput = TextEditingController();
  late final TextEditingController _price;
  late WardrobeLaundryStatus _laundryStatus;
  late bool _favorite;
  XFile? _selectedImage;
  Uint8List? _pastedImageBytes;
  final FocusNode _imagePasteFocus = FocusNode(
    debugLabel: 'Pegar imagen de prenda',
  );
  bool _removeImage = false;
  bool _saving = false;

  WardrobeItem? get item => widget.item;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: item?.name ?? '');
    _category = WardrobeTaxonomy.normalizeCategory(
      item?.category ?? WardrobeTaxonomy.categories.first,
    );
    _material = item?.material ?? '';
    _colors = WardrobeTaxonomy.normalizeColors(item?.colors ?? const []);
    _seasons = WardrobeTaxonomy.normalizeSeasons(item?.seasons ?? const []);
    _occasions =
        WardrobeTaxonomy.normalizeOccasions(item?.occasions ?? const []);
    _tags = List<String>.of(item?.tags ?? const []);
    _price = TextEditingController(text: item?.price?.toString() ?? '');
    _laundryStatus = item?.laundryStatus ?? WardrobeLaundryStatus.available;
    _favorite = item?.favorite ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _tagInput.dispose();
    _price.dispose();
    _imagePasteFocus.dispose();
    super.dispose();
  }

  TextStyle get _normalFieldStyle =>
      Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w400,
          ) ??
      const TextStyle(fontWeight: FontWeight.w400);

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 780),
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
                          Text(item == null ? 'Añadir prenda' : 'Editar prenda',
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 5),
                          Text(
                            item == null
                                ? 'Completa la ficha y añade una imagen si quieres.'
                                : 'Actualiza la ficha completa sin perder de vista la prenda.',
                            style: TextStyle(color: visuals.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: visuals.pageBorder),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    if (compact) {
                      return ListView(
                        children: [
                          SizedBox(height: 280, child: _imagePreview()),
                          _form(),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 380, child: _imagePreview()),
                        VerticalDivider(width: 1, color: visuals.pageBorder),
                        Expanded(child: _form()),
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
                    if (item != null)
                      TextButton.icon(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(
                                  context,
                                  _WardrobeEditAction.delete,
                                ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Eliminar prenda'),
                        style: TextButton.styleFrom(
                          foregroundColor: visuals.danger,
                        ),
                      ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        item == null ? 'Añadir prenda' : 'Guardar cambios',
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

  Widget _imagePreview() {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            _pasteImage,
      },
      child: Focus(
        focusNode: _imagePasteFocus,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _imagePasteFocus.requestFocus,
          child: ColoredBox(
            color: const Color(0xFFF3EEE5),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Expanded(child: _imageContent()),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _saving ? null : _selectImage,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          _selectedImage != null ||
                                  _pastedImageBytes != null ||
                                  (item != null && item!.imagePath.isNotEmpty)
                              ? 'Cambiar imagen'
                              : 'Añadir imagen',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pasteImage,
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('Pegar imagen'),
                      ),
                      if (_selectedImage != null ||
                          _pastedImageBytes != null ||
                          (!_removeImage &&
                              item != null &&
                              item!.imagePath.isNotEmpty))
                        OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => setState(() {
                                    _selectedImage = null;
                                    _pastedImageBytes = null;
                                    _removeImage = true;
                                  }),
                          icon: const Icon(Icons.hide_image_outlined),
                          label: const Text('Quitar imagen'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'También puedes hacer clic aquí y pulsar Ctrl+V.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.visuals.textMuted,
                          fontWeight: FontWeight.w400,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageContent() {
    if (_pastedImageBytes != null) {
      return Image.memory(
        _pastedImageBytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _MissingWardrobeImage(),
      );
    }
    if (_selectedImage != null) {
      return Image.file(
        File(_selectedImage!.path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _MissingWardrobeImage(),
      );
    }
    if (_removeImage || item == null || item!.imagePath.isEmpty) {
      return const _MissingWardrobeImage();
    }
    return FutureBuilder<String>(
      future: widget.controller.wardrobeImageAbsolutePath(
        item!,
        thumbnail: false,
      ),
      builder: (context, snapshot) {
        final path = snapshot.data ?? '';
        if (path.isEmpty || !File(path).existsSync()) {
          return const _MissingWardrobeImage();
        }
        return Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _MissingWardrobeImage(),
        );
      },
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('wardrobe-editor-form'),
        padding: const EdgeInsets.all(24),
        children: [
          Text('Información básica',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          TextFormField(
            controller: _name,
            autofocus: true,
            style: _normalFieldStyle,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: _requiredField,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('wardrobe-editor-category'),
            initialValue: _category,
            style: _normalFieldStyle,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: WardrobeTaxonomy.categoriesWithLegacy(item?.category)
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _category = value ?? _category;
            }),
          ),
          const SizedBox(height: 12),
          _materialField(),
          const SizedBox(height: 22),
          Text('Clasificación', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          _multiChoiceField(
            label: 'Colores',
            options: WardrobeTaxonomy.colors,
            selected: _colors,
            onChanged: (values) => setState(() => _colors = values),
          ),
          const SizedBox(height: 16),
          _multiChoiceField(
            label: 'Temporadas',
            options: WardrobeTaxonomy.seasons,
            selected: _seasons,
            onChanged: (values) => setState(() => _seasons = values),
          ),
          const SizedBox(height: 16),
          _multiChoiceField(
            label: 'Ocasiones',
            options: WardrobeTaxonomy.occasions,
            selected: _occasions,
            onChanged: (values) => setState(() => _occasions = values),
          ),
          const SizedBox(height: 16),
          _tagsField(),
          const SizedBox(height: 22),
          Text('Estado y valor',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          DropdownButtonFormField<WardrobeLaundryStatus>(
            initialValue: _laundryStatus,
            style: _normalFieldStyle,
            decoration: const InputDecoration(labelText: 'Lavandería'),
            items: WardrobeLaundryStatus.values
                .map((value) => DropdownMenuItem(
                      value: value,
                      child: Text(_laundryLabel(value)),
                    ))
                .toList(),
            onChanged: (value) => setState(() {
              _laundryStatus = value ?? WardrobeLaundryStatus.available;
            }),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _price,
            style: _normalFieldStyle,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio',
              suffixText: '€',
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              return double.tryParse(text.replaceAll(',', '.')) == null
                  ? 'Escribe un importe válido'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _favorite,
            onChanged: (value) => setState(() => _favorite = value),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            secondary: const Icon(Icons.favorite_outline_rounded),
            title: const Text(
              'Prenda favorita',
              style: TextStyle(fontWeight: FontWeight.w400),
            ),
            subtitle: const Text(
              'Aparecerá primero y podrá mostrarse con el filtro de favoritas.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _materialField() {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _material),
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return WardrobeTaxonomy.materialSuggestions;
        return WardrobeTaxonomy.materialSuggestions.where(
          (option) => option.toLowerCase().contains(query),
        );
      },
      onSelected: (value) => _material = value,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          style: _normalFieldStyle,
          onChanged: (value) => _material = value,
          onFieldSubmitted: (_) => onSubmitted(),
          decoration: const InputDecoration(
            labelText: 'Material',
            hintText: 'Algodón, cuero, lino…',
          ),
        );
      },
    );
  }

  Widget _multiChoiceField({
    required String label,
    required List<String> options,
    required List<String> selected,
    required ValueChanged<List<String>> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selected.isNotEmpty) ...[
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: selected
                  .map(
                    (value) => InputChip(
                      label: Text(value),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w400),
                      onDeleted: () {
                        final next = List<String>.of(selected)..remove(value);
                        onChanged(next);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
          ],
          TextButton.icon(
            onPressed: () => _showMultiChoiceDialog(
              label: label,
              options: options,
              selected: selected,
              onChanged: onChanged,
            ),
            icon: const Icon(Icons.tune_rounded),
            label: Text('Elegir ${label.toLowerCase()}'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMultiChoiceDialog({
    required String label,
    required List<String> options,
    required List<String> selected,
    required ValueChanged<List<String>> onChanged,
  }) async {
    final draft = List<String>.of(selected);
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Elegir ${label.toLowerCase()}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: options
                    .map(
                      (option) => FilterChip(
                        label: Text(option),
                        labelStyle:
                            const TextStyle(fontWeight: FontWeight.w400),
                        selected: draft.contains(option),
                        onSelected: (value) => setDialogState(() {
                          if (value) {
                            draft.add(option);
                          } else {
                            draft.remove(option);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, draft),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) onChanged(result);
  }

  Widget _tagsField() {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Etiquetas'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_tags.isNotEmpty) ...[
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _tags
                  .map(
                    (tag) => InputChip(
                      label: Text(tag),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w400),
                      onDeleted: () => setState(() => _tags.remove(tag)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagInput,
                  style: _normalFieldStyle,
                  decoration: const InputDecoration(
                    hintText: 'Añadir etiqueta',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              IconButton(
                tooltip: 'Añadir etiqueta',
                onPressed: _addTag,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _requiredField(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Este campo es obligatorio' : null;

  void _addTag() {
    final value = _tagInput.text.trim();
    if (value.isEmpty) return;
    if (!_tags.any((tag) => tag.toLowerCase() == value.toLowerCase())) {
      setState(() => _tags.add(value));
    }
    _tagInput.clear();
  }

  Future<void> _selectImage() async {
    final selected = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Imágenes',
          extensions: ['png', 'jpg', 'jpeg', 'webp'],
        ),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedImage = selected;
      _pastedImageBytes = null;
      _removeImage = false;
    });
  }

  Future<void> _pasteImage() async {
    if (_saving) return;
    final result = await readClipboardImage();
    if (!mounted) return;
    if (!result.hasImage) {
      _showImageMessage(result.errorMessage!);
      return;
    }
    setState(() {
      _pastedImageBytes = result.bytes;
      _selectedImage = null;
      _removeImage = false;
    });
    _showImageMessage('Imagen pegada.');
  }

  void _showImageMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _addTag();
    setState(() => _saving = true);
    final priceText = _price.text.trim();
    try {
      await widget.controller.saveWardrobeItem(
        existing: item,
        name: _name.text,
        category: _category,
        material: _material,
        colors: _colors,
        seasons: _seasons,
        occasions: _occasions,
        tags: _tags,
        favorite: _favorite,
        laundryStatus: _laundryStatus,
        price: double.tryParse(priceText.replaceAll(',', '.')),
        sourceImagePath: _selectedImage?.path,
        sourceImageBytes: _pastedImageBytes,
        removeImage: _removeImage,
      );
      if (mounted) Navigator.pop(context, _WardrobeEditAction.saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la prenda: $error')),
      );
    }
  }
}

Future<void> _showWardrobeOutfit(BuildContext context, TodoWorkspace controller,
    WardrobeOutfit outfit) async {
  final items = outfit.itemIds
      .map(controller.wardrobeItemById)
      .whereType<WardrobeItem>()
      .toList();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 940,
        height: 600,
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(26)),
                child: _WardrobeOutfitArtwork(
                    controller: controller, outfit: outfit),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(outfit.name,
                            style: Theme.of(context).textTheme.headlineSmall),
                      ),
                      IconButton(
                        tooltip: 'Editar conjunto',
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await _showEditOutfit(context, controller, outfit);
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ]),
                    Text(
                      '${items.length} prendas${outfit.occasion.isEmpty ? '' : ' · ${outfit.occasion}'}',
                      style: TextStyle(color: context.visuals.textMuted),
                    ),
                    const SizedBox(height: 20),
                    Text('Prendas del conjunto',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _OutfitItemRow(
                            controller: controller, item: items[index]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          controller.recordWardrobeWear(
                            date: DateTime.now(),
                            itemIds: outfit.itemIds,
                            outfitId: outfit.id,
                            label: outfit.name,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Uso registrado.')),
                          );
                        },
                        icon: const Icon(Icons.event_available_rounded),
                        label: const Text('Registrar uso hoy'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final changed = await _pickOutfitRender(
                                dialogContext, controller, outfit);
                            if (changed && dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(outfit.renderImagePath.isEmpty
                              ? 'Añadir render'
                              : 'Cambiar render'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final changed = await _pasteOutfitRender(
                              dialogContext,
                              controller,
                              outfit,
                            );
                            if (changed && dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                          icon: const Icon(Icons.content_paste_rounded),
                          label: const Text('Pegar imagen'),
                        ),
                        if (outfit.renderImagePath.isNotEmpty)
                          IconButton.outlined(
                            tooltip: 'Quitar render',
                            onPressed: () async {
                              await controller
                                  .clearWardrobeOutfitRender(outfit.id);
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            },
                            icon: const Icon(Icons.hide_image_outlined),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        final confirmed = await _confirm(
                          dialogContext,
                          'Eliminar conjunto',
                          'Se eliminará el conjunto y su render. Las prendas seguirán en el armario.',
                        );
                        if (confirmed && dialogContext.mounted) {
                          controller.deleteWardrobeOutfit(outfit.id);
                          Navigator.pop(dialogContext);
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Eliminar conjunto'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OutfitItemRow extends StatelessWidget {
  const _OutfitItemRow({required this.controller, required this.item});
  final TodoWorkspace controller;
  final WardrobeItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .58),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        SizedBox(
          width: 58,
          height: 58,
          child: FutureBuilder<String>(
            future: controller.wardrobeImageAbsolutePath(item),
            builder: (context, snapshot) {
              final path = snapshot.data ?? '';
              if (path.isEmpty || !File(path).existsSync()) {
                return const Icon(Icons.checkroom_outlined);
              }
              return Image.file(File(path), fit: BoxFit.contain);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(item.category,
                  style: TextStyle(
                      color: context.visuals.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }
}

Future<bool> _pickOutfitRender(BuildContext context, TodoWorkspace controller,
    WardrobeOutfit outfit) async {
  final file = await openFile(
    acceptedTypeGroups: const <XTypeGroup>[
      XTypeGroup(
          label: 'Imágenes', extensions: <String>['png', 'jpg', 'jpeg', 'webp'])
    ],
  );
  if (file == null) return false;
  try {
    await controller.importWardrobeOutfitRender(outfit.id, file.path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Render del conjunto actualizado.')),
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar la imagen: $error')),
      );
    }
    return false;
  }
}

Future<bool> _pasteOutfitRender(
  BuildContext context,
  TodoWorkspace controller,
  WardrobeOutfit outfit,
) async {
  final result = await readClipboardImage();
  if (!context.mounted) return false;
  if (!result.hasImage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.errorMessage!)),
    );
    return false;
  }
  try {
    await controller.importWardrobeOutfitRenderBytes(
      outfit.id,
      result.bytes!,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen pegada en el conjunto.')),
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo pegar la imagen: $error')),
      );
    }
    return false;
  }
}

Future<void> _showCreateOutfit(
    BuildContext context, TodoWorkspace controller) async {
  final name = TextEditingController();
  final selected = <String>{};
  final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                  title: const Text('Nuevo conjunto'),
                  content: SizedBox(
                      width: 480,
                      height: 470,
                      child: Column(children: [
                        TextField(
                            controller: name,
                            decoration:
                                const InputDecoration(labelText: 'Nombre')),
                        const SizedBox(height: 10),
                        Expanded(
                            child: ListView(
                                children: controller.wardrobeItems
                                    .where((item) => !item.archived)
                                    .map((item) => CheckboxListTile(
                                        value: selected.contains(item.id),
                                        title: Text(item.name),
                                        subtitle: Text(item.category),
                                        onChanged: (value) => setDialogState(
                                            () => value == true
                                                ? selected.add(item.id)
                                                : selected.remove(item.id))))
                                    .toList()))
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () => Navigator.pop(context, true),
                        child: const Text('Crear'))
                  ])));
  if (result == true) {
    controller.createWardrobeOutfit(
        name: name.text, itemIds: selected.toList());
  }
}

Future<void> _showEditOutfit(BuildContext context, TodoWorkspace controller,
    WardrobeOutfit outfit) async {
  final name = TextEditingController(text: outfit.name);
  final occasion = TextEditingController(text: outfit.occasion);
  final tags = TextEditingController(text: outfit.tags.join(', '));
  final selected = outfit.itemIds.toSet();
  final originalItems = outfit.itemIds.toSet();
  final categories = controller.wardrobeItems
      .where((item) => !item.archived || selected.contains(item.id))
      .map((item) => item.category)
      .where((category) => category.trim().isNotEmpty)
      .toSet()
      .toList()
    ..sort(WardrobeTaxonomy.compareCategories);
  categories.insert(0, 'Todas');
  var category = 'Todas';
  var query = '';
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final selectedItems = controller.wardrobeItems
            .where((item) => selected.contains(item.id))
            .toList();
        final normalizedQuery = query.trim().toLowerCase();
        final availableItems = controller.wardrobeItems.where((item) {
          if (item.archived || selected.contains(item.id)) return false;
          if (category != 'Todas' && item.category != category) return false;
          if (normalizedQuery.isEmpty) return true;
          final searchable = <String>[
            item.name,
            item.category,
            item.material,
            ...item.colors,
            ...item.tags,
            ...item.seasons,
            ...item.occasions,
          ].join(' ').toLowerCase();
          return searchable.contains(normalizedQuery);
        }).toList();
        return AlertDialog(
          title: const Text('Editar conjunto'),
          content: SizedBox(
            width: 760,
            height: 680,
            child: Column(children: [
              Row(children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: occasion,
                    decoration: const InputDecoration(
                      labelText: 'Ocasión',
                      hintText: 'Diario, trabajo, cena…',
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: tags,
                decoration: const InputDecoration(
                  labelText: 'Etiquetas',
                  hintText: 'casual, verano, cómodo',
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Text('En el conjunto',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 8),
                Chip(label: Text('${selectedItems.length}')),
              ]),
              const SizedBox(height: 6),
              SizedBox(
                height: 104,
                child: selectedItems.isEmpty
                    ? Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: context.visuals.panelBorder),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                            'Selecciona al menos una prenda del catálogo.'),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: selectedItems.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final item = selectedItems[index];
                          return SizedBox(
                            width: 224,
                            child: Card(
                              margin: EdgeInsets.zero,
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.fromLTRB(8, 6, 2, 6),
                                leading: _OutfitPickerImage(
                                    controller: controller, item: item),
                                title: Text(item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(item.category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                trailing: IconButton(
                                  tooltip: 'Quitar del conjunto',
                                  onPressed: () => setDialogState(
                                      () => selected.remove(item.id)),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Buscar: pantalón beige, camisa azul…',
                  labelText: 'Buscar prendas para añadir',
                ),
                onChanged: (value) => setDialogState(() => query = value),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (context, index) {
                    final value = categories[index];
                    return FilterChip(
                      label: Text(value),
                      selected: category == value,
                      onSelected: (_) => setDialogState(() => category = value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: availableItems.isEmpty
                    ? Center(
                        child: Text(normalizedQuery.isEmpty
                            ? 'No quedan prendas en esta categoría.'
                            : 'No hay prendas que coincidan con la búsqueda.'),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 4.6,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: availableItems.length,
                        itemBuilder: (context, index) {
                          final item = availableItems[index];
                          return Card(
                            margin: EdgeInsets.zero,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  setDialogState(() => selected.add(item.id)),
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Row(children: [
                                  _OutfitPickerImage(
                                      controller: controller, item: item),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        Text(item.category,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color:
                                                    context.visuals.textMuted,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.add_circle_outline_rounded),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar cambios'),
            ),
          ],
        );
      },
    ),
  );
  if (result != true) return;
  final itemsChanged = originalItems.length != selected.length ||
      !originalItems.containsAll(selected);
  controller.updateWardrobeOutfit(
    id: outfit.id,
    name: name.text,
    itemIds: selected.toList(),
    occasion: occasion.text,
    tags: _splitTags(tags.text),
  );
  if (itemsChanged && outfit.renderImagePath.isNotEmpty) {
    await controller.clearWardrobeOutfitRender(outfit.id);
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(itemsChanged && outfit.renderImagePath.isNotEmpty
          ? 'Conjunto actualizado. El render se quitó porque cambiaron las prendas.'
          : 'Conjunto actualizado.'),
    ));
  }
}

class _OutfitPickerImage extends StatelessWidget {
  const _OutfitPickerImage({required this.controller, required this.item});
  final TodoWorkspace controller;
  final WardrobeItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 58,
      child: FutureBuilder<String>(
        future: controller.wardrobeImageAbsolutePath(item),
        builder: (context, snapshot) {
          final path = snapshot.data ?? '';
          if (path.isEmpty || !File(path).existsSync()) {
            return const Icon(Icons.checkroom_outlined);
          }
          return Image.file(File(path), fit: BoxFit.contain);
        },
      ),
    );
  }
}

Future<void> _showPlanDay(
    BuildContext context, TodoWorkspace controller, DateTime day) async {
  String? outfitId = controller.wardrobeOutfits.firstOrNull?.id;
  var weather = WardrobeWeather.mild;
  final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                  title: Text('Planificar ${day.day}/${day.month}'),
                  content: SizedBox(
                      width: 420,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        DropdownButtonFormField<String>(
                            initialValue: outfitId,
                            decoration:
                                const InputDecoration(labelText: 'Conjunto'),
                            items: controller.wardrobeOutfits
                                .map((outfit) => DropdownMenuItem(
                                    value: outfit.id, child: Text(outfit.name)))
                                .toList(),
                            onChanged: (value) => outfitId = value),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<WardrobeWeather>(
                            initialValue: weather,
                            decoration:
                                const InputDecoration(labelText: 'Clima'),
                            items: WardrobeWeather.values
                                .map((value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(_weatherLabel(value))))
                                .toList(),
                            onChanged: (value) => setDialogState(
                                () => weather = value ?? WardrobeWeather.mild))
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: outfitId == null
                            ? null
                            : () => Navigator.pop(context, true),
                        child: const Text('Guardar'))
                  ])));
  if (result == true && outfitId != null) {
    final outfit =
        controller.wardrobeOutfits.where((value) => value.id == outfitId).first;
    controller.setWardrobePlan(
        date: day,
        itemIds: outfit.itemIds,
        outfitId: outfit.id,
        weather: weather,
        occasion: outfit.occasion);
  }
}

Future<void> _showCreatePackingList(
    BuildContext context, TodoWorkspace controller) async {
  final name = TextEditingController();
  final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
              title: const Text('Nueva maleta'),
              content: TextField(
                  controller: name,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Nombre del viaje')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Crear'))
              ]));
  if (result == true) {
    controller.createWardrobePackingList(
        name: name.text,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)));
  }
}

Future<void> _showAddPackingItem(BuildContext context, TodoWorkspace controller,
    WardrobePackingList list) async {
  final available = controller.wardrobeItems
      .where((item) =>
          !item.archived &&
          !list.entries.any((entry) => entry.itemId == item.id))
      .toList();
  final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
          title: const Text('Añadir prenda'),
          children: available
              .map((item) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, item.id),
                  child: ListTile(
                      title: Text(item.name), subtitle: Text(item.category))))
              .toList()));
  if (selected != null) controller.addWardrobePackingItem(list.id, selected);
}

Future<void> _importWardrobeDirectory(
    BuildContext context, TodoWorkspace controller) async {
  final path = await getDirectoryPath(confirmButtonText: 'Seleccionar lote');
  if (path == null) return;
  try {
    await controller.stageWardrobeImportDirectory(path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lote preparado para revisión.')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo importar el lote: $error')));
    }
  }
}

Future<void> _approveBatch(
    BuildContext context, TodoWorkspace controller, String batchId) async {
  try {
    final count = await controller.approveWardrobeImport(batchId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Se añadieron $count prendas al armario.')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo aprobar el lote: $error')));
    }
  }
}

Future<void> _showEditImportItem(BuildContext context, TodoWorkspace controller,
    WardrobeImportBatch batch, WardrobeImportItem item) async {
  final name = TextEditingController(text: item.name);
  final category = TextEditingController(text: item.category);
  final tags = TextEditingController(text: item.tags.join(', '));
  final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
              title: const Text('Revisar metadatos'),
              content: SizedBox(
                  width: 420,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: name,
                        decoration: const InputDecoration(labelText: 'Nombre')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: category,
                        decoration:
                            const InputDecoration(labelText: 'Categoría')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: tags,
                        decoration:
                            const InputDecoration(labelText: 'Etiquetas'))
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Guardar'))
              ]));
  if (saved == true) {
    controller.updateWardrobeImportItem(batch.id, item.id,
        name: name.text, category: category.text, tags: _splitTags(tags.text));
  }
}

Future<bool> _confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) =>
            AlertDialog(title: Text(title), content: Text(body), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirmar'))
            ])) ??
    false;
List<String> _splitTags(String value) => value
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();
String _laundryLabel(WardrobeLaundryStatus value) => switch (value) {
      WardrobeLaundryStatus.available => 'Disponible',
      WardrobeLaundryStatus.toWash => 'Para lavar',
      WardrobeLaundryStatus.washing => 'Lavando',
      WardrobeLaundryStatus.drying => 'Secando'
    };
String _weatherLabel(WardrobeWeather value) => switch (value) {
      WardrobeWeather.hot => 'Calor',
      WardrobeWeather.mild => 'Templado',
      WardrobeWeather.cold => 'Frío',
      WardrobeWeather.rain => 'Lluvia'
    };
String _wardrobeWeekdayLabel(int weekday) => const <String>[
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ][weekday - 1];

extension _WardrobeFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
