part of 'app_shell.dart';

class HouseholdPage extends StatefulWidget {
  const HouseholdPage({required this.controller, super.key});

  final TodoWorkspace controller;

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
    final now = DateTime.now();
    final withManual = active.where((item) => item.hasManual).length;
    final underWarranty = active
        .where((item) =>
            item.warrantyUntil != null && !item.warrantyUntil!.isBefore(now))
        .length;

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
                    Text('Hogar',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${active.length} ${active.length == 1 ? 'artículo' : 'artículos'} · '
                      '$withManual con manual guardado',
                      style: TextStyle(color: context.visuals.textMuted),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showHouseholdEditor(context, controller),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Añadir compra'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HouseholdSummaryChip(
                icon: Icons.inventory_2_outlined,
                label: '${active.length} inventariados',
              ),
              _HouseholdSummaryChip(
                icon: Icons.menu_book_rounded,
                label: '$withManual con manual',
              ),
              _HouseholdSummaryChip(
                icon: Icons.verified_user_outlined,
                label: '$underWarranty en garantía',
              ),
              _HouseholdSummaryChip(
                icon: Icons.description_outlined,
                label:
                    '${active.where((item) => item.hasInvoice).length} con factura',
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('household-search'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Buscar en el hogar',
              hintText: 'Lavadora, Bosch, cocina, modelo o número de serie…',
            ),
            onChanged: (value) => setState(() => _query = value),
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
                final count = value == 'Todos'
                    ? active.length
                    : active.where((item) => item.category == value).length;
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
      ),
    );
  }
}

class _HouseholdSummaryChip extends StatelessWidget {
  const _HouseholdSummaryChip({required this.icon, required this.label});

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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: item.hasManual
                      ? () => _openHouseholdFile(
                          context, controller, item.manualPath)
                      : item.manualSourceUrl.isNotEmpty
                          ? () =>
                              _openHouseholdUrl(context, item.manualSourceUrl)
                          : null,
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text(item.hasManual ? 'Abrir manual' : 'Manual web'),
                ),
                FilledButton.tonalIcon(
                  onPressed: item.hasInvoice
                      ? () => _openHouseholdFile(
                          context, controller, item.invoicePath)
                      : null,
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Factura'),
                ),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Editar'),
                ),
                IconButton(
                  tooltip: 'Archivar',
                  onPressed: onArchive,
                  icon: const Icon(Icons.archive_outlined),
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
  final name = TextEditingController(text: current?.name ?? '');
  final category = TextEditingController(text: current?.category ?? '');
  final brand = TextEditingController(text: current?.brand ?? '');
  final model = TextEditingController(text: current?.model ?? '');
  final serial = TextEditingController(text: current?.serialNumber ?? '');
  final location = TextEditingController(text: current?.location ?? '');
  final retailer = TextEditingController(text: current?.retailer ?? '');
  final price = TextEditingController(
      text: current?.price == null ? '' : current!.price!.toStringAsFixed(2));
  final manualUrl = TextEditingController(text: current?.manualSourceUrl ?? '');
  final tags = TextEditingController(text: current?.tags.join(', ') ?? '');
  final notes = TextEditingController(text: current?.notes ?? '');
  var purchaseDate = current?.purchaseDate;
  var warrantyUntil = current?.warrantyUntil;
  XFile? imageFile;
  XFile? manualFile;
  XFile? invoiceFile;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(current == null ? 'Añadir compra' : 'Editar artículo'),
        content: SizedBox(
          width: 720,
          height: 650,
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: name,
                      autofocus: true,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: category,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: brand,
                      decoration: const InputDecoration(labelText: 'Marca'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: model,
                      decoration: const InputDecoration(labelText: 'Modelo'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: serial,
                      decoration:
                          const InputDecoration(labelText: 'Número de serie'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: location,
                      decoration: const InputDecoration(
                        labelText: 'Ubicación',
                        hintText: 'Cocina, salón, despacho…',
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
                      controller: retailer,
                      decoration: const InputDecoration(labelText: 'Tienda'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Precio (€)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _HouseholdDateButton(
                      label: 'Fecha de compra',
                      value: purchaseDate,
                      onChanged: (value) =>
                          setDialogState(() => purchaseDate = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HouseholdDateButton(
                      label: 'Garantía hasta',
                      value: warrantyUntil,
                      onChanged: (value) =>
                          setDialogState(() => warrantyUntil = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: manualUrl,
                decoration: const InputDecoration(
                  labelText: 'Fuente oficial del manual',
                  hintText: 'https://fabricante.com/manual.pdf',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tags,
                decoration: const InputDecoration(
                  labelText: 'Etiquetas',
                  hintText: 'wifi, bajo consumo, mantenimiento anual',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notas',
                  hintText: 'Accesorios, consumibles, incidencias o cuidados…',
                ),
              ),
              const SizedBox(height: 16),
              Text('Recursos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
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
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await openFile(
                        acceptedTypeGroups: const [
                          XTypeGroup(label: 'PDF', extensions: ['pdf']),
                        ],
                      );
                      if (selected != null) {
                        setDialogState(() => manualFile = selected);
                      }
                    },
                    icon: const Icon(Icons.menu_book_outlined),
                    label: Text(manualFile?.name ??
                        (current?.hasManual == true
                            ? 'Cambiar manual'
                            : 'Añadir manual PDF')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await openFile(
                        acceptedTypeGroups: const [
                          XTypeGroup(label: 'PDF', extensions: ['pdf']),
                        ],
                      );
                      if (selected != null) {
                        setDialogState(() => invoiceFile = selected);
                      }
                    },
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(invoiceFile?.name ??
                        (current?.hasInvoice == true
                            ? 'Cambiar factura'
                            : 'Añadir factura PDF')),
                  ),
                ],
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
            onPressed: name.text.trim().isEmpty
                ? null
                : () => Navigator.pop(dialogContext, true),
            child: Text(current == null ? 'Añadir' : 'Guardar'),
          ),
        ],
      ),
    ),
  );
  if (result != true || !context.mounted) return;

  final parsedPrice = double.tryParse(price.text.trim().replaceAll(',', '.'));
  final parsedTags = tags.text
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
  final saved = current ??
      controller.createHouseholdItem(
        name: name.text,
        category: category.text,
        brand: brand.text,
        model: model.text,
        serialNumber: serial.text,
        location: location.text,
        retailer: retailer.text,
        price: parsedPrice,
        purchaseDate: purchaseDate,
        warrantyUntil: warrantyUntil,
        manualSourceUrl: manualUrl.text,
        tags: parsedTags,
        notes: notes.text,
      );
  if (current != null) {
    controller.updateHouseholdItem(
      current.id,
      name: name.text,
      category: category.text,
      brand: brand.text,
      model: model.text,
      serialNumber: serial.text,
      location: location.text,
      retailer: retailer.text,
      price: parsedPrice,
      clearPrice: price.text.trim().isEmpty,
      purchaseDate: purchaseDate,
      clearPurchaseDate: purchaseDate == null,
      warrantyUntil: warrantyUntil,
      clearWarrantyUntil: warrantyUntil == null,
      manualSourceUrl: manualUrl.text,
      tags: parsedTags,
      notes: notes.text,
    );
  }
  try {
    if (imageFile != null) {
      await controller.importHouseholdImage(saved.id, imageFile!.path);
    }
    if (manualFile != null) {
      await controller.importHouseholdManual(saved.id, manualFile!.path);
    }
    if (invoiceFile != null) {
      await controller.importHouseholdInvoice(saved.id, invoiceFile!.path);
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo importar un recurso: $error')),
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
