part of 'app_shell.dart';

class _WardrobeOutfitSelector extends StatefulWidget {
  const _WardrobeOutfitSelector(
      {required this.controller,
      required this.selected,
      required this.onToggle});
  final TodoWorkspace controller;
  final Set<String> selected;
  final ValueChanged<WardrobeItem> onToggle;

  @override
  State<_WardrobeOutfitSelector> createState() =>
      _WardrobeOutfitSelectorState();
}

class _WardrobeOutfitSelectorState extends State<_WardrobeOutfitSelector> {
  String _query = '';
  String? _category;
  bool _selectedOnly = false;
  bool _favoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final all = widget.controller.wardrobeItems
        .where((item) => !item.archived)
        .toList();
    final categories = all.map((item) => item.category).toSet().toList()
      ..sort(WardrobeTaxonomy.compareCategories);
    final query = _query.trim().toLowerCase();
    final items = all.where((item) {
      if (_category != null && item.category != _category) return false;
      if (_selectedOnly && !widget.selected.contains(item.id)) return false;
      if (_favoritesOnly && !item.favorite) return false;
      return [
        item.name,
        item.category,
        item.material,
        ...item.colors,
        ...item.tags,
        ...item.seasons,
        ...item.occasions
      ].join(' ').toLowerCase().contains(query);
    }).toList()
      ..sort((left, right) {
        if (left.favorite != right.favorite) return left.favorite ? -1 : 1;
        final order =
            WardrobeTaxonomy.compareCategories(left.category, right.category);
        return order != 0
            ? order
            : left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });
    return Column(children: [
      _CatalogSearchField(
          label: 'Buscar prendas para añadir',
          hint: 'Pantalón beige, camisa azul…',
          onChanged: (value) => setState(() => _query = value)),
      const SizedBox(height: 10),
      SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _FilterPill(
                label: 'Todas',
                selected:
                    _category == null && !_selectedOnly && !_favoritesOnly,
                onTap: () => setState(() {
                      _category = null;
                      _selectedOnly = false;
                      _favoritesOnly = false;
                    })),
            const SizedBox(width: 7),
            _FilterPill(
                label: 'En el conjunto (${widget.selected.length})',
                selected: _selectedOnly,
                onTap: () => setState(() {
                      _selectedOnly = !_selectedOnly;
                      _category = null;
                      _favoritesOnly = false;
                    })),
            const SizedBox(width: 7),
            _FilterPill(
                label: 'Favoritos',
                selected: _favoritesOnly,
                onTap: () => setState(() {
                      _favoritesOnly = !_favoritesOnly;
                      _category = null;
                      _selectedOnly = false;
                    })),
            for (final category in categories) ...[
              const SizedBox(width: 7),
              _FilterPill(
                  label: category,
                  selected: _category == category,
                  onTap: () => setState(() => _category = category)),
            ],
          ])),
      const SizedBox(height: 10),
      Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No hay prendas con estos filtros.'))
              : _WardrobeItemsGrid(
                  controller: widget.controller,
                  items: items,
                  onTapForItem: widget.onToggle,
                  actionsForItem: (item) => [
                    IconButton.filledTonal(
                      tooltip: widget.selected.contains(item.id)
                          ? 'Quitar del conjunto'
                          : 'Añadir al conjunto',
                      onPressed: () => widget.onToggle(item),
                      icon: Icon(widget.selected.contains(item.id)
                          ? Icons.check_circle_rounded
                          : Icons.add_circle_outline_rounded),
                    )
                  ],
                )),
    ]);
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
                      width: 1040,
                      height: 650,
                      child: Column(children: [
                        TextField(
                            controller: name,
                            decoration:
                                const InputDecoration(labelText: 'Nombre')),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _WardrobeOutfitSelector(
                            controller: controller,
                            selected: selected,
                            onToggle: (item) => setDialogState(() {
                              if (!selected.add(item.id)) {
                                selected.remove(item.id);
                              }
                            }),
                          ),
                        )
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
            width: 1040,
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
                    : _WardrobeItemsGrid(
                        controller: controller,
                        items: availableItems,
                        onTapForItem: (item) =>
                            setDialogState(() => selected.add(item.id)),
                        actionsForItem: (item) => [
                          IconButton.filledTonal(
                            tooltip: 'Añadir al conjunto',
                            onPressed: () =>
                                setDialogState(() => selected.add(item.id)),
                            icon: const Icon(Icons.add_circle_outline_rounded),
                          )
                        ],
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

Future<WardrobePackingList?> _showCreatePackingList(
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
    return controller.createWardrobePackingList(
        name: name.text,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)));
  }
  return null;
}

Future<WardrobePackingList?> _showDuplicatePackingList(BuildContext context,
    TodoWorkspace controller, WardrobePackingList original) async {
  final name = TextEditingController(text: '${original.name} · otro viaje');
  var start = DateUtils.dateOnly(DateTime.now());
  var end = start.add(original.endDate.difference(original.startDate));
  var keepDiscarded = false;
  final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
            builder: (context, actualizar) => AlertDialog(
              title: const Text('Duplicar maleta'),
              content: SizedBox(
                  width: 480,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: name,
                        autofocus: true,
                        decoration: const InputDecoration(
                            labelText: 'Nombre del nuevo viaje')),
                    const SizedBox(height: 12),
                    ListTile(
                        title: const Text('Inicio'),
                        subtitle:
                            Text('${start.day}/${start.month}/${start.year}'),
                        trailing: const Icon(Icons.calendar_today_outlined),
                        onTap: () async {
                          final date = await showDatePicker(
                              context: context,
                              initialDate: start,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100));
                          if (date != null && context.mounted) {
                            actualizar(() {
                              final duration = end.difference(start);
                              start = date;
                              end = date.add(duration);
                            });
                          }
                        }),
                    ListTile(
                        title: const Text('Fin'),
                        subtitle: Text('${end.day}/${end.month}/${end.year}'),
                        trailing: const Icon(Icons.calendar_today_outlined),
                        onTap: () async {
                          final date = await showDatePicker(
                              context: context,
                              initialDate: end,
                              firstDate: start,
                              lastDate: DateTime(2100));
                          if (date != null && context.mounted) {
                            actualizar(() => end = date);
                          }
                        }),
                    CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Conservar prendas descartadas'),
                        subtitle: Text(
                            '${original.discardedItemIds.length} prendas. Las marcas de preparada se reinician.'),
                        value: keepDiscarded,
                        onChanged: (value) =>
                            actualizar(() => keepDiscarded = value ?? false)),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Duplicar')),
              ],
            ),
          ));
  if (save != true) return null;
  return controller.duplicateWardrobePackingList(original.id,
      name: name.text,
      startDate: start,
      endDate: end,
      keepDiscarded: keepDiscarded);
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
