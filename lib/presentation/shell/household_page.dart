part of 'app_shell.dart';

class HouseholdPage extends StatefulWidget {
  const HouseholdPage(
      {required this.controller, this.homeAssistant, super.key});

  final TodoWorkspace controller;
  final HomeAssistantController? homeAssistant;

  @override
  State<HouseholdPage> createState() => _HouseholdPageState();
}

class _HouseholdPageState extends State<HouseholdPage> {
  String _query = '';
  String _category = 'Todos';

  TodoWorkspace get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final active =
        controller.householdItems.where((item) => !item.archived).toList();
    final categories = active
        .map((item) => item.category.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    categories.insert(0, 'Todos');
    final selectedCategory =
        categories.contains(_category) ? _category : 'Todos';
    final query = _query.trim().toLowerCase();
    final items = active.where((item) {
      if (selectedCategory != 'Todos' && item.category != selectedCategory) {
        return false;
      }
      if (query.isEmpty) return true;
      return <String>[
        item.name,
        item.category,
        item.brand,
        item.model,
        item.serialNumber,
        item.location,
        item.retailer,
        ...item.tags,
      ].join(' ').toLowerCase().contains(query);
    }).toList()
      ..sort((left, right) {
        final category =
            left.category.toLowerCase().compareTo(right.category.toLowerCase());
        return category != 0
            ? category
            : left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });
    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: _PageHeader(
                title: 'Hogar',
                subtitle: '',
                compact: true,
                pinTrailingToEdge: true,
                trailing: _HeaderActionButton(
                  label: 'Añadir compra',
                  icon: Icons.add_rounded,
                  onPressed: () => _showHouseholdEditor(context, controller),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const _SectionTabBar(
              labels: ['Inventario', 'Gemelo 3D', 'Códigos QR'],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _inventoryView(
                    active: active,
                    categories: categories,
                    selectedCategory: selectedCategory,
                    items: items,
                  ),
                  HomeTwinPage(
                      controller: controller,
                      homeAssistant: widget.homeAssistant),
                  _HouseholdQrTab(controller: controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inventoryView({
    required List<HouseholdItem> active,
    required List<String> categories,
    required String selectedCategory,
    required List<HouseholdItem> items,
  }) {
    return Column(
      children: [
        _CatalogSearchField(
          key: const ValueKey('household-search'),
          label: 'Buscar en el hogar',
          hint: 'Lavadora, Bosch, cocina, modelo o número de serie…',
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            key: const ValueKey('household-category-filters'),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final value = categories[index];
              final count = value == 'Todos'
                  ? active.length
                  : active.where((item) => item.category == value).length;
              return _FilterPill(
                label: '$value ($count)',
                selected: selectedCategory == value,
                onTap: () => setState(() => _category = value),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: items.isEmpty
              ? _HouseholdEmpty(filtered: active.isNotEmpty)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        max(2, (constraints.maxWidth / 260).floor());
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        childAspectRatio: .78,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) => _HouseholdItemCard(
                        controller: controller,
                        item: items[index],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _HouseholdQrTab extends StatelessWidget {
  const _HouseholdQrTab({required this.controller});

  final TodoWorkspace controller;

  @override
  Widget build(BuildContext context) {
    final items = controller.householdItems
        .where((item) => !item.archived)
        .toList()
      ..sort((left, right) =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()));
    if (items.isEmpty) {
      return const _HouseholdEmpty(filtered: false);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: context.visuals.panelAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.visuals.pageBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1DD),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.qr_code_2_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Códigos QR automáticos',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Cada artículo recibe su QR al crearse y se actualiza con su ficha. Funciona sin internet y no incluye precio, ubicación ni número de serie.',
                      style: TextStyle(
                        color: context.visuals.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 560,
              mainAxisExtent: 224,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                _HouseholdQrCard(item: items[index]),
          ),
        ),
      ],
    );
  }
}

class _HouseholdQrCard extends StatelessWidget {
  const _HouseholdQrCard({required this.item});

  final HouseholdItem item;

  @override
  Widget build(BuildContext context) {
    final identity = <String>[item.brand, item.model]
        .where((value) => value.trim().isNotEmpty)
        .join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showHouseholdQr(context, item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      identity.isEmpty ? item.category : identity,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.visuals.textMuted),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          _householdWebUri(item.manualSourceUrl) == null
                              ? Icons.qr_code_2_rounded
                              : Icons.menu_book_outlined,
                          size: 17,
                          color: context.visuals.accent,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _householdWebUri(item.manualSourceUrl) == null
                                ? 'Ficha básica'
                                : 'Ficha y manual web',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Pulsa para ampliar',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _HouseholdFlowerQr(
                key: ValueKey('household-qr-card-${item.id}'),
                data: _householdQrSummary(item),
                size: 176,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HouseholdFlowerQr extends StatelessWidget {
  const _HouseholdFlowerQr({
    required this.data,
    required this.size,
    super.key,
  });

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF35422E);
    return Semantics(
      label: 'Código QR',
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF0F5E8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD3DFC5)),
          ),
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: size - 28,
                  height: size - 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: QrImageView(
                    data: data,
                    version: QrVersions.auto,
                    padding: const EdgeInsets.all(9),
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: ink,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: ink,
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 3,
                top: 3,
                child: Icon(Icons.local_florist_rounded,
                    size: 21, color: Color(0xFF8DA574)),
              ),
              const Positioned(
                right: 3,
                bottom: 3,
                child: Icon(Icons.local_florist_rounded,
                    size: 21, color: Color(0xFFB88A93)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _householdQrSummary(HouseholdItem item) {
  final manual = _householdWebUri(item.manualSourceUrl);
  return <String>[
    'Ficha de Hogar: ${item.name}',
    'Categoría: ${item.category}',
    if (item.brand.trim().isNotEmpty) 'Marca: ${item.brand}',
    if (item.model.trim().isNotEmpty) 'Modelo: ${item.model}',
    if (manual != null) 'Manual: $manual',
  ].join('\n');
}

Uri? _householdWebUri(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && <String>{'https', 'http'}.contains(uri.scheme)
      ? uri
      : null;
}

Future<void> _showHouseholdQr(
  BuildContext context,
  HouseholdItem item,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(item.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HouseholdFlowerQr(
            data: _householdQrSummary(item),
            size: 340,
          ),
          const SizedBox(height: 16),
          const Text(
            'Escanea este código para consultar la ficha básica del artículo.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

class _HouseholdItemCard extends StatelessWidget {
  const _HouseholdItemCard({required this.controller, required this.item});

  final TodoWorkspace controller;
  final HouseholdItem item;

  @override
  Widget build(BuildContext context) {
    final identity = <String>[
      item.brand,
      item.model,
    ].where((value) => value.trim().isNotEmpty).join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showHouseholdDetail(context, controller, item),
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
                      future: controller.householdImageAbsolutePath(item),
                      builder: (context, snapshot) {
                        final path = snapshot.data ?? '';
                        if (path.isEmpty || !File(path).existsSync()) {
                          return const _MissingHouseholdImage();
                        }
                        return Image.file(
                          File(path),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const _MissingHouseholdImage(),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .64),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.category,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
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
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    identity.isEmpty ? 'Marca y modelo pendientes' : identity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.visuals.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      _HouseholdStatusIcon(
                        icon: Icons.menu_book_rounded,
                        active: item.hasManual,
                        tooltip: item.hasManual
                            ? 'Manual guardado'
                            : 'Manual pendiente',
                      ),
                      const SizedBox(width: 7),
                      _HouseholdStatusIcon(
                        icon: Icons.receipt_long_rounded,
                        active: item.hasInvoice,
                        tooltip: item.hasInvoice
                            ? 'Factura guardada'
                            : 'Factura pendiente',
                      ),
                      const Spacer(),
                      if (item.location.isNotEmpty)
                        Flexible(
                          child: Text(
                            item.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
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
}

class _HouseholdStatusIcon extends StatelessWidget {
  const _HouseholdStatusIcon({
    required this.icon,
    required this.active,
    required this.tooltip,
  });

  final IconData icon;
  final bool active;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Icon(
          icon,
          size: 18,
          color: active ? context.visuals.accent : context.visuals.textMuted,
        ),
      );
}

class _MissingHouseholdImage extends StatelessWidget {
  const _MissingHouseholdImage();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chair_outlined,
                size: 48, color: context.visuals.textMuted),
            const SizedBox(height: 8),
            Text('Imagen pendiente',
                style:
                    TextStyle(color: context.visuals.textMuted, fontSize: 12)),
          ],
        ),
      );
}

class _HouseholdEmpty extends StatelessWidget {
  const _HouseholdEmpty({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(filtered ? Icons.search_off_rounded : Icons.home_work_outlined,
                size: 54, color: context.visuals.textMuted),
            const SizedBox(height: 12),
            Text(
              filtered
                  ? 'No hay artículos con estos filtros'
                  : 'Tu inventario del hogar está vacío',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              filtered
                  ? 'Prueba otra categoría o cambia la búsqueda.'
                  : 'Añade una compra o pídele a Codex que prepare la imagen, la ficha y el manual.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.visuals.textMuted),
            ),
          ],
        ),
      );
}

Future<void> _showHouseholdDetail(
  BuildContext context,
  TodoWorkspace controller,
  HouseholdItem initialItem,
) async {
  final action = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final item = controller.householdItemById(initialItem.id) ?? initialItem;
      return Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040, maxHeight: 760),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final image = ColoredBox(
                color: const Color(0xFFF3EEE5),
                child: FutureBuilder<String>(
                  future: controller.householdImageAbsolutePath(
                    item,
                    thumbnail: false,
                  ),
                  builder: (context, snapshot) {
                    final path = snapshot.data ?? '';
                    if (path.isEmpty || !File(path).existsSync()) {
                      return const _MissingHouseholdImage();
                    }
                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Image.file(File(path), fit: BoxFit.contain),
                    );
                  },
                ),
              );
              final details = _HouseholdDetailPanel(
                controller: controller,
                item: item,
                onClose: () => Navigator.pop(dialogContext),
                onEdit: () => Navigator.pop(dialogContext, 'edit'),
                onArchive: () => Navigator.pop(dialogContext, 'archive'),
              );
              if (constraints.maxWidth < 760) {
                return Column(
                  children: [
                    SizedBox(height: 320, width: double.infinity, child: image),
                    Expanded(child: details),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 3, child: image),
                  SizedBox(width: 410, child: details),
                ],
              );
            },
          ),
        ),
      );
    },
  );
  if (!context.mounted) return;
  if (action == 'edit') {
    await _showHouseholdEditor(context, controller, item: initialItem);
  } else if (action == 'archive') {
    controller.archiveHouseholdItem(initialItem.id);
  }
}

class _HouseholdDetailPanel extends StatelessWidget {
  const _HouseholdDetailPanel({
    required this.controller,
    required this.item,
    required this.onClose,
    required this.onEdit,
    required this.onArchive,
  });

  final TodoWorkspace controller;
  final HouseholdItem item;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final manualWebUri = _householdWebUri(item.manualSourceUrl);
    final hasManualAccess = item.hasManual || manualWebUri != null;
    final metadata = <({String label, String value})>[
      (label: 'Categoría', value: item.category),
      if (item.brand.isNotEmpty) (label: 'Marca', value: item.brand),
      if (item.model.isNotEmpty) (label: 'Modelo', value: item.model),
      if (item.serialNumber.isNotEmpty)
        (label: 'Número de serie', value: item.serialNumber),
      if (item.location.isNotEmpty) (label: 'Ubicación', value: item.location),
      if (item.retailer.isNotEmpty) (label: 'Tienda', value: item.retailer),
      if (item.purchaseDate != null)
        (label: 'Compra', value: _householdDate(item.purchaseDate!)),
      if (item.warrantyUntil != null)
        (label: 'Garantía hasta', value: _householdDate(item.warrantyUntil!)),
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
                  child: Text('Ficha del hogar',
                      style: TextStyle(color: context.visuals.textMuted)),
                ),
                PopupMenuButton<String>(
                  key: const ValueKey('household-detail-more'),
                  tooltip: 'Más opciones',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (value) async {
                    if (value != 'archive') return;
                    final confirmed = await _confirm(
                      context,
                      'Archivar artículo',
                      'El artículo dejará de aparecer en el inventario.',
                    );
                    if (confirmed) onArchive();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined),
                          SizedBox(width: 10),
                          Text('Archivar artículo'),
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
            Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  ...metadata.map((entry) => Padding(
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                  if (item.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: item.tags
                          .map((tag) => Chip(label: Text(tag)))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (item.notes.isNotEmpty)
                    Text(item.notes, style: const TextStyle(height: 1.45)),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (hasManualAccess || item.hasInvoice) ...[
              Text(
                'Documentos',
                style: TextStyle(
                  color: context.visuals.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (hasManualAccess)
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: item.hasManual
                            ? () => _openHouseholdFile(
                                context, controller, item.manualPath)
                            : () => _openHouseholdUrl(
                                context, manualWebUri!.toString()),
                        icon: const Icon(Icons.menu_book_rounded),
                        label: Text(
                          item.hasManual ? 'Abrir manual' : 'Manual web',
                        ),
                      ),
                    ),
                  if (hasManualAccess && item.hasInvoice)
                    const SizedBox(width: 10),
                  if (item.hasInvoice)
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _openHouseholdFile(
                          context,
                          controller,
                          item.invoicePath,
                        ),
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: const Text('Abrir factura'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('household-detail-qr'),
                    onPressed: () => _showHouseholdQr(context, item),
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: const Text('Código QR'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Editar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openHouseholdFile(
  BuildContext context,
  TodoWorkspace controller,
  String relativePath,
) async {
  final path = await controller.householdDocumentAbsolutePath(relativePath);
  if (path.isEmpty || !File(path).existsSync()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El documento no está disponible.')),
      );
    }
    return;
  }
  await launchUrl(Uri.file(path), mode: LaunchMode.externalApplication);
}

Future<void> _openHouseholdUrl(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null || !<String>{'https', 'http'}.contains(uri.scheme)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('La dirección del manual no es válida.')),
    );
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _showHouseholdEditor(
  BuildContext context,
  TodoWorkspace controller, {
  HouseholdItem? item,
}) async {
  final current =
      item == null ? null : controller.householdItemById(item.id) ?? item;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _HouseholdItemEditorDialog(
      controller: controller,
      item: current,
    ),
  );
}

class _HouseholdItemEditorDialog extends StatefulWidget {
  const _HouseholdItemEditorDialog({
    required this.controller,
    required this.item,
  });

  final TodoWorkspace controller;
  final HouseholdItem? item;

  @override
  State<_HouseholdItemEditorDialog> createState() =>
      _HouseholdItemEditorDialogState();
}

class _HouseholdItemEditorDialogState
    extends State<_HouseholdItemEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _serial;
  late final TextEditingController _location;
  late final TextEditingController _retailer;
  late final TextEditingController _price;
  late final TextEditingController _manualUrl;
  late final TextEditingController _tags;
  late final TextEditingController _notes;
  DateTime? _purchaseDate;
  DateTime? _warrantyUntil;
  XFile? _imageFile;
  Uint8List? _pastedImageBytes;
  final FocusNode _imagePasteFocus = FocusNode(
    debugLabel: 'Pegar imagen de hogar',
  );
  XFile? _manualFile;
  XFile? _invoiceFile;
  bool _saving = false;

  HouseholdItem? get item => widget.item;
  bool get editing => item != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: item?.name ?? '');
    _category = TextEditingController(text: item?.category ?? '');
    _brand = TextEditingController(text: item?.brand ?? '');
    _model = TextEditingController(text: item?.model ?? '');
    _serial = TextEditingController(text: item?.serialNumber ?? '');
    _location = TextEditingController(text: item?.location ?? '');
    _retailer = TextEditingController(text: item?.retailer ?? '');
    _price = TextEditingController(
      text: item?.price == null ? '' : item!.price!.toStringAsFixed(2),
    );
    _manualUrl = TextEditingController(text: item?.manualSourceUrl ?? '');
    _tags = TextEditingController(text: item?.tags.join(', ') ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
    _purchaseDate = item?.purchaseDate;
    _warrantyUntil = item?.warrantyUntil;
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _name,
      _category,
      _brand,
      _model,
      _serial,
      _location,
      _retailer,
      _price,
      _manualUrl,
      _tags,
      _notes,
    ]) {
      controller.dispose();
    }
    _imagePasteFocus.dispose();
    super.dispose();
  }

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
                            editing ? 'Editar artículo' : 'Añadir compra',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            editing
                                ? 'Actualiza la ficha, sus documentos y la información de compra.'
                                : 'Crea una ficha completa para guardar todo lo importante.',
                            style: TextStyle(color: visuals.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: _saving ? null : () => Navigator.pop(context),
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
                          SizedBox(height: 260, child: _imagePanel()),
                          Expanded(child: _form()),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 390, child: _imagePanel()),
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
                    if (editing)
                      Expanded(
                        child: Text(
                          'Los documentos solo se sustituyen si eliges otro archivo.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: visuals.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 16),
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
                      label: Text(editing ? 'Guardar cambios' : 'Añadir'),
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

  Widget _imagePanel() {
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
                  Expanded(child: _imagePreview()),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _selectImage,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          _imageFile?.name ??
                              (_pastedImageBytes != null
                                  ? 'Cambiar imagen'
                                  : item?.imagePath.isNotEmpty == true
                                      ? 'Cambiar imagen'
                                      : 'Elegir imagen'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pasteImage,
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('Pegar imagen'),
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

  Widget _imagePreview() {
    if (_pastedImageBytes != null) {
      return Image.memory(
        _pastedImageBytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _MissingHouseholdImage(),
      );
    }
    if (_imageFile != null) {
      return Image.file(
        File(_imageFile!.path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _MissingHouseholdImage(),
      );
    }
    if (item == null) return const _MissingHouseholdImage();
    return FutureBuilder<String>(
      future: widget.controller.householdImageAbsolutePath(
        item!,
        thumbnail: false,
      ),
      builder: (context, snapshot) {
        final path = snapshot.data ?? '';
        if (path.isEmpty || !File(path).existsSync()) {
          return const _MissingHouseholdImage();
        }
        return Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _MissingHouseholdImage(),
        );
      },
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('household-editor-form'),
        padding: const EdgeInsets.all(24),
        children: [
          _sectionTitle('Información básica'),
          const SizedBox(height: 14),
          TextFormField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: _requiredField,
          ),
          const SizedBox(height: 12),
          if (editing)
            DropdownButtonFormField<String>(
              key: const ValueKey('household-editor-category'),
              initialValue: _category.text,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: _availableCategories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) => _category.text = value ?? _category.text,
            )
          else
            TextFormField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              validator: _requiredField,
            ),
          const SizedBox(height: 12),
          _pairedFields(
            TextFormField(
              controller: _brand,
              decoration: const InputDecoration(labelText: 'Marca'),
            ),
            TextFormField(
              controller: _model,
              decoration: const InputDecoration(labelText: 'Modelo'),
            ),
          ),
          const SizedBox(height: 12),
          _pairedFields(
            TextFormField(
              controller: _serial,
              decoration: const InputDecoration(labelText: 'Número de serie'),
            ),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Ubicación',
                hintText: 'Cocina, salón, despacho…',
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Compra y garantía'),
          const SizedBox(height: 14),
          _pairedFields(
            TextFormField(
              controller: _retailer,
              decoration: const InputDecoration(labelText: 'Tienda'),
            ),
            TextFormField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Precio',
                suffixText: '€',
              ),
              validator: _priceValidator,
            ),
          ),
          const SizedBox(height: 12),
          _pairedFields(
            _HouseholdDateButton(
              label: 'Fecha de compra',
              value: _purchaseDate,
              onChanged: (value) => setState(() => _purchaseDate = value),
            ),
            _HouseholdDateButton(
              label: 'Garantía hasta',
              value: _warrantyUntil,
              onChanged: (value) => setState(() => _warrantyUntil = value),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Documentación'),
          const SizedBox(height: 14),
          TextFormField(
            controller: _manualUrl,
            decoration: const InputDecoration(
              labelText: 'Fuente oficial del manual',
              hintText: 'https://fabricante.com/manual.pdf',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _selectPdf(manual: true),
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(
                  _manualFile?.name ??
                      (item?.hasManual == true
                          ? 'Cambiar manual'
                          : 'Añadir manual PDF'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _selectPdf(manual: false),
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(
                  _invoiceFile?.name ??
                      (item?.hasInvoice == true
                          ? 'Cambiar factura'
                          : 'Añadir factura PDF'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle('Organización y notas'),
          const SizedBox(height: 14),
          TextFormField(
            controller: _tags,
            decoration: const InputDecoration(
              labelText: 'Etiquetas',
              hintText: 'wifi, bajo consumo, mantenimiento anual',
              helperText: 'Separa varias etiquetas con comas',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Notas',
              hintText: 'Accesorios, consumibles, incidencias o cuidados…',
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String value) =>
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

  List<String> get _availableCategories {
    final categories = widget.controller.householdItems
        .where((householdItem) => !householdItem.archived)
        .map((householdItem) => householdItem.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet();
    if (item != null) categories.add(item!.category);
    return categories.toList()..sort();
  }

  String? _requiredField(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Este campo es obligatorio' : null;

  String? _priceValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.')) == null
        ? 'Escribe un importe válido'
        : null;
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
    if (selected != null && mounted) {
      setState(() {
        _imageFile = selected;
        _pastedImageBytes = null;
      });
    }
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
      _imageFile = null;
    });
    _showImageMessage('Imagen pegada.');
  }

  void _showImageMessage(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _selectPdf({required bool manual}) async {
    final selected = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (manual) {
        _manualFile = selected;
      } else {
        _invoiceFile = selected;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final parsedPrice = double.tryParse(
      _price.text.trim().replaceAll(',', '.'),
    );
    final parsedTags = _tags.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final saved = item ??
        widget.controller.createHouseholdItem(
          name: _name.text,
          category: _category.text,
          brand: _brand.text,
          model: _model.text,
          serialNumber: _serial.text,
          location: _location.text,
          retailer: _retailer.text,
          price: parsedPrice,
          purchaseDate: _purchaseDate,
          warrantyUntil: _warrantyUntil,
          manualSourceUrl: _manualUrl.text,
          tags: parsedTags,
          notes: _notes.text,
        );
    if (item != null) {
      widget.controller.updateHouseholdItem(
        item!.id,
        name: _name.text,
        category: _category.text,
        brand: _brand.text,
        model: _model.text,
        serialNumber: _serial.text,
        location: _location.text,
        retailer: _retailer.text,
        price: parsedPrice,
        clearPrice: _price.text.trim().isEmpty,
        purchaseDate: _purchaseDate,
        clearPurchaseDate: _purchaseDate == null,
        warrantyUntil: _warrantyUntil,
        clearWarrantyUntil: _warrantyUntil == null,
        manualSourceUrl: _manualUrl.text,
        tags: parsedTags,
        notes: _notes.text,
      );
    }
    String? resourceError;
    try {
      if (_pastedImageBytes != null) {
        await widget.controller.importHouseholdImageBytes(
          saved.id,
          _pastedImageBytes!,
        );
      } else if (_imageFile != null) {
        await widget.controller
            .importHouseholdImage(saved.id, _imageFile!.path);
      }
      if (_manualFile != null) {
        await widget.controller
            .importHouseholdManual(saved.id, _manualFile!.path);
      }
      if (_invoiceFile != null) {
        await widget.controller
            .importHouseholdInvoice(saved.id, _invoiceFile!.path);
      }
    } catch (error) {
      resourceError = error.toString();
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.pop(context);
    if (resourceError != null) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'La ficha se guardó, pero no se pudo importar un recurso: $resourceError',
          ),
        ),
      );
    }
  }
}

class _HouseholdDateButton extends StatelessWidget {
  const _HouseholdDateButton({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(
              child: Text(value == null ? 'Sin fecha' : _householdDate(value!)),
            ),
            if (value != null)
              IconButton(
                tooltip: 'Quitar fecha',
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            IconButton(
              tooltip: 'Elegir fecha',
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: value ?? DateTime.now(),
                  firstDate: DateTime(1990),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (selected != null) onChanged(selected);
              },
              icon: const Icon(Icons.calendar_month_rounded, size: 19),
            ),
          ],
        ),
      );
}

String _householdDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';
