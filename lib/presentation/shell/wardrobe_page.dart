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
    final tabs = controller.visibilitySettings.visibleTabs(AppSection.wardrobe);
    final views = <String, Widget>{
      'wardrobe': _wardrobeGrid(),
      'outfits': _WardrobeOutfitsTab(controller: controller),
      'planner': _WardrobePlannerTab(controller: controller),
      'laundry': _WardrobeLaundryTab(controller: controller),
      'packing': _WardrobePackingTab(controller: controller),
      'stats': _WardrobeStatsTab(controller: controller),
    };
    return DefaultTabController(
      key: ValueKey(tabs.join(',')),
      length: tabs.length,
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
            _SectionTabBar(
              labels: tabs
                  .map((id) =>
                      AppVisibilitySettings.tabs[AppSection.wardrobe]![id]!)
                  .toList(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: tabs.map((id) => views[id]!).toList(),
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
    final normalizedQuery = _query.trim().paraBuscar;
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
      ].join(' ').paraBuscar;
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
              : _WardrobeItemsGrid(controller: controller, items: items),
        ),
      ],
    );
  }
}

class _WardrobeItemsGrid extends StatelessWidget {
  const _WardrobeItemsGrid({
    required this.controller,
    required this.items,
    this.actionsForItem,
    this.onTapForItem,
  });

  final TodoWorkspace controller;
  final List<WardrobeItem> items;
  final List<Widget> Function(WardrobeItem)? actionsForItem;
  final ValueChanged<WardrobeItem>? onTapForItem;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: max(2, (constraints.maxWidth / 220).floor()),
            childAspectRatio: .72,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _WardrobeItemCard(
            controller: controller,
            item: items[index],
            actions: actionsForItem?.call(items[index]),
            onTap:
                onTapForItem == null ? null : () => onTapForItem!(items[index]),
          ),
        ),
      );
}

class _WardrobeItemCard extends StatelessWidget {
  const _WardrobeItemCard({
    required this.controller,
    required this.item,
    this.actions,
    this.onTap,
  });
  final TodoWorkspace controller;
  final WardrobeItem item;
  final List<Widget>? actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            onTap ?? () => _showWardrobeItemDetail(context, controller, item),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions ??
                          [
                            IconButton.filledTonal(
                              tooltip: item.favorite
                                  ? 'Quitar de favoritos'
                                  : 'Añadir a favoritos',
                              onPressed: () =>
                                  controller.toggleWardrobeFavorite(item.id),
                              icon: Icon(item.favorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded),
                            ),
                          ],
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
  const _WardrobeOutfitCard(
      {required this.controller, required this.outfit, this.onTap});
  final TodoWorkspace controller;
  final WardrobeOutfit outfit;
  final VoidCallback? onTap;

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
          onTap: widget.onTap ??
              () => _showWardrobeOutfit(context, widget.controller, outfit),
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
                  child: Center(
                    child: Chip(
                      avatar: Icon(
                          widget.onTap == null
                              ? Icons.visibility_outlined
                              : Icons.luggage_outlined,
                          size: 18),
                      label: Text(widget.onTap == null
                          ? 'Ver conjunto'
                          : 'Añadir conjunto'),
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

class _WardrobePackingTab extends StatefulWidget {
  const _WardrobePackingTab({required this.controller});
  final TodoWorkspace controller;

  @override
  State<_WardrobePackingTab> createState() => _WardrobePackingTabState();
}

class _WardrobePackingTabState extends State<_WardrobePackingTab> {
  String? _selectedListId;
  String _query = '';
  String? _category;
  int _view = 0;

  TodoWorkspace get controller => widget.controller;

  Future<void> _duplicarMaleta(WardrobePackingList list) async {
    final copy = await _showDuplicatePackingList(context, controller, list);
    if (copy != null && mounted) {
      setState(() {
        _selectedListId = copy.id;
        _view = 0;
        _query = '';
        _category = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = controller.wardrobePackingLists
        .where((list) => list.id == _selectedListId)
        .firstOrNull;
    if (selected == null) {
      return Column(children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () async {
              final created = await _showCreatePackingList(context, controller);
              if (created != null && mounted) {
                setState(() {
                  _selectedListId = created.id;
                  _view = 0;
                  _query = '';
                  _category = null;
                });
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nueva maleta'),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: controller.wardrobePackingLists.isEmpty
              ? const _WardrobeEmpty(
                  icon: Icons.luggage_outlined,
                  title: 'No hay viajes preparados',
                  subtitle:
                      'Crea una maleta y añade las prendas que quieres llevar.',
                )
              : ListView(
                  children: controller.wardrobePackingLists
                      .map((list) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.luggage_outlined),
                              title: Text(list.name),
                              subtitle: Text(
                                '${list.startDate.day}/${list.startDate.month} – ${list.endDate.day}/${list.endDate.month} · ${list.entries.length} prendas · ${list.entries.where((entry) => entry.packed).length} preparadas',
                              ),
                              trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        tooltip: 'Duplicar maleta',
                                        onPressed: () => _duplicarMaleta(list),
                                        icon: const Icon(Icons.copy_outlined)),
                                    const Icon(Icons.chevron_right_rounded),
                                  ]),
                              onTap: () => setState(() {
                                _selectedListId = list.id;
                                _view = 0;
                                _query = '';
                                _category = null;
                              }),
                            ),
                          ))
                      .toList(),
                ),
        ),
      ]);
    }

    final includedIds = selected.entries.map((entry) => entry.itemId).toSet();
    final discardedIds = selected.discardedItemIds.toSet();
    final allItems =
        controller.wardrobeItems.where((item) => !item.archived).toList();
    final availableCount = allItems
        .where((item) =>
            !includedIds.contains(item.id) && !discardedIds.contains(item.id))
        .length;
    final includedCount =
        allItems.where((item) => includedIds.contains(item.id)).length;
    final discardedCount =
        allItems.where((item) => discardedIds.contains(item.id)).length;
    final visibleGroup = allItems
        .where((item) => switch (_view) {
              0 => !includedIds.contains(item.id) &&
                  !discardedIds.contains(item.id),
              1 => includedIds.contains(item.id),
              _ => discardedIds.contains(item.id),
            })
        .toList();
    final categories = visibleGroup
        .map((item) => item.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort(WardrobeTaxonomy.compareCategories);
    final query = _query.trim().paraBuscar;
    final items = visibleGroup.where((item) {
      if (_category != null && item.category != _category) return false;
      if (query.isEmpty) return true;
      return <String>[
        item.name,
        item.category,
        item.material,
        ...item.colors,
        ...item.tags,
        ...item.seasons,
        ...item.occasions,
      ].join(' ').paraBuscar.contains(query);
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

    return Column(children: [
      Row(children: [
        IconButton(
          tooltip: 'Volver a maletas',
          onPressed: () => setState(() => _selectedListId = null),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(selected.name, style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${selected.entries.where((entry) => entry.packed).length} de ${selected.entries.length} prendas preparadas',
              style: TextStyle(color: context.visuals.textMuted),
            ),
          ],
        )),
        _HeaderSecondaryButton(
          label: 'Añadir conjunto',
          icon: Icons.style_outlined,
          onPressed: () async {
            await _showAddPackingOutfit(context, controller, selected.id);
            if (mounted) setState(() {});
          },
        ),
        IconButton(
            tooltip: 'Duplicar maleta',
            onPressed: () => _duplicarMaleta(selected),
            icon: const Icon(Icons.copy_outlined)),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _FilterPill(
          key: const ValueKey('packing-view-available'),
          label: 'Disponibles ($availableCount)',
          selected: _view == 0,
          onTap: () => setState(() {
            _view = 0;
            _category = null;
          }),
        ),
        _FilterPill(
          key: const ValueKey('packing-view-included'),
          label: 'En la maleta ($includedCount)',
          selected: _view == 1,
          onTap: () => setState(() {
            _view = 1;
            _category = null;
          }),
        ),
        _FilterPill(
          key: const ValueKey('packing-view-discarded'),
          label: 'Descartadas ($discardedCount)',
          selected: _view == 2,
          onTap: () => setState(() {
            _view = 2;
            _category = null;
          }),
        ),
      ]),
      const SizedBox(height: 10),
      _CatalogSearchField(
        key: ValueKey('packing-search-${selected.id}'),
        label: 'Buscar ropa',
        hint: 'Pantalón beige, zapatillas, camiseta granate…',
        onChanged: (value) => setState(() => _query = value),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _FilterPill(
                label: 'Todo (${visibleGroup.length})',
                selected: _category == null,
                onTap: () => setState(() => _category = null),
              );
            }
            final category = categories[index - 1];
            return _FilterPill(
              label:
                  '$category (${visibleGroup.where((item) => item.category == category).length})',
              selected: _category == category,
              onTap: () => setState(() => _category = category),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: items.isEmpty
            ? _WardrobeEmpty(
                icon: _view == 1
                    ? Icons.luggage_outlined
                    : Icons.search_off_rounded,
                title: query.isNotEmpty || _category != null
                    ? 'No hay prendas con estos filtros'
                    : switch (_view) {
                        0 => 'No quedan prendas disponibles',
                        1 => 'La maleta está vacía',
                        _ => 'No hay prendas descartadas',
                      },
                subtitle: query.isNotEmpty || _category != null
                    ? 'Prueba otra categoría o cambia la búsqueda.'
                    : switch (_view) {
                        0 =>
                          'Puedes recuperar prendas desde Descartadas o quitar alguna de la maleta.',
                        1 => 'Añade prendas desde Disponibles.',
                        _ =>
                          'Descarta prendas desde Disponibles para ocultarlas de este viaje.',
                      },
              )
            : _WardrobeItemsGrid(
                controller: controller,
                items: items,
                actionsForItem: (item) => switch (_view) {
                  0 => [
                      IconButton.filledTonal(
                        tooltip: 'Añadir a la maleta',
                        icon: const Icon(Icons.luggage_rounded),
                        onPressed: () => controller.addWardrobePackingItem(
                            selected.id, item.id),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        tooltip: 'Descartar para este viaje',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => controller.discardWardrobePackingItem(
                            selected.id, item.id),
                      ),
                    ],
                  1 => [
                      IconButton.filledTonal(
                        tooltip: selected.entries
                                .firstWhere((entry) => entry.itemId == item.id)
                                .packed
                            ? 'Marcar como pendiente'
                            : 'Marcar como preparada',
                        icon: Icon(selected.entries
                                .firstWhere((entry) => entry.itemId == item.id)
                                .packed
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded),
                        onPressed: () => controller.toggleWardrobePackingItem(
                            selected.id, item.id),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        tooltip: 'Quitar de la maleta',
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        onPressed: () => controller.removeWardrobePackingItem(
                            selected.id, item.id),
                      ),
                    ],
                  _ => [
                      IconButton.filledTonal(
                        tooltip: 'Volver a disponibles',
                        icon: const Icon(Icons.undo_rounded),
                        onPressed: () => controller.restoreWardrobePackingItem(
                            selected.id, item.id),
                      ),
                    ],
                },
              ),
      ),
    ]);
  }
}

Future<void> _showAddPackingOutfit(
    BuildContext context, TodoWorkspace controller, String listId) async {
  final outfitId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text('Añadir un conjunto a la maleta'),
            content: SizedBox(
              width: 980,
              height: 600,
              child: controller.wardrobeOutfits.isEmpty
                  ? const Center(
                      child: Text('Crea un conjunto en la pestaña Conjuntos.'))
                  : LayoutBuilder(
                      builder: (context, constraints) => GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  max(2, (constraints.maxWidth / 300).floor()),
                              childAspectRatio: .73,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: controller.wardrobeOutfits.length,
                            itemBuilder: (context, index) {
                              final outfit = controller.wardrobeOutfits[index];
                              return _WardrobeOutfitCard(
                                  controller: controller,
                                  outfit: outfit,
                                  onTap: () =>
                                      Navigator.pop(context, outfit.id));
                            },
                          )),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'))
            ],
          ));
  if (outfitId == null) return;
  final count = controller.addWardrobeOutfitToPackingList(listId, outfitId);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(count == 0
          ? 'Las prendas del conjunto ya están en la maleta o están archivadas.'
          : 'Se añadieron $count prendas. Las que ya estaban se conservaron.'),
    ));
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
