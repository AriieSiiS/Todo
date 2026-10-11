part of 'app_shell.dart';

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
