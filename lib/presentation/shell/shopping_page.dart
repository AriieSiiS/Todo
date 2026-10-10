part of 'app_shell.dart';

const _shoppingCategories = <String>[
  'Electrónica',
  'Gaming',
  'Cocina',
  'Hogar y decoración',
  'Otros',
];

String _shoppingMoney(double value) =>
    '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

class ShoppingPage extends StatefulWidget {
  const ShoppingPage({required this.controller, super.key});
  final TodoWorkspace controller;

  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  String _query = '';
  String _category = 'Todas';
  String _subcategory = 'Todas';
  String _status = 'Pendientes';
  bool _priorityOnly = false;
  (String, String)? _folder;

  (String, String) _folderKey(ShoppingItem item) =>
      (item.category, item.subcategory.trim());

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final active = widget.controller.shoppingItems
              .where((item) => !item.archived)
              .toList();
          final categories =
              active.map((item) => item.category).toSet().toList()..sort();
          final selectedCategory =
              categories.contains(_category) ? _category : 'Todas';
          final subcategories = active
              .where((item) =>
                  selectedCategory == 'Todas' ||
                  item.category == selectedCategory)
              .map((item) => item.subcategory)
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final selectedSubcategory =
              subcategories.contains(_subcategory) ? _subcategory : 'Todas';
          final query = _query.trim().toLowerCase();
          final items = active.where((item) {
            if (_status == 'Pendientes' &&
                item.status == ShoppingStatus.purchased) {
              return false;
            }
            if (_status == 'Comprados' &&
                item.status != ShoppingStatus.purchased) {
              return false;
            }
            if (_priorityOnly && !item.priority) return false;
            if (selectedCategory != 'Todas' &&
                item.category != selectedCategory) {
              return false;
            }
            if (selectedSubcategory != 'Todas' &&
                item.subcategory != selectedSubcategory) {
              return false;
            }
            return [
              item.name,
              item.category,
              item.subcategory,
              item.retailer,
              item.notes,
              item.sourceUrl,
              ...item.offers.expand((offer) => [offer.name, offer.sourceUrl])
            ].join(' ').toLowerCase().contains(query);
          }).toList()
            ..sort((a, b) {
              final priority =
                  (b.priority ? 1 : 0).compareTo(a.priority ? 1 : 0);
              return priority != 0
                  ? priority
                  : b.createdAt.compareTo(a.createdAt);
            });
          final pending = active
              .where((item) => item.status != ShoppingStatus.purchased)
              .length;
          final groupSizes = <(String, String), int>{};
          for (final item in active) {
            if (!item.grouped) continue;
            final key = _folderKey(item);
            groupSizes[key] = (groupSizes[key] ?? 0) + 1;
          }
          final groups = <(String, String), List<ShoppingItem>>{};
          for (final item in items) {
            if (!item.grouped) continue;
            (groups[_folderKey(item)] ??= []).add(item);
          }
          final entries = <List<ShoppingItem>>[];
          final seen = <(String, String)>{};
          for (final item in items) {
            final key = _folderKey(item);
            if (!item.grouped || (groupSizes[key] ?? 0) < 2) {
              entries.add([item]);
            } else if (seen.add(key)) {
              entries.add(groups[key]!);
            }
          }
          final folderItems = _folder == null
              ? items
              : items
                  .where((item) => item.grouped && _folderKey(item) == _folder)
                  .toList();
          final folderName = _folder == null
              ? ''
              : _folder!.$2.isEmpty
                  ? _folder!.$1
                  : _folder!.$2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CatalogSearchField(
                key: const ValueKey('shopping-search'),
                label: 'Buscar en compras',
                hint: 'Producto, categoría, tienda o nota…',
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final entry in [
                      (label: 'Pendientes', count: pending),
                      (label: 'Todos', count: active.length),
                      (label: 'Comprados', count: active.length - pending),
                    ]) ...[
                      _FilterPill(
                        label: '${entry.label} (${entry.count})',
                        selected: _status == entry.label,
                        onTap: () => setState(() => _status = entry.label),
                      ),
                      const SizedBox(width: 7),
                    ],
                    _FilterPill(
                      label: 'Prioritarias',
                      icon: Icons.star_outline_rounded,
                      selected: _priorityOnly,
                      onTap: () =>
                          setState(() => _priorityOnly = !_priorityOnly),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 7),
                    itemBuilder: (context, index) {
                      final value =
                          index == 0 ? 'Todas' : categories[index - 1];
                      return _FilterPill(
                          label: value == 'Todas'
                              ? 'Todas las categorías (${active.length})'
                              : '$value (${active.where((item) => item.category == value).length})',
                          key: ValueKey('shopping-category-$value'),
                          selected: selectedCategory == value,
                          onTap: () => setState(() {
                                _category = value;
                                _subcategory = 'Todas';
                                _folder = null;
                              }));
                    },
                  )),
              if (selectedCategory != 'Todas' && subcategories.isNotEmpty) ...[
                const SizedBox(height: 7),
                SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: subcategories.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 7),
                      itemBuilder: (context, index) {
                        final value =
                            index == 0 ? 'Todas' : subcategories[index - 1];
                        return _FilterPill(
                            key: ValueKey('shopping-subcategory-$value'),
                            label: value == 'Todas'
                                ? 'Todas las subcategorías'
                                : value,
                            selected: selectedSubcategory == value,
                            onTap: () => setState(() {
                                  _subcategory = value;
                                  _folder = null;
                                }));
                      },
                    )),
              ],
              const SizedBox(height: 12),
              _ShoppingTrackingSummary(controller: widget.controller),
              const SizedBox(height: 10),
              if (_folder != null) ...[
                Row(children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _folder = null),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Todas las compras'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('$folderName (${folderItems.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: 'Desagrupar carpeta',
                    icon: const Icon(Icons.folder_off_outlined),
                    onPressed: () {
                      widget.controller.setShoppingGroupGrouped(
                          _folder!.$1, _folder!.$2, false);
                      setState(() => _folder = null);
                    },
                  ),
                ]),
                const SizedBox(height: 10),
              ],
              Expanded(
                  child: folderItems.isEmpty
                      ? Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.bookmark_border_rounded, size: 44),
                          const SizedBox(height: 12),
                          Text(
                              active.isEmpty
                                  ? 'Tu próxima compra empieza aquí'
                                  : 'No hay compras con estos filtros',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                              onPressed: () => _showShoppingEditor(
                                  context, widget.controller),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Añadir a compras')),
                        ]))
                      : LayoutBuilder(
                          builder: (context, constraints) => GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: max(
                                            1,
                                            (constraints.maxWidth / 260)
                                                .floor()),
                                        childAspectRatio: .78,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 14),
                                itemCount: _folder == null
                                    ? entries.length
                                    : folderItems.length,
                                itemBuilder: (context, index) {
                                  if (_folder != null) {
                                    return _ShoppingCard(
                                        controller: widget.controller,
                                        item: folderItems[index]);
                                  }
                                  final entry = entries[index];
                                  final key = _folderKey(entry.first);
                                  if (!entry.first.grouped ||
                                      (groupSizes[key] ?? 0) < 2) {
                                    return _ShoppingCard(
                                        controller: widget.controller,
                                        item: entry.single);
                                  }
                                  return _ShoppingFolderCard(
                                    key: ValueKey(
                                        ('shopping-folder', key.$1, key.$2)),
                                    controller: widget.controller,
                                    category: key.$1,
                                    name: key.$2.isEmpty ? key.$1 : key.$2,
                                    items: entry,
                                    onOpen: () => setState(() => _folder = key),
                                  );
                                },
                              ))),
            ],
          );
        },
      );
}

class _ShoppingFolderCard extends StatelessWidget {
  const _ShoppingFolderCard({
    required this.controller,
    required this.category,
    required this.name,
    required this.items,
    required this.onOpen,
    super.key,
  });
  final TodoWorkspace controller;
  final String category;
  final String name;
  final List<ShoppingItem> items;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cover = items.firstWhere((item) => item.imagePath.isNotEmpty,
        orElse: () => items.first);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        onSecondaryTapDown: (details) => _showShoppingFolderMenu(
            context,
            controller,
            category,
            items.first.subcategory,
            details.globalPosition),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              _ShoppingImage(controller: controller, item: cover),
              Positioned(
                top: 10,
                left: 10,
                right: 52,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .64),
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: PopupMenuButton<String>(
                  tooltip: 'Opciones de carpeta',
                  style: IconButton.styleFrom(
                      backgroundColor: context.visuals.panel),
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (_) => controller.setShoppingGroupGrouped(
                      category, items.first.subcategory, false),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'ungroup', child: Text('Desagrupar')),
                  ],
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.folder_outlined,
                      size: 20, color: context.visuals.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(
                    '${items.length} ${items.length == 1 ? 'producto' : 'productos'}',
                    style: TextStyle(
                        fontSize: 12, color: context.visuals.textMuted)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: Text('Ver opciones',
                        style: TextStyle(
                            fontSize: 13, color: context.visuals.accent)),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 20, color: context.visuals.accent),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

Future<void> _showShoppingFolderMenu(
    BuildContext context,
    TodoWorkspace controller,
    String category,
    String subcategory,
    Offset position) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final action = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
        overlay.globalToLocal(position) & const Size(1, 1),
        Offset.zero & overlay.size),
    items: const [
      PopupMenuItem(value: 'ungroup', child: Text('Desagrupar')),
    ],
  );
  if (context.mounted && action == 'ungroup') {
    controller.setShoppingGroupGrouped(category, subcategory, false);
  }
}

class _ShoppingImage extends StatelessWidget {
  const _ShoppingImage(
      {required this.controller, required this.item, this.thumbnail = true});
  final TodoWorkspace controller;
  final ShoppingItem item;
  final bool thumbnail;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFF3EEE5),
        child: FutureBuilder<String>(
          future:
              controller.shoppingImageAbsolutePath(item, thumbnail: thumbnail),
          builder: (context, snapshot) {
            final path = snapshot.data ?? '';
            final placeholder = Center(
                child: Icon(Icons.shopping_bag_outlined,
                    size: 58, color: context.visuals.textMuted));
            if (path.isEmpty || !File(path).existsSync()) return placeholder;
            return Image.file(File(path),
                fit: BoxFit.contain, errorBuilder: (_, __, ___) => placeholder);
          },
        ),
      );
}

class _ShoppingCard extends StatelessWidget {
  const _ShoppingCard({required this.controller, required this.item});
  final TodoWorkspace controller;
  final ShoppingItem item;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: controller.priceTracking,
      builder: (context, _) => Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showShoppingDetail(context, controller, item.id),
              onSecondaryTapDown: (details) => _showShoppingCardMenu(
                  context, controller, item, details.globalPosition),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: Stack(fit: StackFit.expand, children: [
                      _ShoppingImage(controller: controller, item: item),
                      Positioned(
                        left: 10,
                        top: 10,
                        right: 52,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .64),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(item.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  context.visuals.panel.withValues(alpha: .95),
                              foregroundColor: context.visuals.accent,
                              minimumSize: const Size(32, 32),
                              padding: const EdgeInsets.all(6),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            iconSize: 18,
                            tooltip: item.priority
                                ? 'Quitar prioridad'
                                : 'Marcar como prioritaria',
                            onPressed: () => controller.updateShoppingItem(
                                item.id,
                                priority: !item.priority),
                            icon: Icon(item.priority
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded),
                          )),
                    ])),
                    Padding(
                        padding: const EdgeInsets.all(13),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                  [item.retailer, item.subcategory]
                                      .where((value) => value.isNotEmpty)
                                      .join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: context.visuals.textMuted)),
                              const SizedBox(height: 9),
                              Text(
                                  controller.priceTracking
                                              .watch(item.id)
                                              ?.currentPrice !=
                                          null
                                      ? _shoppingMoney(controller.priceTracking
                                          .watch(item.id)!
                                          .currentPrice!)
                                      : item.referencePrice == null
                                          ? item.offers.isEmpty
                                              ? 'Precio por anotar'
                                              : '${item.offers.length} opciones de compra'
                                          : _shoppingMoney(
                                              item.referencePrice!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              Text(
                                  item.targetPrice == null
                                      ? 'Sin precio objetivo'
                                      : 'Objetivo: ${_shoppingMoney(item.targetPrice!)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: context.visuals.textMuted)),
                              const SizedBox(height: 8),
                              Row(children: [
                                if (controller.priceTracking
                                        .watch(item.id)
                                        ?.enabled ==
                                    true) ...[
                                  Tooltip(
                                    message: controller.priceTracking
                                            .watch(item.id)!
                                            .error
                                            .isEmpty
                                        ? 'Seguimiento cada 24 horas'
                                        : 'Última lectura sin precio válido',
                                    child: Icon(
                                        controller.priceTracking
                                                .watch(item.id)!
                                                .error
                                                .isEmpty
                                            ? Icons
                                                .notifications_active_outlined
                                            : Icons.warning_amber_rounded,
                                        size: 16,
                                        color: context.visuals.accent),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                    child: Text(item.status.label,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: context.visuals.textMuted))),
                                if (item.sourceUrl.isNotEmpty)
                                  const Icon(Icons.link_rounded, size: 18),
                              ]),
                            ])),
                  ]),
            ),
          ));
}

Future<void> _showShoppingCardMenu(BuildContext context,
    TodoWorkspace controller, ShoppingItem item, Offset position) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final purchased = item.status == ShoppingStatus.purchased;
  final peers = controller.shoppingItems.where((entry) =>
      !entry.archived &&
      entry.category == item.category &&
      entry.subcategory.trim() == item.subcategory.trim());
  final canRegroup = peers.length >= 2 && peers.any((entry) => !entry.grouped);
  final action = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      overlay.globalToLocal(position) & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      if (canRegroup)
        const PopupMenuItem(
          value: 'group',
          child: ListTile(
              dense: true,
              leading: Icon(Icons.create_new_folder_outlined),
              title: Text('Agrupar de nuevo')),
        ),
      for (final entry in [
        (value: 'edit', label: 'Editar', icon: Icons.edit_outlined),
        (
          value: 'priority',
          label: item.priority ? 'Quitar prioridad' : 'Marcar como prioritaria',
          icon: item.priority ? Icons.star_rounded : Icons.star_outline_rounded
        ),
        (
          value: 'status',
          label: purchased ? 'Volver a pendientes' : 'Marcar como comprado',
          icon: purchased ? Icons.undo_rounded : Icons.check_rounded
        ),
      ])
        PopupMenuItem(
          value: entry.value,
          child: ListTile(
              dense: true, leading: Icon(entry.icon), title: Text(entry.label)),
        ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'delete',
        child: ListTile(
            dense: true,
            leading: Icon(Icons.delete_outline_rounded),
            title: Text('Eliminar')),
      ),
    ],
  );
  if (!context.mounted || action == null) return;
  final current = controller.shoppingItemById(item.id);
  if (current == null) return;
  switch (action) {
    case 'group':
      controller.setShoppingGroupGrouped(
          current.category, current.subcategory, true);
    case 'edit':
      await _showShoppingEditor(context, controller, item: current);
    case 'priority':
      controller.updateShoppingItem(current.id, priority: !current.priority);
    case 'status':
      controller.updateShoppingItem(current.id,
          status: current.status == ShoppingStatus.purchased
              ? ShoppingStatus.saved
              : ShoppingStatus.purchased);
    case 'delete':
      await _confirmShoppingDelete(context, controller, current);
  }
}

Future<void> _confirmShoppingDelete(
    BuildContext context, TodoWorkspace controller, ShoppingItem item,
    {VoidCallback? onConfirmed}) async {
  final confirmed = await _confirm(
      context, 'Eliminar compra', '¿Eliminar «${item.name}» de tu lista?');
  if (!confirmed || !context.mounted) return;
  onConfirmed?.call();
  controller.deleteShoppingItem(item.id);
}

Future<void> _showShoppingDetail(
        BuildContext context, TodoWorkspace controller, String id) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final item = controller.shoppingItemById(id);
          if (item == null) return const SizedBox.shrink();
          return Dialog(
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 760),
              child: LayoutBuilder(builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final image = _ShoppingImage(
                    controller: controller, item: item, thumbnail: false);
                final details = _ShoppingDetailPanel(
                  controller: controller,
                  item: item,
                  image: compact ? image : null,
                  onClose: () => Navigator.pop(dialogContext),
                );
                if (compact) return details;
                return Row(children: [
                  Expanded(child: image),
                  SizedBox(width: 410, child: details),
                ]);
              }),
            ),
          );
        },
      ),
    );

class _ShoppingDetailPanel extends StatelessWidget {
  const _ShoppingDetailPanel({
    required this.controller,
    required this.item,
    required this.onClose,
    this.image,
  });

  final TodoWorkspace controller;
  final ShoppingItem item;
  final VoidCallback onClose;
  final Widget? image;

  @override
  Widget build(BuildContext context) {
    final url = _householdWebUri(item.sourceUrl);
    final purchased = item.status == ShoppingStatus.purchased;
    final metadata = <({String label, String value})>[
      (label: 'Categoría', value: item.category),
      if (item.subcategory.isNotEmpty)
        (label: 'Subcategoría', value: item.subcategory),
      if (item.retailer.isNotEmpty) (label: 'Tienda', value: item.retailer),
      (label: 'Estado', value: item.status.label),
      if (item.priority) (label: 'Prioridad', value: 'Prioritaria'),
    ];
    return Material(
      color: context.visuals.panel,
      child: Padding(
        padding: EdgeInsets.all(image == null ? 24 : 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('Ficha de compra',
                    style: TextStyle(color: context.visuals.textMuted))),
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (value) async {
                if (value == 'priority') {
                  controller.updateShoppingItem(item.id,
                      priority: !item.priority);
                } else if (value == 'delete') {
                  await _confirmShoppingDelete(context, controller, item,
                      onConfirmed: onClose);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'priority',
                  child: Row(children: [
                    Icon(item.priority
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded),
                    const SizedBox(width: 10),
                    Text(item.priority
                        ? 'Quitar prioridad'
                        : 'Marcar como prioritaria'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded),
                    SizedBox(width: 10),
                    Text('Eliminar de compras'),
                  ]),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ]),
          SelectableText(item.name,
              key: const ValueKey('shopping-detail-name'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              key: const ValueKey('shopping-detail-content'),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (image != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(height: 220, child: image),
                  ),
                  const SizedBox(height: 20),
                ],
                for (final entry in metadata)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.label,
                            style: TextStyle(
                                color: context.visuals.textMuted,
                                fontSize: 12)),
                        const SizedBox(height: 2),
                        SelectableText(entry.value,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: _ShoppingPrice(
                          label: 'Precio de referencia',
                          value: item.referencePrice)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _ShoppingPrice(
                          label: 'Me gustaría pagar', value: item.targetPrice)),
                ]),
                const SizedBox(height: 8),
                Text('La referencia y el objetivo se anotan manualmente.',
                    style: TextStyle(
                        fontSize: 12, color: context.visuals.textMuted)),
                const SizedBox(height: 16),
                _ShoppingTrackingPanel(controller: controller, item: item),
                if (item.notes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Notas',
                      style: TextStyle(
                          color: context.visuals.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  SelectableText(item.notes,
                      style: const TextStyle(height: 1.45)),
                ],
                if (item.researchNotes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Investigación y comparativas',
                      style: TextStyle(
                          color: context.visuals.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  SelectableText(item.researchNotes,
                      style: const TextStyle(height: 1.45)),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 16),
          if (url != null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  if (!await launchUrl(url,
                          mode: LaunchMode.externalApplication) &&
                      context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('No se pudo abrir el enlace.')));
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Abrir enlace de origen'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(children: [
            Expanded(
              child: Tooltip(
                message:
                    purchased ? 'Volver a pendientes' : 'Marcar como comprado',
                child: OutlinedButton.icon(
                  onPressed: () => controller.updateShoppingItem(item.id,
                      status: purchased
                          ? ShoppingStatus.saved
                          : ShoppingStatus.purchased),
                  icon: Icon(
                      purchased ? Icons.undo_rounded : Icons.check_rounded,
                      size: 18),
                  label: Text(purchased ? 'Pendiente' : 'Comprado'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    _showShoppingEditor(context, controller, item: item),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Editar'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ShoppingPrice extends StatelessWidget {
  const _ShoppingPrice({required this.label, required this.value});
  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: context.visuals.textMuted)),
        const SizedBox(height: 2),
        SelectableText(value == null ? 'Sin anotar' : _shoppingMoney(value!),
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ]);
}

Future<void> _showShoppingEditor(BuildContext context, TodoWorkspace controller,
        {ShoppingItem? item}) =>
    showDialog<void>(
        context: context,
        builder: (_) => _ShoppingEditor(controller: controller, item: item));

class _ShoppingEditor extends StatefulWidget {
  const _ShoppingEditor({required this.controller, this.item});
  final TodoWorkspace controller;
  final ShoppingItem? item;
  @override
  State<_ShoppingEditor> createState() => _ShoppingEditorState();
}

class _ShoppingEditorState extends State<_ShoppingEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late ShoppingStatus _status;
  late bool _priority;
  bool _saving = false;
  String? _savedId;
  XFile? _image;
  final _offers = <({TextEditingController name, TextEditingController url})>[];
  final _offerControllers = <TextEditingController>[];

  void _addOffer({String name = '', String url = ''}) {
    final fields = (
      name: TextEditingController(text: name),
      url: TextEditingController(text: url)
    );
    _offers.add(fields);
    _offerControllers.addAll([fields.name, fields.url]);
  }

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _savedId = item?.id;
    _status = item?.status ?? ShoppingStatus.saved;
    _priority = item?.priority ?? false;
    _fields = {
      'name': TextEditingController(text: item?.name ?? ''),
      'category': TextEditingController(text: item?.category ?? 'Electrónica'),
      'subcategory': TextEditingController(text: item?.subcategory ?? ''),
      'sourceUrl': TextEditingController(text: item?.sourceUrl ?? ''),
      'retailer': TextEditingController(text: item?.retailer ?? ''),
      'referencePrice': TextEditingController(
          text: item?.referencePrice?.toStringAsFixed(2).replaceAll('.', ',') ??
              ''),
      'targetPrice': TextEditingController(
          text:
              item?.targetPrice?.toStringAsFixed(2).replaceAll('.', ',') ?? ''),
      'notes': TextEditingController(text: item?.notes ?? ''),
      'researchNotes': TextEditingController(text: item?.researchNotes ?? ''),
    };
    for (final offer in item?.offers ?? <ShoppingOffer>[]) {
      _addOffer(name: offer.name, url: offer.sourceUrl);
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    for (final field in _offerControllers) {
      field.dispose();
    }
    super.dispose();
  }

  Widget _field(String id, String label,
          {int lines = 1,
          String? hint,
          bool required = false,
          bool money = false}) =>
      TextFormField(
          controller: _fields[id],
          maxLines: lines,
          key: ValueKey('shopping-editor-$id'),
          decoration: InputDecoration(
              labelText: label, hintText: hint, suffixText: money ? '€' : null),
          keyboardType: money
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (required && text.isEmpty) return 'Este campo es obligatorio.';
            if (id == 'sourceUrl' &&
                text.isNotEmpty &&
                _householdWebUri(text) == null) {
              return 'Introduce un enlace http o https válido.';
            }
            if (money && text.isNotEmpty) {
              final amount = double.tryParse(text.replaceAll(',', '.'));
              if (amount == null || !amount.isFinite || amount < 0) {
                return 'Introduce un precio válido.';
              }
            }
            return null;
          });

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    double? price(String key) =>
        double.tryParse(_fields[key]!.text.trim().replaceAll(',', '.'));
    try {
      _savedId ??= widget.controller
          .createShoppingItem(
              name: _fields['name']!.text, category: _fields['category']!.text)
          .id;
      widget.controller.updateShoppingItem(_savedId!,
          name: _fields['name']!.text,
          category: _fields['category']!.text,
          subcategory: _fields['subcategory']!.text,
          sourceUrl: _offers.isEmpty
              ? _fields['sourceUrl']!.text
              : _offers.first.url.text.trim(),
          offers: _offers
              .map((offer) => ShoppingOffer(
                  name: offer.name.text.trim(),
                  sourceUrl: offer.url.text.trim()))
              .toList(),
          retailer: _fields['retailer']!.text,
          notes: _fields['notes']!.text,
          researchNotes: _fields['researchNotes']!.text,
          status: _status,
          priority: _priority,
          referencePrice: price('referencePrice'),
          clearReferencePrice: price('referencePrice') == null,
          targetPrice: price('targetPrice'),
          clearTargetPrice: price('targetPrice') == null);
      if (_image != null) {
        await widget.controller.importShoppingImage(_savedId!, _image!.path);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('No se pudo completar el guardado: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.item == null ? 'Añadir a compras' : 'Editar compra'),
        content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _field('name', 'Nombre del producto o idea',
                            required: true),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                              child: _field('category', 'Categoría',
                                  required: true)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _field('subcategory', 'Subcategoría',
                                  hint: 'Tablets, auriculares…'))
                        ]),
                        const SizedBox(height: 6),
                        Wrap(spacing: 5, children: [
                          for (final category in {
                            ..._shoppingCategories,
                            ...widget.controller.shoppingItems
                                .map((item) => item.category)
                          })
                            ActionChip(
                                label: Text(category),
                                onPressed: () =>
                                    _fields['category']!.text = category),
                        ]),
                        const SizedBox(height: 14),
                        if (_offers.isEmpty)
                          _field('sourceUrl', 'Enlace de origen',
                              hint: 'Amazon, tuit o página del producto'),
                        const SizedBox(height: 10),
                        const Text('Opciones de compra',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        for (var i = 0; i < _offers.length; i++)
                          Padding(
                            key: ObjectKey(_offers[i].name),
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      child: Column(children: [
                                    TextFormField(
                                        controller: _offers[i].name,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Nombre de la opción y pack'),
                                        validator: (value) => value
                                                    ?.trim()
                                                    .isNotEmpty ==
                                                true
                                            ? null
                                            : 'Indica el nombre de esta opción.'),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                        controller: _offers[i].url,
                                        decoration: const InputDecoration(
                                            labelText: 'Enlace de esta opción'),
                                        validator: (value) => _householdWebUri(
                                                    value?.trim() ?? '') !=
                                                null
                                            ? null
                                            : 'Introduce un enlace http o https válido.'),
                                  ])),
                                  IconButton(
                                      tooltip: 'Quitar opción',
                                      onPressed: () =>
                                          setState(() => _offers.removeAt(i)),
                                      icon: const Icon(Icons.close_rounded)),
                                ]),
                          ),
                        TextButton.icon(
                          onPressed: _offers.length >= 25
                              ? null
                              : () => setState(() {
                                    if (_offers.isEmpty &&
                                        _fields['sourceUrl']!
                                            .text
                                            .trim()
                                            .isNotEmpty) {
                                      _addOffer(
                                          name: _fields['name']!.text,
                                          url: _fields['sourceUrl']!.text);
                                    }
                                    _addOffer();
                                  }),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Añadir opción'),
                        ),
                        const SizedBox(height: 14),
                        _field('retailer', 'Tienda o fuente'),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                              child: _field(
                                  'referencePrice', 'Precio de referencia',
                                  money: true)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _field('targetPrice', 'Precio objetivo',
                                  money: true))
                        ]),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<ShoppingStatus>(
                            initialValue: _status,
                            decoration:
                                const InputDecoration(labelText: 'Estado'),
                            items: ShoppingStatus.values
                                .map((status) => DropdownMenuItem(
                                    value: status, child: Text(status.label)))
                                .toList(),
                            onChanged: (value) => setState(
                                () => _status = value ?? ShoppingStatus.saved)),
                        CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Compra prioritaria'),
                            value: _priority,
                            onChanged: (value) =>
                                setState(() => _priority = value ?? false)),
                        OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () async {
                                    final file =
                                        await openFile(acceptedTypeGroups: [
                                      const XTypeGroup(
                                          label: 'Imagen',
                                          extensions: [
                                            'png',
                                            'jpg',
                                            'jpeg',
                                            'webp'
                                          ])
                                    ]);
                                    if (file != null && mounted) {
                                      setState(() => _image = file);
                                    }
                                  },
                            icon:
                                const Icon(Icons.add_photo_alternate_outlined),
                            label: Text(_image?.name ?? 'Elegir imagen')),
                        if (_image != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SizedBox(
                                  height: 110,
                                  child: Image.file(File(_image!.path),
                                      fit: BoxFit.contain))),
                        const SizedBox(height: 14),
                        _field('notes', 'Notas',
                            lines: 3,
                            hint: 'Para qué lo quieres, variante, dudas…'),
                        const SizedBox(height: 14),
                        _field('researchNotes', 'Investigación y comparativas',
                            lines: 3,
                            hint:
                                'Conclusiones y enlaces que quieras conservar'),
                      ],
                    )))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar'))
        ],
      );
}
